import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../core/network/mqtt_client.dart';
import '../../core/constants/ws_cmd.dart';
import '../../config/config.dart';
import '../../core/utils/message_status_parser.dart';
import '../../core/utils/message_utils.dart';
import '../../models/message_model.dart';
import '../../core/cache/message_cache_manager.dart';
import '../../services/conversation_service.dart';
import '../../providers/chat_provider.dart';
import '../widgets/chat_bubble.dart';
import 'group_detail_screen.dart';
import '../../core/utils/date_utils.dart' as app_date;

class ChatDetailScreen extends StatefulWidget {
  final int targetId;
  final String targetType;
  final String? targetName;

  const ChatDetailScreen({
    super.key,
    required this.targetId,
    required this.targetType,
    this.targetName,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_DisplayMessage> _messages = [];
  bool _isLoading = true;
  bool _hasMore = false;
  String _sessionId = '';
  MqttChatClient? _mqttClient;
  // 临时选择器状态：记录待发送的媒体/文件（等待用户点击发送按钮后再真正发送）
  File? _pendingMediaFile;     // 待发送的文件对象（图片/视频/文档/语音）
  String _pendingMediaType = 'text'; // 当前选中类型：text / image / video / file / voice
  String? _pendingMediaUrl;    // 已上传后的 URL，直接用作消息 content
  String? _pendingFileName;    // 文件名（仅 file 类型需要展示）
  // 表情面板状态
  bool _showEmojiPanel = false; // 是否显示 emoji 选择面板
  static const List<String> _emojiList = [ // 常用 emoji 列表（微信风格：一行 8 个，两行）
    '😀','😂','🥰','😍','🤩','😘','😊','🥳',
    '😎','🤔','😅','😭','😱','🤗','🫡','😇',
    '👍','👏','🙏','💪','❤️','🔥','💯','🎉',
  ];

  @override
  void initState() {
    super.initState();
    _ensureConversationSaved();
    _initCache();
    _initMqtt();
  }

  /// 进入聊天页时把该对话保存到本地会话列表，并清空未读数。
  Future<void> _ensureConversationSaved() async {
    final auth = context.read<AuthProvider>();
    if (auth.userId == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    await ConversationService().saveSession(
      userId: auth.userId!,
      targetId: widget.targetId,
      targetType: widget.targetType,
      lastMsg: widget.targetName ?? '',
      lastMsgTime: now,
      unreadCount: 0,
    );

    // 通知服务端标记消息为已读
    final service = ChatService(auth.apiClient);
    service.markAsRead(auth.userId!, widget.targetId, widget.targetType);

    if (!mounted) return;
    // 清空该会话的未读数，导航栏角标和列表角标同步更新
    context.read<ChatProvider>().updateConversation(
      Conversation(
        targetId: widget.targetId,
        targetType: widget.targetType,
        lastMsg: widget.targetName ?? '',
        lastMsgTime: now,
        unreadCount: 0,
      ),
    );
  }

  Future<void> _initCache() async {
    final auth = context.read<AuthProvider>();
    if (auth.userId == null) return;

    _sessionId = widget.targetType == 'group'
        ? MessageCacheManager.sessionIdForGroup(widget.targetId)
        : MessageCacheManager.sessionIdForPrivate(auth.userId!, widget.targetId);

    await MessageCacheManager().init();
    final cached = await MessageCacheManager().recentMessages(_sessionId, limit: 30);

    if (mounted) {
      setState(() {
        _messages.addAll(cached.map((m) => _DisplayMessage.fromModel(m)));
        _isLoading = false;
        _hasMore = _messages.isNotEmpty;
      });
    }

    // 后台同步服务端最新历史，并更新缓存
    await _loadHistory();

    // 进入聊天页面时，请求服务器推送未推送成功的消息
    _fetchUndelivered();
  }

  void _initMqtt() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.userId ?? 0;
    // 使用独立 clientId，避免与 HomeScreen 的全局 MQTT 连接互踢
    final chatClientId = 'user_${userId}_chat_${widget.targetId}_${widget.targetType}';
    _mqttClient = MqttChatClient(
      host: AppConfig.mqttHost,
      port: AppConfig.mqttPort,
      onMessage: _handleMqttMessage,
    );
    // 等待连接完成后再订阅群主题
    await _mqttClient?.connect(
      userId: userId,
      username: AppConfig.mqttUsername,
      password: AppConfig.mqttPassword,
      clientId: chatClientId,
    );
    // 连接成功后订阅群主题
    if (widget.targetType == 'group') {
      _mqttClient?.subscribeGroup(widget.targetId);
    }
  }

  /// 处理 MQTT 收到的消息
  Future<void> _handleMqttMessage(int cmd, dynamic data) async {
    if (!mounted) return;
    debugPrint('[ChatDetail] _handleMqttMessage cmd=$cmd, data=$data');
    if (cmd == WsCmd.msgPush) {
      // 只处理与自己相关的消息
      final fromUserId = MessageUtils.toNullableInt(data['fromUserId']);
      final toUserId = MessageUtils.toNullableInt(data['toUserId']);
      final groupId = MessageUtils.toNullableInt(data['groupId']);

      bool isRelated = false;
      if (widget.targetType == 'group') {
        isRelated = groupId == widget.targetId;
      } else if (widget.targetType == 'file_helper') {
        // 文件传输助手：消息是"发给自己的"（from=to=自己），推送到本人 topic
        final auth = context.read<AuthProvider>();
        isRelated = fromUserId == auth.userId && toUserId == auth.userId;
      } else {
        final auth = context.read<AuthProvider>();
        isRelated = (fromUserId == widget.targetId && toUserId == auth.userId) ||
                    (fromUserId == auth.userId && toUserId == widget.targetId);
      }
      debugPrint('[ChatDetail] isRelated=$isRelated, targetType=${widget.targetType}, targetId=${widget.targetId}, from=$fromUserId, to=$toUserId, groupId=$groupId');

      if (isRelated) {
        final incoming = _DisplayMessage.fromJson(data);
        final localSeq = MessageUtils.toNullableInt(data['localSeq']);
        await MessageCacheManager().appendMessage(_sessionId, incoming.toModel());
        if (!mounted) return;
        setState(() {
          if (localSeq != null) {
            final idx = _messages.indexWhere(
              (m) => m.id == localSeq && m.fromUserId == incoming.fromUserId,
            );
            if (idx != -1) {
              _messages[idx] = incoming;
              return;
            }
          }
          final exists = _messages.any((m) => m.id == incoming.id);
          if (!exists) {
            _messages.add(incoming);
          }
        });
        _scrollToBottom();

        // 收到对方消息后，向服务器发送回执确认（仅对方发来的消息才回执）
        if (fromUserId != null && fromUserId != (context.read<AuthProvider>().userId ?? 0)) {
          _sendReceipt(incoming.id);
        }
      }
    } else if (cmd == WsCmd.msgReceiptAck) {
      // 服务器回执：确认消息已推送给对方，更新 pushStatus 为 delivered
      final msgId = MessageUtils.toNullableInt(data['messageId']);
      if (msgId != null) {
        debugPrint('[ChatDetail] msgReceiptAck for msgId=$msgId, updating pushStatus to delivered');
        await MessageCacheManager().updatePushStatus(_sessionId, msgId, 'delivered');
        if (!mounted) return;
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == msgId);
          if (idx != -1) {
            _messages[idx] = _messages[idx].copyWith(pushStatus: 'delivered');
          }
        });
      }
    } else if (cmd == WsCmd.fetchUndeliveredAck) {
      // 服务器推送未推送成功的消息列表
      final messages = data as List<dynamic>? ?? [];
      debugPrint('[ChatDetail] fetchUndeliveredAck: ${messages.length} messages');
      for (final msgData in messages) {
        final incoming = _DisplayMessage.fromJson(msgData);
        await MessageCacheManager().appendMessage(_sessionId, incoming.toModel());
        if (!mounted) return;
        final exists = _messages.any((m) => m.id == incoming.id);
        if (!exists) {
          setState(() => _messages.add(incoming));
        }
      }
      // 重新排序并滚动到底部
      if (messages.isNotEmpty && mounted) {
        setState(() {
          _messages.sort((a, b) => a.createTime.compareTo(b.createTime));
        });
        _scrollToBottom();
      }
    } else if (cmd == WsCmd.friendReqNotify) {
      // 好友请求通知
    }
  }

  /// 向服务器发送消息回执（接收方确认收到消息）- 通过 REST API
  void _sendReceipt(int messageId) {
    final auth = context.read<AuthProvider>();
    if (auth.userId == null) return;
    final service = ChatService(auth.apiClient);
    service.sendReceipt(messageId, auth.userId!, widget.targetId, widget.targetType);
    debugPrint('[ChatDetail] sent msgReceipt for messageId=$messageId');
  }

  /// 进入聊天页面时请求服务器推送未推送成功的消息 - 通过 REST API
  void _fetchUndelivered() async {
    final auth = context.read<AuthProvider>();
    if (auth.userId == null) return;
    final service = ChatService(auth.apiClient);
    final messages = await service.fetchUndelivered(auth.userId!, widget.targetId, widget.targetType);
    debugPrint('[ChatDetail] fetchUndelivered: ${messages.length} messages');
    if (messages.isEmpty || !mounted) return;
    for (final msg in messages) {
      await MessageCacheManager().appendMessage(_sessionId, msg);
      if (!mounted) return;
      final exists = _messages.any((m) => m.id == msg.id);
      if (!exists) {
        setState(() => _messages.add(_DisplayMessage.fromModel(msg)));
      }
    }
    if (mounted) {
      setState(() {
        _messages.sort((a, b) => a.createTime.compareTo(b.createTime));
      });
      _scrollToBottom();
    }
  }

  Future<void> _loadHistory() async {
    final auth = context.read<AuthProvider>();
    if (auth.userId == null) return;

    if (mounted) setState(() => _isLoading = true);
    final service = ChatService(auth.apiClient);
    final messages = await service.getHistory(
      userId: auth.userId!,
      targetId: widget.targetId,
      targetType: widget.targetType,
      page: 1,
      size: 30,
    );

    // 同步写入本地缓存
    for (final m in messages) {
      await MessageCacheManager().appendMessage(_sessionId, m);
    }

    if (!mounted) return;

    // 以缓存为准重新加载，但保留 _messages 中已有但缓存快照还没同步的实时消息
    // （避免竞态：MQTT 消息刚到、缓存写入尚未完成时被清空）
    final cached = await MessageCacheManager().recentMessages(_sessionId, limit: 30);
    if (!mounted) return;
    setState(() {
      // 用 id 做 key 合并：缓存版本优先（可能含更新的 status），保留 _messages 中未同步的实时消息
      final merged = <int, _DisplayMessage>{};
      for (final m in _messages) {
        merged[m.id] = m;
      }
      for (final m in cached) {
        final display = _DisplayMessage.fromModel(m);
        merged[display.id] = display; // 缓存版本覆盖
      }
      _messages
        ..clear()
        ..addAll(merged.values)
        ..sort((a, b) => a.createTime.compareTo(b.createTime));
      _hasMore = messages.length >= 30;
      _isLoading = false;
    });
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _messages.isEmpty) return;

    final earliest = _messages.first;
    final older = await MessageCacheManager().loadHistory(
      _sessionId,
      beforeTime: earliest.createTime,
      limit: 20,
    );

    if (older.isNotEmpty) {
      setState(() {
        _messages.insertAll(0, older.map((m) => _DisplayMessage.fromModel(m)));
        _hasMore = older.length >= 20;
      });
    } else {
      setState(() => _hasMore = false);
    }
  }

  /// 打开图片选择器（相册 / 相机），选择后回调 [onPicked]
  Future<void> _pickImage(void Function(File) onPicked) async {
    try {
      final picker = ImagePicker();
      // 先询问用户：从相册选图还是拍照
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.chooseImageSource),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
              child: Text(AppLocalizations.of(context)!.gallery),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, ImageSource.camera),
              child: Text(AppLocalizations.of(context)!.camera),
            ),
          ],
        ),
      );
      if (source == null) return;
      // 调用 image_picker 获取 XFile，再转为 File
      final XFile? picked = await picker.pickImage(
        source: source,
        maxWidth: 1920,   // 限制最大宽度，避免大文件上传慢
        maxHeight: 1920,
        imageQuality: 85, // 压缩质量 85%，在清晰度与流量之间平衡
      );
      if (picked == null) return;
      onPicked(File(picked.path));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.pickImageFailed + ': $e')),
      );
    }
  }

  /// 打开视频选择器（相册 / 相机），选择后回调 [onPicked]
  Future<void> _pickVideo(void Function(File) onPicked) async {
    try {
      final picker = ImagePicker();
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.chooseVideoSource),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
              child: Text(AppLocalizations.of(context)!.gallery),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, ImageSource.camera),
              child: Text(AppLocalizations.of(context)!.camera),
            ),
          ],
        ),
      );
      if (source == null) return;
      final XFile? picked = await picker.pickVideo(source: source);
      if (picked == null) return;
      onPicked(File(picked.path));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.pickVideoFailed + ': $e')),
      );
    }
  }

  /// 打开系统文件选择器，限制只能选图片/视频/文档（排除其他任意文件）
  Future<void> _pickFile(void Function(File) onPicked) async {
    try {
      // 这里仅做文件选择，不再进一步限制 MIME（后端 uploadMedia 端点只校验 type 白名单）
      // 使用 image_picker 模拟（仅取 path）；实际生产可接入 path_provider + open_file 或 file_picker 插件
      final picker = ImagePicker();
      // image_picker 不直接支持通用文件，这里回退到相册通道：
      // - 相册：用户手动挑选图片/视频（已覆盖大部分场景）
      // - 若需选 PDF/压缩包等文档，提示用户使用系统分享面板
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.chooseFileSource),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
              child: Text(AppLocalizations.of(context)!.gallery),
            ),
          ],
        ),
      );
      if (source == null) return;
      final XFile? picked = await picker.pickImage(source: source);
      if (picked == null) return;
      onPicked(File(picked.path));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.pickFileFailed + ': $e')),
      );
    }
  }

  /// 发送消息（含文本 / 图片 / 视频 / 文件）
  Future<void> _sendMessage() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    final auth = context.read<AuthProvider>();
    final now = DateTime.now().millisecondsSinceEpoch;

    // 分支 1：用户选择了媒体/文件，先上传再发送
    if (_pendingMediaType != 'text' && _pendingMediaUrl != null) {
      final type = _pendingMediaType;
      final content = _pendingMediaUrl!;
      final fileName = _pendingFileName;
      // 清空选择器状态，防止重复发送
      setState(() {
        _pendingMediaType = 'text';
        _pendingMediaUrl = null;
        _pendingMediaFile = null;
        _pendingFileName = null;
      });
      await _doSendMedia(type, content, fileName, now, auth, scaffoldMessenger, l10n);
      return;
    }

    // 分支 2：用户选择了 emoji，直接发送（无需上传）
    if (_pendingMediaType == 'emoji' && _pendingMediaUrl != null) {
      final content = _pendingMediaUrl!;
      setState(() {
        _pendingMediaType = 'text';
        _pendingMediaUrl = null;
        _showEmojiPanel = false;
      });
      await _doSendEmoji(content, now, auth, scaffoldMessenger, l10n);
      return;
    }

    // 分支 2：纯文本发送（原有逻辑）
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // 乐观UI：立即显示
    setState(() {
      _messages.add(_DisplayMessage(
        id: now,
        fromUserId: auth.userId ?? 0,
        toUserId: widget.targetId,
        groupId: widget.targetType == 'group' ? widget.targetId : null,
        type: 'text',
        content: text,
        createTime: now,
        status: 'sending',
      ));
    });
    _controller.clear();
    _scrollToBottom();

    // 通过REST发送，由后端统一落库并MQTT推送
    final service = ChatService(auth.apiClient);
    // 文件传输助手：接收人改为自己（touserId=userId），类型标记为 self（新增消息类型）
    final bool isFileHelper = widget.targetType == 'file_helper';
    final sentModel = _DisplayMessage(
      id: now,
      fromUserId: auth.userId ?? 0,
      toUserId: isFileHelper ? (auth.userId ?? 0) : widget.targetId,
      groupId: widget.targetType == 'group' ? widget.targetId : null,
      type: isFileHelper ? 'self' : 'text',
      content: text,
      createTime: now,
      status: 'sent',
    );
    // 文件助手走独立接口（后端强制接收人=自己、类型=self，同步到本人其他登录端）
    final success = isFileHelper
        ? await service.sendFileHelper(sentModel.toModel())
        : await service.sendMessage(sentModel.toModel());

    if (!mounted) return;

    // 更新本地消息状态并写入缓存
    final index = _messages.indexWhere((m) => m.id == now);
    if (index != -1) {
      setState(() {
        _messages[index] = _messages[index].copyWith(
          status: success ? 'sent' : 'failed',
        );
      });
    }
    if (success) {
      await MessageCacheManager().appendMessage(_sessionId, sentModel.copyWith(status: 'sent').toModel());
      // 更新会话列表 lastMsg（私聊已去掉服务端回显，需客户端主动更新）
      if (mounted) {
        context.read<ChatProvider>().updateConversation(
          Conversation(
            targetId: widget.targetId,
            targetType: widget.targetType,
            lastMsg: text,
            lastMsgTime: now,
            unreadCount: 0,
          ),
        );
        await ConversationService().saveSession(
          userId: auth.userId!,
          targetId: widget.targetId,
          targetType: widget.targetType,
          lastMsg: text,
          lastMsgTime: now,
          unreadCount: 0,
        );
      }
    }

    if (!success) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(l10n.messageFailed)),
      );
    }
  }

  /// 发送媒体/文件消息：上传到对象存储 → 构造 MessageModel → 发送
  Future<void> _doSendMedia(
    String type,
    String content,
    String? fileName,
    int now,
    AuthProvider auth,
    ScaffoldMessengerState scaffoldMessenger,
    AppLocalizations l10n,
  ) async {
    final service = ChatService(auth.apiClient);
    // 构造消息模型：媒体消息 content 存 URL，type 标识类型
    final sentModel = _DisplayMessage(
      id: now,
      fromUserId: auth.userId ?? 0,
      toUserId: widget.targetType == 'file_helper' ? (auth.userId ?? 0) : widget.targetId,
      groupId: widget.targetType == 'group' ? widget.targetId : null,
      type: widget.targetType == 'file_helper' ? 'self' : type,
      content: content,
      createTime: now,
      status: 'sending',
    );
    // 乐观UI：立即显示
    if (!mounted) return;
    setState(() {
      _messages.add(sentModel);
    });
    _scrollToBottom();

    // 通过 REST 发送，由后端统一落库并 MQTT 推送
    final success = widget.targetType == 'file_helper'
        ? await service.sendFileHelper(sentModel.toModel())
        : await service.sendMessage(sentModel.toModel());

    if (!mounted) return;
    final index = _messages.indexWhere((m) => m.id == now);
    if (index != -1) {
      setState(() {
        _messages[index] = _messages[index].copyWith(
          status: success ? 'sent' : 'failed',
        );
      });
    }
    if (success) {
      await MessageCacheManager().appendMessage(_sessionId, sentModel.copyWith(status: 'sent').toModel());
      if (mounted) {
        // 会话 lastMsg：图片/视频/文件消息以类型+文件名作为摘要
        final summary = fileName != null ? '$type: $fileName' : type;
        context.read<ChatProvider>().updateConversation(
          Conversation(
            targetId: widget.targetId,
            targetType: widget.targetType,
            lastMsg: summary,
            lastMsgTime: now,
            unreadCount: 0,
          ),
        );
        await ConversationService().saveSession(
          userId: auth.userId!,
          targetId: widget.targetId,
          targetType: widget.targetType,
          lastMsg: summary,
          lastMsgTime: now,
          unreadCount: 0,
        );
      }
    }

    if (!success && mounted) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(l10n.messageFailed)),
      );
    }
  }

  /// 发送 emoji 消息（纯前端直接发送，无需上传）
  ///
  /// content 为单个 emoji 字符，type 固定为 "emoji"。
  Future<void> _doSendEmoji(
    String emoji,
    int now,
    AuthProvider auth,
    ScaffoldMessengerState scaffoldMessenger,
    AppLocalizations l10n,
  ) async {
    final service = ChatService(auth.apiClient);
    // 构造消息模型
    final sentModel = _DisplayMessage(
      id: now,
      fromUserId: auth.userId ?? 0,
      toUserId: widget.targetType == 'file_helper' ? (auth.userId ?? 0) : widget.targetId,
      groupId: widget.targetType == 'group' ? widget.targetId : null,
      type: widget.targetType == 'file_helper' ? 'self' : 'emoji',
      content: emoji,
      createTime: now,
      status: 'sending',
    );
    // 乐观UI：立即显示
    if (!mounted) return;
    setState(() => _messages.add(sentModel));
    _scrollToBottom();
    // 通过 REST 发送
    final success = widget.targetType == 'file_helper'
        ? await service.sendFileHelper(sentModel.toModel())
        : await service.sendMessage(sentModel.toModel());
    if (!mounted) return;
    final index = _messages.indexWhere((m) => m.id == now);
    if (index != -1) {
      setState(() {
        _messages[index] = _messages[index].copyWith(status: success ? 'sent' : 'failed');
      });
    }
    if (success) {
      await MessageCacheManager().appendMessage(_sessionId, sentModel.copyWith(status: 'sent').toModel());
      if (mounted) {
        context.read<ChatProvider>().updateConversation(
          Conversation(
            targetId: widget.targetId,
            targetType: widget.targetType,
            lastMsg: emoji,
            lastMsgTime: now,
            unreadCount: 0,
          ),
        );
        await ConversationService().saveSession(
          userId: auth.userId!,
          targetId: widget.targetId,
          targetType: widget.targetType,
          lastMsg: emoji,
          lastMsgTime: now,
          unreadCount: 0,
        );
      }
    }
    if (!success && mounted) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text(l10n.messageFailed)));
    }
  }

  /// 用户点击" attachment" 按钮：按当前选中类型触发对应选择器
  void _onAttachTap() {
    switch (_pendingMediaType) {
      case 'image':
        _pickImage((file) => _onMediaPicked(file, 'image'));
        break;
      case 'video':
        _pickVideo((file) => _onMediaPicked(file, 'video'));
        break;
      case 'file':
        _pickFile((file) => _onMediaPicked(file, 'file'));
        break;
      default:
        // 未选择类型时不做任何操作
        break;
    }
  }

  /// 选择媒体/文件后的统一处理：
  /// 1. 上传到对象存储（POST /file/media/{type}）
  /// 2. 将返回的 URL 暂存为 _pendingMediaUrl，类型暂存为 _pendingMediaType
  /// 3. 切换到预览状态，等待用户点击发送
  void _onMediaPicked(File file, String type) {
    final l10n = AppLocalizations.of(context)!;
    final service = ChatService(context.read<AuthProvider>().apiClient);
    // 显示上传中提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${l10n.uploading}...')),
    );
    // 并发上传：上传完成后再 setState 切换 UI
    service.uploadMedia(file, type).then((result) {
      if (!mounted) return;
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.uploadFailed)),
        );
        return;
      }
      // 上传成功，暂存 URL 与文件信息，切换到预览状态
      setState(() {
        _pendingMediaType = type;
        _pendingMediaUrl = result.url;
        _pendingMediaFile = file;
        // 文件名仅 file 类型需要展示；image/video 可省略
        _pendingFileName = type == 'file' ? file.path.split('/').last : null;
      });
    }).catchError((e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.uploadFailed}: $e')),
      );
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        // reverse: true 时 minScrollExtent 对应视觉底部（最新消息位置）
        _scrollController.animateTo(
          _scrollController.position.minScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _mqttClient?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final displayName = widget.targetName ?? l10n.myFriends;

    return Scaffold(
      appBar: AppBar(
        title: Text(displayName),
        // 群聊显示三点按钮，点击直接进入群聊详情
        actions: widget.targetType == 'group'
            ? [
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  tooltip: '群聊信息',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GroupDetailScreen(groupId: widget.targetId),
                      ),
                    );
                  },
                ),
              ]
            : null,
      ),
      body: Column(
        children: [
          // 预览区域：当用户选中媒体/文件但还未发送时显示
          if (_pendingMediaType != 'text' && _pendingMediaUrl != null)
            _buildMediaPreview(theme),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 空状态图标：深色背景下使用低透明度白，柔和且可见
                            const Icon(Icons.chat_bubble_outline, size: 48, color: Colors.white24),
                            const SizedBox(height: 8),
                            // 空状态文字：半透明白，保证深色背景上可读
                            Text(l10n.noMessages, style: const TextStyle(color: Colors.white54)),
                          ],
                        ),
                      )
                    : NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          // reverse: true 时 maxScrollExtent 对应视觉顶部，上滑加载更早消息
                          if (notification is ScrollEndNotification &&
                              notification.metrics.pixels == notification.metrics.maxScrollExtent) {
                            _loadMore();
                          }
                          return false;
                        },
                        child: ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          padding: const EdgeInsets.all(8),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[_messages.length - 1 - index];
                            final isMe = msg.fromUserId == (context.read<AuthProvider>().userId ?? 0);
                            return _buildMessageBubble(msg, isMe, theme);
                          },
                        ),
                      ),
          ),
          _buildInputBar(theme, l10n),
        ],
      ),
    );
  }

  /// 构建媒体预览组件（图片/视频/文件）
  ///
  /// 预览区域位于输入栏上方，显示已选中的媒体缩略图/文件名，并提供取消与重新选择入口。
  Widget _buildMediaPreview(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final isImage = _pendingMediaType == 'image';
    final isVideo = _pendingMediaType == 'video';
    return Container(
      padding: const EdgeInsets.all(8),
      color: theme.cardColor,
      child: Row(
        children: [
          // 预览图/占位
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(8),
            ),
            child: isImage
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _pendingMediaFile!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white54),
                    ),
                  )
                : isVideo
                    ? const Icon(Icons.videocam, color: Colors.white54)
                    : const Icon(Icons.insert_drive_file, color: Colors.white54),
          ),
          const SizedBox(width: 8),
          // 文件名（仅 file 类型）
          if (_pendingFileName != null)
            Expanded(
              child: Text(
                _pendingFileName!,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          const SizedBox(width: 8),
          // 取消按钮：清除预览，回到文本输入
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: l10n.cancel,
            onPressed: () {
              setState(() {
                _pendingMediaType = 'text';
                _pendingMediaUrl = null;
                _pendingMediaFile = null;
                _pendingFileName = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_DisplayMessage msg, bool isMe, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.secondary,
              child: Text(msg.content.isNotEmpty ? msg.content[0] : '?'),
            ),
            const SizedBox(width: 8),
          ],
          // 气泡本体：根据消息类型分发渲染
          Flexible(
            child: _buildMessageBubbleByType(msg, isMe, theme),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.secondary,
              child: const Text('Y'),
            ),
          ],
        ],
      ),
    );
  }

  /// 按消息类型渲染气泡内容
  Widget _buildMessageBubbleByType(_DisplayMessage msg, bool isMe, ThemeData theme) {
    final bubbleColor = isMe ? theme.colorScheme.primary : Colors.grey.shade200;
    final textColor = isMe ? Colors.white : Colors.black87;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: switch (msg.type) {
        // 图片消息：展示图片 URL；data: URL 由 InMemory 降级实现提供
        'image' => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: msg.content.startsWith('data:')
                    ? Image.memory(
                        base64Decode(msg.content.split(',').last),
                        width: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _fallbackPlaceholder(theme, textColor, Icons.broken_image),
                      )
                    : Image.network(
                        msg.content,
                        width: 200,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) =>
                            progress == null ? child : _fallbackPlaceholder(theme, textColor, Icons.image),
                        errorBuilder: (_, __, ___) =>
                            _fallbackPlaceholder(theme, textColor, Icons.broken_image),
                      ),
              ),
              if (msg.createTime != null) ...[
                const SizedBox(height: 4),
                Text(
                  app_date.DateUtils.formatTime(msg.createTime),
                  style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.6)),
                ),
              ],
            ],
          ),
        // 视频消息：展示封面占位，点击播放（此处先用占位，后续可扩展 full-screen player）
        'video' => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => _openVideoPlayer(msg.content),
                child: Container(
                  width: 200,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(Icons.play_circle_outline, size: 48, color: Colors.white70),
                  ),
                ),
              ),
              if (msg.createTime != null) ...[
                const SizedBox(height: 4),
                Text(
                  app_date.DateUtils.formatTime(msg.createTime),
                  style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.6)),
                ),
              ],
            ],
          ),
        // 文件消息：展示文件名 + 下载按钮
        'file' => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => _openFile(msg.content),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.insert_drive_file, size: 28),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        msg.content.split('/').last, // 简单截断文件名
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: textColor, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              if (msg.createTime != null) ...[
                const SizedBox(height: 4),
                Text(
                  app_date.DateUtils.formatTime(msg.createTime),
                  style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.6)),
                ),
              ],
            ],
          ),
        // 文件传输助手（self）：与普通文本相同，但显示特殊标识
        'self' => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade600,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'TA',
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(msg.content, style: TextStyle(color: textColor)),
                  ),
                ],
              ),
              if (msg.createTime != null) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      app_date.DateUtils.formatTime(msg.createTime),
                      style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.6)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        // 表情消息：直接渲染 emoji 字符（大字体）
        'emoji' => Center(
            child: Text(
              msg.content,
              style: const TextStyle(fontSize: 36),
            ),
          ),
        // 默认：文本消息
        _ => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(msg.content, style: TextStyle(color: textColor)),
              if (msg.createTime != null) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      app_date.DateUtils.formatTime(msg.createTime),
                      style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.6)),
                    ),
                    if (msg.status != null) ...[
                      const SizedBox(width: 4),
                      Icon(
                        msg.status == 'read' ? Icons.done_all : Icons.done,
                        size: 12,
                        color: msg.status == 'read' ? Colors.blueAccent : textColor.withOpacity(0.6),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
      },
    );
  }

  /// 气泡内通用占位组件（加载失败、类型不支持时显示）
  Widget _fallbackPlaceholder(ThemeData theme, Color textColor, IconData icon) {
    return Container(
      width: 200,
      height: 150,
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
      child: Icon(icon, color: textColor.withOpacity(0.5), size: 32),
    );
  }

  /// 打开视频播放器（全屏）
  ///
  /// 使用 [video_player] 插件播放本地/网络视频；此处先打印路径以便后续接入完整播放器。
  void _openVideoPlayer(String url) {
    // TODO: 接入 video_player 全屏播放器，当前仅提示
    debugPrint('[ChatDetail] 打开视频: $url');
  }

  /// 打开文件（下载 / 预览）
  ///
  /// 对于媒体 URL，可触发系统分享面板或外部应用打开。
  void _openFile(String url) {
    // TODO: 接入 open_file / share_plus 插件，当前仅提示
    debugPrint('[ChatDetail] 打开文件: $url');
  }

  Widget _buildInputBar(ThemeData theme, AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 表情面板：点击表情按钮时弹出，再次点击关闭
        if (_showEmojiPanel) _buildEmojiPanel(theme),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: theme.cardColor,
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
          ),
          child: Row(
            children: [
              // 表情按钮：点击切换 emoji 面板显示
              IconButton(
                icon: const Icon(Icons.emoji_emotions),
                tooltip: l10n.emoji,
                onPressed: () {
                  setState(() => _showEmojiPanel = !_showEmojiPanel);
                  // 切换面板时清除其他 pending 状态
                  if (!_showEmojiPanel) {
                    _pendingMediaType = 'text';
                    _pendingMediaUrl = null;
                    _pendingMediaFile = null;
                    _pendingFileName = null;
                  }
                },
              ),
              // 附件按钮：点击弹出类型选择（图片/视频/文件/语音）
              PopupMenuButton<String>(
                icon: const Icon(Icons.attach_file),
                tooltip: l10n.attach,
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'image',
                    child: Row(
                      children: [
                        const Icon(Icons.photo_library, size: 18),
                        const SizedBox(width: 8),
                        Text(l10n.image),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'video',
                    child: Row(
                      children: [
                        const Icon(Icons.videocam, size: 18),
                        const SizedBox(width: 8),
                        Text(l10n.video),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'file',
                    child: Row(
                      children: [
                        const Icon(Icons.insert_drive_file, size: 18),
                        const SizedBox(width: 8),
                        Text(l10n.file),
                      ],
                    ),
                  ),
                  // TODO: 语音暂不支持（需接入录音权限与音频上传），后续迭代
                  // PopupMenuItem(value: 'voice', ...),
                ],
                onSelected: (type) {
                  // 切换类型时关闭 emoji 面板
                  setState(() {
                    _showEmojiPanel = false;
                    _pendingMediaType = type;
                  });
                  _onAttachTap();
                },
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: l10n.inputMessage,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.none,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 4),
              // 发送按钮
              IconButton(
                icon: const Icon(Icons.send_rounded),
                color: theme.colorScheme.primary,
                tooltip: l10n.send,
                onPressed: _sendMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建表情选择面板（微信风格：网格布局，点击即发送）
  ///
  /// 面板高度固定（两行 emoji），背景色与输入栏一致，点击 emoji 后立即发送并收起面板。
  Widget _buildEmojiPanel(ThemeData theme) {
    return Container(
      color: theme.cardColor,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: GridView.count(
        crossAxisCount: 8, // 每行 8 个 emoji
        shrinkWrap: true, // 不自适应高度，避免布局溢出
        physics: const NeverScrollableScrollPhysics(), // 禁用面板内部滚动
        childAspectRatio: 1.2, // 宽高比
        children: _emojiList.map((emoji) {
          return GestureDetector(
            onTap: () {
              // 点击 emoji：直接发送，不经过上传流程
              final auth = context.read<AuthProvider>();
              final l10n = AppLocalizations.of(context)!;
              final now = DateTime.now().millisecondsSinceEpoch;
              // 先乐观显示再发送，避免 UI 卡顿
              setState(() => _messages.add(_DisplayMessage(
                id: now,
                fromUserId: auth.userId ?? 0,
                toUserId: widget.targetType == 'file_helper' ? (auth.userId ?? 0) : widget.targetId,
                groupId: widget.targetType == 'group' ? widget.targetId : null,
                type: widget.targetType == 'file_helper' ? 'self' : 'emoji',
                content: emoji,
                createTime: now,
                status: 'sending',
              )));
              _scrollToBottom();
              // 异步发送后关闭面板并更新状态
              _doSendEmoji(emoji, now, auth, ScaffoldMessenger.of(context), l10n).whenComplete(() {
                if (mounted) setState(() => _showEmojiPanel = false);
              });
            },
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 28)),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// 内部消息显示模型
class _DisplayMessage {
  final int id;
  final int fromUserId;
  final int? toUserId;
  final int? groupId;
  final String type;
  final String content;
  final String status;
  final String pushStatus; // 推送状态：pending/server_received/client_ack/delivered
  final int createTime;

  _DisplayMessage({
    required this.id,
    required this.fromUserId,
    this.toUserId,
    this.groupId,
    required this.type,
    required this.content,
    this.status = 'sent',
    this.pushStatus = 'pending',
    required this.createTime,
  });

  factory _DisplayMessage.fromJson(dynamic json) {
    if (json == null) return _DisplayMessage(id: 0, fromUserId: 0, type: 'text', content: '', createTime: 0);
    return _DisplayMessage(
      // 使用安全 int 解析：后端 Long/Date 可能序列化为 String 或 num
      id: MessageUtils.toInt(json['id']),
      fromUserId: MessageUtils.toInt(json['fromUserId']),
      toUserId: MessageUtils.toNullableInt(json['toUserId']),
      groupId: MessageUtils.toNullableInt(json['groupId']),
      type: json['type'] as String? ?? 'text',
      content: json['content'] as String? ?? '',
      status: parseMessageStatus(json['status']),
      pushStatus: json['pushStatus'] as String? ?? 'pending',
      // createTime 兼容 ISO 字符串、毫秒数、DateTime 三种格式
      createTime: json['createTime'] is DateTime
          ? (json['createTime'] as DateTime).millisecondsSinceEpoch
          : MessageUtils.toInt(json['createTime']),
    );
  }

  factory _DisplayMessage.fromModel(MessageModel model) {
    return _DisplayMessage(
      id: model.id,
      fromUserId: model.fromUserId,
      toUserId: model.toUserId,
      groupId: model.groupId,
      type: model.type,
      content: model.content,
      status: model.status,
      pushStatus: model.pushStatus,
      createTime: model.createTime,
    );
  }

  _DisplayMessage copyWith({
    int? id,
    int? fromUserId,
    int? toUserId,
    int? groupId,
    String? type,
    String? content,
    String? status,
    String? pushStatus,
    int? createTime,
  }) {
    return _DisplayMessage(
      id: id ?? this.id,
      fromUserId: fromUserId ?? this.fromUserId,
      toUserId: toUserId ?? this.toUserId,
      groupId: groupId ?? this.groupId,
      type: type ?? this.type,
      content: content ?? this.content,
      status: status ?? this.status,
      pushStatus: pushStatus ?? this.pushStatus,
      createTime: createTime ?? this.createTime,
    );
  }

  MessageModel toModel() {
    return MessageModel(
      id: id,
      fromUserId: fromUserId,
      toUserId: toUserId,
      groupId: groupId,
      type: type,
      content: content,
      status: status,
      pushStatus: pushStatus,
      createTime: createTime,
    );
  }
}
