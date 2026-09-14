import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../core/network/mqtt_client.dart';
import '../../core/constants/ws_cmd.dart';
import '../../config/config.dart';
import '../../core/utils/message_status_parser.dart';
import '../../core/utils/message_delivery_state.dart';
import '../../core/utils/message_utils.dart';
import '../../core/utils/emoji_text_editing.dart';
import '../../models/message_model.dart';
import '../../core/cache/message_cache_manager.dart';
import '../../core/cache/favorite_cache_manager.dart';
import '../../models/favorite_model.dart';
import '../../services/conversation_service.dart';
import '../../providers/chat_provider.dart';
import '../widgets/message_delivery_status.dart';
import '../widgets/message_action_sheet.dart';
import '../widgets/forward_picker_sheet.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/chat_bubble.dart';
import '../../core/theme/app_theme.dart';
import '../../services/contact_service.dart';
import '../../services/chat_background_service.dart';
import '../../core/utils/voice_content_codec.dart';
import 'group_settings_screen.dart';
import 'single_chat_settings_screen.dart';
import 'image_viewer_screen.dart';
import '../../core/utils/date_utils.dart' as app_date;

/// 媒体类型：image / video / audio / file
enum MediaType { image, video, audio, file }

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
  // 输入框 FocusNode，用于表情面板关闭后重新获取焦点
  final _inputFocusNode = FocusNode();
  final _scrollController = ScrollController();
  final List<_DisplayMessage> _messages = [];
  bool _isLoading = true;
  bool _hasMore = false;
  String _sessionId = '';
  MqttChatClient? _mqttClient;

  // 临时选择器状态
  String _pendingMediaType = 'text'; // text / image / video / file / voice
  String? _pendingMediaUrl;
  String? _pendingFileName;

  // 聊天背景路径；null 表示使用默认背景（从 ChatBackgroundService 读取）
  String? _chatBackgroundPath;

  // 表情面板状态
  bool _showEmojiPanel = false;
  // 表情面板删除键的长按连删计时器
  Timer? _emojiDeleteTimer;
  // 微信风格附件面板状态：点「+」后在输入栏上方展开图片/视频/文件
  bool _showAttachPanel = false;


  // 视频播放器控制器（每个视频消息独立持有）
  final Map<int, VideoPlayerController> _videoPlayers = {};

  // 音频播放器（全局单例，同一时刻只播一条语音）
  final AudioPlayer _audioPlayer = AudioPlayer();

  // 录音状态（record 4.4.4 使用 Record 类，非 AudioRecorder）
  final Record _recorder = Record();
  bool _isRecording = false;
  Duration? _recordDuration;
  // 长按录音：录音计时器（每秒刷新覆盖层时长）
  Timer? _recordTimer;
  // 长按录音：手指按下时的全局 Y 坐标，用于判断上滑取消
  double _recordStartY = 0;
  // 长按录音：当前是否处于"上滑取消"状态（覆盖层变红提示）
  bool _isCancelling = false;
  // 语音输入模式：true 时输入栏显示"按住说话"按钮而非文本框
  bool _voiceMode = false;

  // 当前播放中的语音消息 ID（用于气泡更新播放状态）
  int? _playingVoiceMsgId;

  @override
  void initState() {
    super.initState();
    _markConversationRead();
    _initCache();
    _initMqtt();
    // 异步加载用户设置的聊天背景，不阻塞首帧
    _loadChatBackground();
    // 监听输入内容变化：切换「发送」金色按钮与「+」附件按钮的显隐
    _controller.addListener(_onInputChanged);
  }

  void _onInputChanged() {
    if (mounted) setState(() {});
  }

  /// 从 ChatBackgroundService 读取聊天背景路径
  Future<void> _loadChatBackground() async {
    final path = await ChatBackgroundService().getBackgroundPath();
    if (!mounted) return;
    // 仅在确实是本地已存在的文件时应用，否则回退默认背景
    if (path != null && await File(path).exists()) {
      setState(() => _chatBackgroundPath = path);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    _stopRepeatDelete();
    _mqttClient?.disconnect();
    // 释放所有视频播放器
    for (final controller in _videoPlayers.values) {
      controller.dispose();
    }
    _videoPlayers.clear();
    // 停止音频播放
    _audioPlayer.stop();
    // 停止录音计时器与录音（如有）
    _recordTimer?.cancel();
    if (_isRecording) {
      _recorder.stop();
    }
    super.dispose();
  }

  /// 进入聊天页时把该会话标记为已读。
  ///
  /// 这里**不再新建会话记录**：原先每进一次聊天就写一条会话（还把对方名字当
  /// 最后一条消息存进去），从通讯录反复进入就会让聊天列表出现「同名重复」的条目，
  /// 并且每进一次都把该会话顶到列表最前，像是"新打开了一条数据"。
  /// 会话记录统一由「真的发出/收到消息」时创建；这里只清未读，
  /// 既不动最后消息与时间，也不会覆盖用户设置的置顶/免打扰。
  Future<void> _markConversationRead() async {
    final auth = context.read<AuthProvider>();
    if (auth.userId == null) return;

    // 本地：清掉该会话的未读计数（会话不存在则什么也不做，不新建）
    await ConversationService().clearUnread(
      context: context,
      targetId: widget.targetId,
      targetType: widget.targetType,
    );
    // 服务端：同步已读回执
    ChatService(auth.apiClient).markAsRead(auth.userId!, widget.targetId, widget.targetType);

    if (!mounted) return;
    context.read<ChatProvider>().clearUnread(widget.targetId, widget.targetType);
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
    await _loadHistory();
    _fetchUndelivered();
  }

  void _initMqtt() async {
    if (!AppConfig.enableMqtt) {
      debugPrint('[ChatDetail] MQTT disabled by config, skipping connection');
      return;
    }
    final auth = context.read<AuthProvider>();
    final userId = auth.userId ?? 0;
    final chatClientId = 'user_${userId}_chat_${widget.targetId}_${widget.targetType}';
    _mqttClient = MqttChatClient(
      host: AppConfig.mqttHost,
      port: AppConfig.mqttPort,
      onMessage: _handleMqttMessage,
    );
    await _mqttClient?.connect(
      userId: userId,
      username: AppConfig.mqttUsername,
      password: AppConfig.mqttPassword,
      clientId: chatClientId,
    );
    if (widget.targetType == 'group') {
      _mqttClient?.subscribeGroup(widget.targetId);
    }
  }

  /// 处理 MQTT 收到的消息
  Future<void> _handleMqttMessage(int cmd, dynamic data) async {
    if (!mounted) return;
    debugPrint('[ChatDetail] _handleMqttMessage cmd=$cmd, data=$data');
    if (cmd == WsCmd.msgPush) {
      final fromUserId = MessageUtils.toNullableInt(data['fromUserId']);
      final toUserId = MessageUtils.toNullableInt(data['toUserId']);
      final groupId = MessageUtils.toNullableInt(data['groupId']);
      bool isRelated = false;
      if (widget.targetType == 'group') {
        isRelated = groupId == widget.targetId;
      } else if (widget.targetType == 'file_helper') {
        final auth = context.read<AuthProvider>();
        isRelated = fromUserId == auth.userId && toUserId == auth.userId;
      } else {
        final auth = context.read<AuthProvider>();
        isRelated = (fromUserId == widget.targetId && toUserId == auth.userId) ||
                    (fromUserId == auth.userId && toUserId == widget.targetId);
      }
      debugPrint('[ChatDetail] isRelated=$isRelated, targetType=${widget.targetType}, targetId=${widget.targetId}');
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
        if (fromUserId != null && fromUserId != (context.read<AuthProvider>().userId ?? 0)) {
          _sendReceipt(incoming.id);
        }
      }
    } else if (cmd == WsCmd.msgReceiptAck) {
      final msgId = MessageUtils.toNullableInt(data['messageId']);
      if (msgId != null) {
        debugPrint('[ChatDetail] msgReceiptAck for msgId=$msgId');
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
      if (messages.isNotEmpty && mounted) {
        setState(() {
          _messages.sort((a, b) => a.createTime.compareTo(b.createTime));
        });
        _scrollToBottom();
      }
    }
  }

  void _sendReceipt(int messageId) {
    final auth = context.read<AuthProvider>();
    if (auth.userId == null) return;
    final service = ChatService(auth.apiClient);
    service.sendReceipt(messageId, auth.userId!, widget.targetId, widget.targetType);
  }

  void _fetchUndelivered() async {
    final auth = context.read<AuthProvider>();
    if (auth.userId == null) return;
    final service = ChatService(auth.apiClient);
    final messages = await service.fetchUndelivered(auth.userId!, widget.targetId, widget.targetType);
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
    if (!mounted) return;
    setState(() => _isLoading = true);
    final service = ChatService(auth.apiClient);
    final messages = await service.getHistory(
      userId: auth.userId!,
      targetId: widget.targetId,
      targetType: widget.targetType,
      page: 1,
      size: 30,
    );
    for (final m in messages) {
      await MessageCacheManager().appendMessage(_sessionId, m);
    }
    // 页面可能已关闭，检查后才会更新 UI
    if (!mounted) return;
    final cached = await MessageCacheManager().recentMessages(_sessionId, limit: 30);
    if (!mounted) return;
    setState(() {
      final merged = <int, _DisplayMessage>{};
      for (final m in _messages) merged[m.id] = m;
      for (final m in cached) {
        final display = _DisplayMessage.fromModel(m);
        merged[display.id] = display;
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

  /// 使用 wechat_assets_picker 选择媒体（图片/视频/音频/文件）
  ///
  /// [type] 决定 RequestType：image / video / audio / file（file 由 file_picker 处理）。
  /// 除 file 外的类型走相册选择器；file 类型走 [file_picker]（见 [_pickAnyFile]）。
  /// 选择完成后回调 [onPicked] 携带 File
  Future<void> _pickAsset({
    required MediaType type,
    required void Function(File) onPicked,
  }) async {
    try {
      // file 类型：相册选择器只支持媒体，无法选任意文件，故改用 file_picker
      if (type == MediaType.file) {
        await _pickAnyFile(onPicked);
        return;
      }
      // 媒体类型：映射到相册选择器的 RequestType
      final RequestType requestType;
      if (type == MediaType.image) {
        requestType = RequestType.image;
      } else if (type == MediaType.video) {
        requestType = RequestType.video;
      } else {
        requestType = RequestType.audio;
      }
      final List<AssetEntity>? results = await AssetPicker.pickAssets(
        context,
        pickerConfig: AssetPickerConfig(
          requestType: requestType,
          maxAssets: 1,
          gridCount: 4,
          themeColor: Theme.of(context).colorScheme.primary,
          textDelegate: AssetPickerTextDelegate(),
        ),
      );
      if (results == null || results.isEmpty) return;
      // 获取本地文件：wechat_assets_picker 9.x 的 AssetEntity.file 返回 File?
      final file = await results.first.file;
      if (file == null) return;
      onPicked(file);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context)!.pickAssetFailed}: $e')),
      );
    }
  }

  /// 使用 file_picker 选择任意类型的本地文件（文档/压缩包/音视频等）
  ///
  /// 与相册选择器（wechat_assets_picker）互补：相册只能选媒体，
  /// 本方法可以选通用文件。选择完成后通过 [onPicked] 回调把选中的
  /// [File] 交给调用方，统一走已有的"上传→发送"链路（见 [_onMediaPicked]）。
  ///
  /// @param onPicked 选中文件后的回调，携带选中的 [File]
  Future<void> _pickAnyFile(void Function(File) onPicked) async {
    try {
      // 打开系统文件选择器：允许所有文件类型，单选
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      // 用户取消选择时 result 为 null，直接返回不报错
      if (result == null || result.files.isEmpty) return;
      // 取第一个（单选场景）文件的本机路径
      final path = result.files.single.path;
      // Web 平台下 path 为 null；本项目为移动端，此处做判空防御
      if (path == null) return;
      // 把选中的文件交给调用方统一处理（上传→发送）
      onPicked(File(path));
    } catch (e) {
      // 选择失败时给出提示，不中断其它交互
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context)!.pickAssetFailed}: $e')),
      );
    }
  }

  /// 长按开始录音（微信风格：按住说话）
  Future<void> _onRecordStart(double globalY) async {
    try {
      if (!await _recorder.hasPermission()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.voicePermissionDenied)),
        );
        return;
      }
      final path = '${(await getTemporaryDirectory()).path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(path: path);
      setState(() {
        _isRecording = true;
        _recordDuration = Duration.zero;
        _recordStartY = globalY;
        _isCancelling = false;
      });
      // 每秒刷新录音时长（覆盖层显示）
      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || !_isRecording) {
          timer.cancel();
          return;
        }
        setState(() {
          _recordDuration = (_recordDuration ?? Duration.zero) + const Duration(seconds: 1);
        });
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context)!.voiceRecordFailed}: $e')),
      );
    }
  }

  /// 长按移动：判断是否上滑进入取消区域
  void _onRecordMove(double globalY) {
    if (!_isRecording) return;
    // 上滑超过 80px 进入取消状态
    final shouldCancel = (_recordStartY - globalY) > 80;
    if (shouldCancel != _isCancelling) {
      setState(() => _isCancelling = shouldCancel);
    }
  }

  /// 长按结束：根据是否处于取消状态决定发送或丢弃
  Future<void> _onRecordEnd() async {
    if (!_isRecording) return;
    _recordTimer?.cancel();
    _recordTimer = null;

    final duration = _recordDuration ?? Duration.zero;
    final wasCancelling = _isCancelling;

    try {
      final path = await _recorder.stop();
      setState(() {
        _isRecording = false;
        _isCancelling = false;
      });

      // 取消：直接丢弃录音文件
      if (wasCancelling) {
        if (path != null) {
          final f = File(path);
          if (await f.exists()) await f.delete();
        }
        return;
      }

      // 时长不足 1 秒：提示太短
      if (duration.inSeconds < 1) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.recordingTooShort)),
        );
        if (path != null) {
          final f = File(path);
          if (await f.exists()) await f.delete();
        }
        return;
      }

      // 正常发送：上传 + 编码时长 + 直接发送（跳过预览）
      if (path == null) return;
      final file = File(path);
      _uploadAndSendVoice(file, duration.inSeconds);
    } catch (e) {
      setState(() {
        _isRecording = false;
        _isCancelling = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context)!.voiceStopFailed}: $e')),
      );
    }
  }

  /// 上传语音文件并直接发送（携带时长编码）
  void _uploadAndSendVoice(File file, int durationSeconds) {
    final l10n = AppLocalizations.of(context)!;
    final service = ChatService(context.read<AuthProvider>().apiClient);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${l10n.uploading}...')),
    );
    service.uploadMedia(file, 'voice').then((result) {
      if (!mounted) return;
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.uploadFailed)),
        );
        return;
      }
      // 编码 content 为 "url|秒数" 格式
      final encodedContent = VoiceContentCodec.encode(result.url, durationSeconds);
      // 直接发送（跳过预览步骤）
      final auth = context.read<AuthProvider>();
      final now = DateTime.now().millisecondsSinceEpoch;
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      _doSendMedia('voice', encodedContent, null, now, auth, scaffoldMessenger, l10n);
    }).catchError((e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.uploadFailed}: $e')),
      );
    });
  }

  /// 发送消息（含文本 / 图片 / 视频 / 文件 / 语音）
  Future<void> _sendMessage() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    final auth = context.read<AuthProvider>();
    final now = DateTime.now().millisecondsSinceEpoch;

    // 分支 1：用户选择了媒体/文件/语音，先上传再发送
    if (_pendingMediaType != 'text' && _pendingMediaUrl != null) {
      final type = _pendingMediaType;
      final content = _pendingMediaUrl!;
      final fileName = _pendingFileName;
      setState(() {
        _pendingMediaType = 'text';
        _pendingMediaUrl = null;
                _pendingFileName = null;
      });
      await _doSendMedia(type, content, fileName, now, auth, scaffoldMessenger, l10n);
      return;
    }

    // 分支 2：用户选择了 emoji，直接发送
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

    // 分支 3：纯文本发送
    final text = _controller.text.trim();
    if (text.isEmpty) return;
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
    final service = ChatService(auth.apiClient);
    final bool isFileHelper = widget.targetType == 'file_helper';
    final sentModel = _DisplayMessage(
      id: now,
      fromUserId: auth.userId ?? 0,
      toUserId: isFileHelper ? (auth.userId ?? 0) : widget.targetId,
      groupId: isFileHelper ? null : (widget.targetType == 'group' ? widget.targetId : null),
      type: isFileHelper ? 'self' : 'text',
      content: text,
      createTime: now,
      status: 'sent',
    );
    final success = isFileHelper
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
            lastMsg: text,
            lastMsgTime: now,
            unreadCount: 0,
          ),
        );
        await ConversationService().saveSession(
          context: context,
          targetId: widget.targetId,
          targetType: widget.targetType,
          lastMsg: text,
          lastMsgTime: now,
          unreadCount: 0,
        );
      }
    }
    if (!success && mounted) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text(l10n.messageFailed)));
    }
  }

  /// 发送媒体/文件/语音消息：上传到对象存储 → 构造 MessageModel → 发送
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
    if (!mounted) return;
    setState(() => _messages.add(sentModel));
    _scrollToBottom();
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
        // 会话摘要用中文占位（[图片]/[视频]/[文件]/[语音]）：
        // content 是对象存储 URL，直接存进摘要会让聊天列表显示一长串地址
        final summary = MessageUtils.getMessagePreview(type, content);
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
          context: context,
          targetId: widget.targetId,
          targetType: widget.targetType,
          lastMsg: summary,
          lastMsgTime: now,
          unreadCount: 0,
        );
      }
    }
    if (!success && mounted) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text(l10n.messageFailed)));
    }
  }

  /// 发送 emoji 消息（纯前端直接发送，无需上传）
  Future<void> _doSendEmoji(
    String emoji,
    int now,
    AuthProvider auth,
    ScaffoldMessengerState scaffoldMessenger,
    AppLocalizations l10n,
  ) async {
    final service = ChatService(auth.apiClient);
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
    if (!mounted) return;
    setState(() => _messages.add(sentModel));
    _scrollToBottom();
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
          context: context,
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

  /// 用户点击附件面板中的某一项：按类型触发对应选择器
  ///
  /// 与微信一致：选完即上传并直接发送，不再要求用户再点一次「发送」。
  /// 选完收起附件面板与键盘，避免面板挡住刚发出的消息。
  /// [_pendingMediaType] 仍需更新，供上传失败时的提示文案复用。
  void _onAttachTap(String type) {
    setState(() {
      _pendingMediaType = type;
      _showAttachPanel = false;
      _showEmojiPanel = false;
      _inputFocusNode.unfocus();
    });
    switch (type) {
      case 'image':
        _pickAsset(type: MediaType.image, onPicked: (f) => _onMediaPicked(f, 'image'));
        break;
      case 'video':
        _pickAsset(type: MediaType.video, onPicked: (f) => _onMediaPicked(f, 'video'));
        break;
      case 'file':
        _pickAsset(type: MediaType.file, onPicked: (f) => _onMediaPicked(f, 'file'));
        break;
      default:
        break;
    }
  }

  /// 选择媒体/文件后的统一处理：上传 → 直接发送
  ///
  /// 1. 上传到对象存储（POST /file/media/{type}），后端返回**可访问的 URL**
  ///    （disk 存储为 http(s) 地址，不再是把整张图塞进消息体的 base64）；
  /// 2. 用该 URL 作为消息 content 立即发送（微信行为，无需二次确认）。
  ///
  /// 历史消息里可能已存在 base64 data URL 的老数据，渲染侧仍兼容（见
  /// [_buildMessageBubbleByType]），这里不再新增。
  void _onMediaPicked(File file, String type) {
    final l10n = AppLocalizations.of(context)!;
    final service = ChatService(context.read<AuthProvider>().apiClient);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${l10n.uploading}...')),
    );
    service.uploadMedia(file, type).then((result) {
      if (!mounted) return;
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.uploadFailed)),
        );
        return;
      }
      // 上传成功：URL 就是消息内容，直接发送
      final auth = context.read<AuthProvider>();
      final now = DateTime.now().millisecondsSinceEpoch;
      final fileName = type == 'file' ? file.path.split('/').last : null;
      _doSendMedia(
        type,
        result.url,
        fileName,
        now,
        auth,
        ScaffoldMessenger.of(context),
        l10n,
      );
      // 复位待发状态，避免下次点「发送」把这条媒体再发一遍
      setState(() {
        _pendingMediaType = 'text';
        _pendingMediaUrl = null;
                _pendingFileName = null;
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
        _scrollController.animateTo(
          _scrollController.position.minScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final displayName = widget.targetName ?? l10n.myFriends;

    return Scaffold(
      appBar: AppBar(
        // 与通讯录/会话列表同一套写法：深色底、扁平无阴影、标题居中，
        // 由全局 AppBarTheme 统一提供，避免各页各写一份硬编码色值
        title: Text(displayName),
        actions: [
          if (widget.targetType == 'group') ...[
            // 群聊：设置入口（群聊信息/查找记录/置顶/免打扰/清空记录等集中到群聊设置页）
            IconButton(
              icon: const Icon(Icons.more_vert),
              tooltip: l10n.groupSettings,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GroupSettingsScreen(
                      groupId: widget.targetId,
                      targetType: widget.targetType,
                      targetName: widget.targetName,
                    ),
                  ),
                );
              },
            ),
          ] else ...[
            // 单聊：清空/置顶/免打扰/投诉等集中到单聊设置页
            IconButton(
              icon: const Icon(Icons.more_vert),
              tooltip: l10n.chatSettings,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SingleChatSettingsScreen(
                      targetId: widget.targetId,
                      targetType: widget.targetType,
                      targetName: widget.targetName,
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // 消息区：有背景图时用 Stack 把图片垫在列表下方
              Expanded(
                child: _chatBackgroundPath != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          // 背景图铺满消息区
                          Image.file(
                            File(_chatBackgroundPath!),
                            fit: BoxFit.cover,
                          ),
                          // 半透明遮罩提升文字可读性
                          const DecoratedBox(
                            decoration: BoxDecoration(color: Color(0x66000000)),
                          ),
                          // 消息列表叠在背景之上
                          _buildMessageBody(theme, l10n),
                        ],
                      )
                    : _buildMessageBody(theme, l10n),
              ),
              _buildInputBar(theme, l10n),
            ],
          ),
          // 录音中覆盖层：显示时长与上滑取消提示
          if (_isRecording) _buildRecordingOverlay(l10n),
        ],
      ),
    );
  }

  /// 消息列表主体（含空态提示）；被 [_build] 的背景 Stack 或直接使用
  Widget _buildMessageBody(ThemeData theme, AppLocalizations l10n) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _messages.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.chat_bubble_outline, size: 48, color: Colors.white24),
                    const SizedBox(height: 8),
                    Text(l10n.noMessages, style: const TextStyle(color: Colors.white54)),
                  ],
                ),
              )
            : NotificationListener<ScrollNotification>(
                onNotification: (notification) {
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
              );
  }

  Widget _buildMessageBubble(_DisplayMessage msg, bool isMe, ThemeData theme) {
    // 对标 win-chat：气泡箭头指向头像，头像侧需预留箭头伸出的宽度
    final avatarGap = SizedBox(width: BubbleContainer.arrowLen + 2);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            AvatarWidget(
              // 群聊/私聊对方头像：暂无好友目录数据，用会话名首字占位
              initials: (widget.targetName?.isNotEmpty ?? false)
                  ? widget.targetName![0]
                  : '?',
              size: 36,
            ),
            const SizedBox(width: 6),
            avatarGap,
          ],
          Flexible(
            child: GestureDetector(
              // 长按气泡弹出操作菜单（复制/撤回/转发）
              onLongPress: () => _showMessageActionMenu(msg, isMe),
              child: _buildMessageBubbleByType(msg, isMe, theme),
            ),
          ),
          if (isMe) ...[
            avatarGap,
            const SizedBox(width: 6),
            AvatarWidget(
              // 自己的头像用登录态里的真实头像，无头像时退回昵称首字
              imageUrl: context.read<AuthProvider>().avatar,
              initials: _myInitial(),
              size: 36,
            ),
          ],
        ],
      ),
    );
  }

  /// 自己的昵称首字（头像占位用），拿不到时用「我」
  String _myInitial() {
    final nickname = context.read<AuthProvider>().nickname;
    return (nickname != null && nickname.isNotEmpty) ? nickname[0] : '我';
  }

  Widget _buildMessageBubbleByType(_DisplayMessage msg, bool isMe, ThemeData theme) {
    // 对标 win-chat 夜间主题：我方金底黑字、对方灰紫底白字；
    // 图片/视频/大表情/撤回提示不走彩色气泡（参考项目这类消息不带底色）
    final bool bubbleless = switch (msg.type) {
      'image' || 'video' || 'emoji' || 'recall' => true,
      _ => false,
    };
    final Color textColor = isMe
        ? (bubbleless ? Colors.white : AppTheme.bubbleSentText)
        : AppTheme.bubbleReceivedText;
    final Widget content = switch (msg.type) {
        'image' => _buildImageBubble(msg, textColor),
        'video' => _buildVideoBubble(msg, textColor),
        'voice' => _buildVoiceBubble(msg, isMe, textColor),
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
                        msg.content.split('/').last,
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
        // 文件传输助手消息（type=self）：内容就是普通文本，
        // 与默认文本分支同样渲染（去掉旧版的绿色「TA」徽章）
        'self' => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(msg.content, style: TextStyle(color: textColor)),
              if (msg.createTime != null) ...[
                const SizedBox(height: 4),
                Text(
                  app_date.DateUtils.formatTime(msg.createTime),
                  style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.6)),
                ),
              ],
            ],
          ),
        'emoji' => Center(
            child: Text(
              msg.content,
              style: const TextStyle(fontSize: 36),
            ),
          ),
        // 撤回消息：居中、斜体、浅灰，弱化视觉层级，与普通消息明显区分
        'recall' => Center(
            child: Text(
              AppLocalizations.of(context)!.messageRecalled,
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade500,
              ),
            ),
          ),
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
                    // 仅本人发送的消息展示送达/已读状态图标
                    // （由 status 与 pushStatus 推导：发送中/失败/已发送/已送达）
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      MessageDeliveryStatus(
                        state: resolveDeliveryState(
                          status: msg.status,
                          pushStatus: msg.pushStatus,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
    };
    // 文本/语音/文件等走带箭头的彩色气泡；图片/视频/表情/撤回提示不带底色
    if (bubbleless) return content;
    return BubbleContainer(isMe: isMe, child: content);
  }
  /// 图片气泡：消息内容是后端对象存储返回的**可访问 URL**，直接按网络图渲染
  ///
  /// 历史消息里可能还残留旧版写入的 base64 data URI（整张图内嵌在消息体里），
  /// 这里保留兼容分支，但新发的图片一律走 URL —— 消息体只有几十字节，
  /// 对方拉历史时也不会拖回几 MB 的字符串。
  ///
  /// 点击统一走 [_openMediaPreview] 进入大图查看页（支持缩放与保存）。
  Widget _buildImageBubble(_DisplayMessage msg, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _openMediaPreview(msg),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: msg.content.startsWith('data:')
                ? Image.memory(
                    base64Decode(msg.content.split(',').last),
                    width: 180,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _mediaPlaceholder(Icons.broken_image),
                  )
                : CachedNetworkImage(
                    imageUrl: msg.content,
                    width: 180,
                    fit: BoxFit.cover,
                    // 加载中与失败都给出明确占位，避免气泡塌陷成一条细线
                    placeholder: (_, __) => _mediaPlaceholder(Icons.image),
                    errorWidget: (_, __, ___) =>
                        _mediaPlaceholder(Icons.broken_image),
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
    );
  }

  /// 视频气泡：深色封面 + 居中播放按钮，点击进入全屏播放
  ///
  /// 视频首帧需要先把整个文件拉下来解码，代价过高，故用统一的播放封面代替
  /// （与微信「未下载 video 消息」的展现一致）。
  Widget _buildVideoBubble(_DisplayMessage msg, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _openMediaPreview(msg),
          child: Container(
            width: 180,
            height: 140,
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Icon(Icons.play_circle_fill, size: 44, color: Colors.white70),
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
    );
  }

  /// 媒体消息统一预览入口：图片进大图查看页，视频进全屏播放器，文件走打开逻辑
  void _openMediaPreview(_DisplayMessage msg) {
    switch (msg.type) {
      case 'image':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ImageViewerScreen(content: msg.content),
          ),
        );
        break;
      case 'video':
        _openVideoPlayer(msg.id, msg.content);
        break;
      case 'file':
        _openFile(msg.content);
        break;
    }
  }

  /// 媒体占位图：加载中/失败时保持气泡尺寸稳定
  Widget _mediaPlaceholder(IconData icon) {
    return Container(
      width: 180,
      height: 140,
      color: const Color(0xFF2C2C2E),
      child: Icon(icon, color: Colors.white38, size: 32),
    );
  }

  /// 打开视频播放器（全屏）
  Future<void> _openVideoPlayer(int msgId, String url) async {
    // 若已存在控制器则复用，否则创建
    final controller = _videoPlayers[msgId] ?? VideoPlayerController.networkUrl(Uri.parse(url));
    if (_videoPlayers[msgId] == null) {
      _videoPlayers[msgId] = controller;
      try {
        await controller.initialize();
      } catch (e) {
        debugPrint('[ChatDetail] 视频初始化失败: $e');
        return;
      }
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(controller: controller, url: url),
      ),
    );
    // 导航返回后 dispose 控制器释放资源
    if (mounted) {
      final c = _videoPlayers.remove(msgId);
      c?.dispose();
    }
  }

  /// 语音气泡：显示时长 + 波形图标，点击播放/停止
  ///
  /// 微信风格：自己发的语音波形在右侧，对方的在左侧；
  /// 气泡宽度随时长增加（越长越宽，上限 200）。
  Widget _buildVoiceBubble(_DisplayMessage msg, bool isMe, Color textColor) {
    // 解码 content 获取 URL 与时长
    final voice = VoiceContentCodec.decode(msg.content);
    final isPlaying = _playingVoiceMsgId == msg.id;
    // 气泡宽度随时长增加（模拟微信：越长越宽，上限 200）
    final bubbleWidth = (80.0 + voice.durationSeconds * 4).clamp(80.0, 200.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => _playVoice(msg.id, voice.url),
          child: Container(
            width: bubbleWidth,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              // 自己发的：时长在左，波形在右；对方的：波形在左，时长在右
              mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: isMe
                  ? [
                      // 时长文本
                      Text(
                        VoiceContentCodec.formatDuration(voice.durationSeconds),
                        style: TextStyle(color: textColor, fontSize: 14),
                      ),
                      const SizedBox(width: 8),
                      // 波形/播放图标
                      Icon(
                        isPlaying ? Icons.stop_circle : Icons.graphic_eq,
                        color: textColor,
                        size: 22,
                      ),
                    ]
                  : [
                      // 波形/播放图标
                      Icon(
                        isPlaying ? Icons.stop_circle : Icons.graphic_eq,
                        color: textColor,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      // 时长文本
                      Text(
                        VoiceContentCodec.formatDuration(voice.durationSeconds),
                        style: TextStyle(color: textColor, fontSize: 14),
                      ),
                    ],
            ),
          ),
        ),
        if (msg.createTime != null) ...[
          const SizedBox(height: 4),
          Text(
            app_date.DateUtils.formatTime(msg.createTime),
            style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.6)),
          ),
        ],
      ],
    );
  }

  /// 播放语音消息
  ///
  /// [msgId] 消息 ID（用于气泡图标切换）；[url] 音频 URL。
  /// 使用 [AudioPlayer] 播放网络音频；播放中点击停止，播放结束自动重置状态。
  Future<void> _playVoice(int msgId, String url) async {
    try {
      // 若正在播放同一条语音则停止
      if (_playingVoiceMsgId == msgId) {
        await _audioPlayer.stop();
        setState(() => _playingVoiceMsgId = null);
        return;
      }
      // 停止其他语音（若有）
      await _audioPlayer.stop();
      // 设置播放源（网络 URL）并播放；audioplayers 6.x play() 需要 Source 参数
      setState(() => _playingVoiceMsgId = msgId);
      await _audioPlayer.play(UrlSource(url));
      // 播放结束自动重置状态
      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() => _playingVoiceMsgId = null);
        }
      });
    } catch (e) {
      debugPrint('[ChatDetail] 播放语音失败: $e');
      setState(() => _playingVoiceMsgId = null);
    }
  }

  /// 打开文件（下载 / 预览）
  void _openFile(String url) {
    // TODO: 接入 open_file / share_plus 插件
    debugPrint('[ChatDetail] 打开文件: $url');
  }

  /// 长按消息弹出操作菜单（复制/撤回/转发）
  ///
  /// [msg] 被按下的消息；[isMe] 是否本人发送（决定撤回权限）。
  /// 需求2 启用"撤回"：仅本人消息、已发送成功且处于 2 分钟撤回时限内才显示撤回项；
  /// 转发(canForward)在需求3 再启用。
  Future<void> _showMessageActionMenu(_DisplayMessage msg, bool isMe) async {
    // 判断当前是否允许撤回：本人 + 已发送 + 2 分钟内，且该消息尚未被撤回
    final canRecall = msg.type != 'recall' &&
        MessageUtils.canRecallMessage(
          isMe: isMe,
          createTime: msg.createTime,
          status: msg.status,
          nowMillis: DateTime.now().millisecondsSinceEpoch,
        );
    // 仅文本/图片消息可收藏（对标唐道道"收藏模块"：可收藏文本/图片消息）
    final canFavorite = msg.type == 'text' || msg.type == 'image';
    // 弹出底部操作菜单，返回用户所选动作；取消则返回 null
    final action = await showMessageActionSheet(
      context,
      canRecall: canRecall, // 需求2：仅满足撤回条件的消息才显示"撤回"
      canForward: true, // 需求3：启用"转发"到其他会话
      canFavorite: canFavorite, // 收藏：文本/图片消息可收藏
    );
    // 用户取消或页面已关闭则不继续
    if (action == null || !mounted) return;
    await _handleMessageAction(msg, isMe, action);
  }

  /// 执行用户选择的消息操作：复制 / 撤回 / 转发
  ///
  /// [msg] 目标消息；[isMe] 是否本人发送（用于撤回权限判断）。
  Future<void> _handleMessageAction(_DisplayMessage msg, bool isMe, MessageAction action) async {
    // 读取本地化文案，避免硬编码
    final l10n = AppLocalizations.of(context)!;
    switch (action) {
      case MessageAction.copy:
        // 把消息内容写入系统剪贴板，供用户随意粘贴
        await Clipboard.setData(ClipboardData(text: msg.content));
        // 复制成功后轻提示"已复制"
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.copied)));
        }
        break;
      case MessageAction.recall:
        // README：调用后端撤回接口，成功后把本地消息标记为"已撤回"
        final recallAuth = context.read<AuthProvider>();
        if (recallAuth.userId == null) break;
        final recallService = ChatService(recallAuth.apiClient);
        final recalled = await recallService.recallMessage(recallAuth.userId!, msg.id);
        if (!mounted) break;
        if (recalled) {
          // 构造撤回后的消息：类型改为 recall、内容换成"消息已撤回"
          final recalledMsg = msg.copyWith(
            type: 'recall',
            content: l10n.messageRecalled,
          );
          // 就地替换 UI 列表中的消息，让其立即显示为"已撤回"
          final idx = _messages.indexWhere((m) => m.id == msg.id);
          if (idx != -1) {
            setState(() => _messages[idx] = recalledMsg);
          }
          // 持久化到本地 SQLite，重新加载历史时仍保持"已撤回"
          await MessageCacheManager()
              .updateMessageTypeAndContent(
                _sessionId,
                msg.id,
                type: 'recall',
                content: l10n.messageRecalled,
              );
        } else {
          // 撤回失败（例如已超时被服务端拒绝），轻提示告知用户
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l10n.recallFailed)));
        }
        break;
      case MessageAction.forward:
        // README：弹出目标选择器，把消息转发到其他会话（好友私聊）
        await _forwardMessage(msg);
        break;
      case MessageAction.favorite:
        // 收藏当前消息（仅文本/图片可进入此分支）
        await _favoriteMessage(msg, isMe);
        break;
    }
  }

  /// 收藏一条消息到本地（对标唐道道"收藏模块"文本/图片消息可收藏）
  ///
  /// [msg] 目标消息；[isMe] 是否本人发送（用于记录发送者昵称）。
  /// 已收藏的消息再次收藏给出"该消息已收藏"提示，避免重复。
  Future<void> _favoriteMessage(_DisplayMessage msg, bool isMe) async {
    final l10n = AppLocalizations.of(context)!;
    final auth = context.read<AuthProvider>();
    if (auth.userId == null) return;

    // 收藏管理器需要知道当前用户，以生成带用户ID前缀的表
    final cache = FavoriteCacheManager();
    cache.setUserId(auth.userId!);

    // 同一消息只能收藏一次，重复收藏时友好提示
    if (await cache.contains(msg.id)) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.alreadyFavorited)));
      }
      return;
    }

    // 发送者昵称：本人消息记自己的昵称，否则记对方展示名（私聊取对方昵称，群聊取群名）
    final fromNickname = isMe ? (auth.nickname ?? '') : (widget.targetName ?? '');

    // 组装收藏记录并写入本地 SQLite
    final favorite = FavoriteModel(
      messageId: msg.id,
      type: msg.type,
      content: msg.content,
      fromUserId: msg.fromUserId,
      fromNickname: fromNickname,
      createTime: DateTime.now().millisecondsSinceEpoch,
    );
    await cache.add(favorite);

    // 收藏成功后轻提示
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.favoriteAdded)));
    }
  }

  /// 消息转发：展示好友列表供选择，把当前消息发送到所选会话
  ///
  /// 转发逻辑：复用原消息的 [type] 与 [content]（图片/文件等 content 为已上传的
  /// URL，可直接复用），以"我"为发送人、目标好友为接收人，构造一条新消息发送。
  ///
  /// @param msg 被转发的原消息
  Future<void> _forwardMessage(_DisplayMessage msg) async {
    // 读取本地化文案与登录用户
    final l10n = AppLocalizations.of(context)!;
    final auth = context.read<AuthProvider>();
    if (auth.userId == null) return;

    // 加载好友列表作为转发目标（本地优先，避免卡顿）
    final friends = await ContactService(auth.apiClient).getLocalFriends(context);
    if (!mounted) return;
    // 组装转发目标：私聊目标类型统一为 friend
    final targets = friends.map((f) {
      // 显示名取昵称，缺失时用"用户 {id}"兜底
      final name = f.nickname.isNotEmpty ? f.nickname : '用户 ${f.userId}';
      return ForwardTarget(
        targetId: f.userId,
        targetType: 'friend',
        displayName: name,
        avatar: f.avatar,
      );
    }).toList();

    // 弹出转发目标选择器；用户取消则返回 null，直接结束
    final target = await showForwardPickerSheet(context, targets);
    if (target == null || !mounted) return;

    // 构造转发消息：新消息ID用当前时间戳，类型/内容沿用原消息
    final now = DateTime.now().millisecondsSinceEpoch;
    final forwarded = MessageModel(
      id: now,
      fromUserId: auth.userId!,
      toUserId: target.targetId,
      groupId: null, // 私聊无群组ID
      type: msg.type,
      content: msg.content,
      status: 'sent',
      pushStatus: 'pending',
      createTime: now,
    );
    // 通过 REST 接口发送（如后端不可用则返回 false）
    final ok = await ChatService(auth.apiClient).sendMessage(forwarded);
    if (!mounted) return;
    if (ok) {
      // 发送成功后轻提示，并刷新该会话在聊天列表中的摘要
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.messageSent)),
      );
      context.read<ChatProvider>().updateConversation(
        Conversation(
          targetId: target.targetId,
          targetType: target.targetType,
          lastMsg: MessageUtils.getMessagePreview(msg.type, msg.content),
          lastMsgTime: now,
          unreadCount: 0,
        ),
      );
    } else {
      // 发送失败提示，便于用户重试
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.messageFailed)),
      );
    }
  }

  Widget _buildInputBar(ThemeData theme, AppLocalizations l10n) {
    // 对标 win-chat-android act_chat_layout：
    // 工具栏 #1A1A1A、顶部 1px 分隔线；输入框同底色、圆角 14；
    // 有文字时显示金色「发送」按钮（40x32、圆角 6），无文字时显示「+」附件
    final hasText = _controller.text.trim().isNotEmpty;
    // 底部手势条/虚拟键的安全区内边距：面板贴屏幕最底时内容不被遮挡
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: const BoxDecoration(
            color: AppTheme.chatInputBar,
            border: Border(top: BorderSide(color: AppTheme.chatDivider, width: 0.5)),
          ),
          child: Row(
            children: [
              // 语音/键盘切换按钮：切换"按住说话"与文本输入
              IconButton(
                icon: Icon(_voiceMode ? Icons.keyboard : Icons.mic_none,
                    color: Colors.white, size: 26),
                tooltip: _voiceMode ? l10n.inputMessage : l10n.voice,
                onPressed: () {
                  setState(() {
                    _voiceMode = !_voiceMode;
                    // 切回文本模式时收起表情面板并聚焦输入框
                    if (!_voiceMode) {
                      _showEmojiPanel = false;
                      _inputFocusNode.requestFocus();
                    } else {
                      // 切到语音模式时收起键盘与表情面板
                      _inputFocusNode.unfocus();
                      _showEmojiPanel = false;
                    }
                  });
                },
              ),
              // 中间区域：语音模式显示"按住说话"按钮，文本模式显示输入框
              Expanded(
                child: _voiceMode
                    ? _buildHoldToTalkButton(theme, l10n)
                    : TextField(
                        controller: _controller,
                        focusNode: _inputFocusNode,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        cursorColor: AppTheme.accent,
                        decoration: InputDecoration(
                          hintText: l10n.inputMessage,
                          hintStyle: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: AppTheme.chatInputBar,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        maxLines: null,
                        textCapitalization: TextCapitalization.none,
                        // 点输入框时先收起表情面板：否则键盘与面板同时顶起，
                        // 聊天内容区被压到几乎看不见
                        onTap: () {
                          if (_showEmojiPanel || _showAttachPanel) {
                            setState(() {
                              _showEmojiPanel = false;
                              _showAttachPanel = false;
                            });
                          }
                        },
                        onSubmitted: (_) => _sendMessage(),
                      ),
              ),
              const SizedBox(width: 8),
              // 表情按钮
              IconButton(
                icon: const Icon(Icons.emoji_emotions_outlined,
                    color: Colors.white, size: 26),
                tooltip: l10n.emoji,
                onPressed: () {
                  setState(() {
                    _showEmojiPanel = !_showEmojiPanel;
                    if (_showEmojiPanel) {
                      // 打开表情面板时收起键盘与附件面板
                      _showAttachPanel = false;
                      _inputFocusNode.unfocus();
                    } else {
                      _pendingMediaType = 'text';
                      _pendingMediaUrl = null;
                                            _pendingFileName = null;
                    }
                  });
                },
              ),
              // 对标参考项目：输入框有文字时「发送」替换「+」附件按钮
              if (!_voiceMode && hasText)
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 32),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      l10n.send,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              // 附件按钮（语音模式或有文字时隐藏，避免误触）：
              // 点击后在输入栏下方展开图片/视频/文件面板
              if (!_voiceMode && !hasText)
                IconButton(
                  icon: Icon(
                    _showAttachPanel ? Icons.close : Icons.add_circle_outline,
                    color: Colors.white,
                    size: 28,
                  ),
                  tooltip: l10n.attach,
                  onPressed: () {
                    setState(() {
                      _showAttachPanel = !_showAttachPanel;
                      // 展开附件面板时收起键盘与表情面板，避免两层面板叠在一起
                      if (_showAttachPanel) {
                        _showEmojiPanel = false;
                        _inputFocusNode.unfocus();
                      }
                    });
                  },
                ),
            ],
          ),
        ),
        // 表情/附件面板展开在输入栏下方（输入栏在上、面板贴屏幕底部）
        if (_showEmojiPanel) _buildEmojiPanel(),
        if (_showAttachPanel) _buildAttachPanel(l10n, bottomInset: bottomInset),
      ],
    );
  }

  /// 附件面板：图片 / 视频 / 文件 三宫格，位于输入栏下方、贴屏幕底部
  ///
  /// 之前「+」是一个向上弹出的 PopupMenu，菜单浮在系统弹层里、位置随输入栏漂移，
  /// 与「点 + 在输入栏下方展开面板」的体验不一致。改为内嵌面板后，
  /// 面板与输入栏连成一体，点击即选文件，选完直接发送。
  Widget _buildAttachPanel(AppLocalizations l10n, {double bottomInset = 0}) {
    // 面板底色与输入栏一致（#1A1A1A），顶部一条分隔线划分边界；
    // 底部加上安全区内边距，避免内容被手势条/虚拟键挡住
    return Container(
      padding: EdgeInsets.fromLTRB(16, 18, 16, 12 + bottomInset),
      decoration: const BoxDecoration(
        color: AppTheme.chatInputBar,
        border: Border(top: BorderSide(color: AppTheme.chatDivider, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildAttachItem(
            icon: Icons.photo_library,
            color: const Color(0xFF4CAF50),
            label: l10n.image,
            onTap: () => _onAttachTap('image'),
          ),
          _buildAttachItem(
            icon: Icons.videocam,
            color: const Color(0xFF3F8AE2),
            label: l10n.video,
            onTap: () => _onAttachTap('video'),
          ),
          _buildAttachItem(
            icon: Icons.insert_drive_file,
            color: const Color(0xFFFFA726),
            label: l10n.file,
            onTap: () => _onAttachTap('file'),
          ),
        ],
      ),
    );
  }

  /// 附件面板中的单个入口：圆角方块图标 + 下方文字（微信样式）
  Widget _buildAttachItem({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  /// "按住说话"按钮：长按开始录音，移动判断上滑取消，松开发送/取消
  Widget _buildHoldToTalkButton(ThemeData theme, AppLocalizations l10n) {
    return GestureDetector(
      // 按下：记录起点 Y 并开始录音
      onLongPressStart: (details) {
        _onRecordStart(details.globalPosition.dy);
      },
      // 移动：判断是否上滑进入取消区域
      onLongPressMoveUpdate: (details) {
        _onRecordMove(details.globalPosition.dy);
      },
      // 松开：发送或取消
      onLongPressEnd: (_) {
        _onRecordEnd();
      },
      // 长按被系统取消时也要收尾（避免录音状态残留）
      onLongPressCancel: () {
        if (_isRecording) _onRecordEnd();
      },
      child: Container(
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          // 录音中按钮变色提示正在录音
          color: _isRecording
              ? AppTheme.accent.withValues(alpha: 0.25)
              : AppTheme.chatDivider,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          _isRecording ? l10n.releaseToSend : l10n.holdToTalk,
          style: TextStyle(
            color: _isRecording ? AppTheme.accent : Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  /// 录音中覆盖层：显示录音时长与提示（上滑取消时变红）
  Widget _buildRecordingOverlay(AppLocalizations l10n) {
    final seconds = (_recordDuration ?? Duration.zero).inSeconds;
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: Colors.black54,
          alignment: Alignment.center,
          child: Container(
            width: 160,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              // 取消状态变红色警示
              color: _isCancelling ? const Color(0xCCB71C1C) : const Color(0xCC333333),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 麦克风图标（取消状态显示删除图标）
                Icon(
                  _isCancelling ? Icons.delete_outline : Icons.mic,
                  color: Colors.white,
                  size: 40,
                ),
                const SizedBox(height: 12),
                // 录音时长
                Text(
                  '$seconds"',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                // 提示文字：上滑取消 / 松开发送
                Text(
                  _isCancelling ? l10n.releaseToCancel : l10n.releaseToSend,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建微信风格的底部表情面板
  ///
  /// 表情数据、分类、最近使用、搜索、肤色选择全部交给三方组件
  /// `emoji_picker_flutter`（1500+ emoji / 8 个分类），这里只做两件事：
  /// 1. 把配色改成聊天页的深色主题；
  /// 2. 把「选中插入」和「退格删除」接到输入框上（走 [EmojiTextEditing]，
  ///    emoji 是多码点字符，不能按 UTF-16 删）。
  ///
  /// 视图顺序用 emojiView → categoryBar → bottomActionBar：网格在上、
  /// 分类栏在下，和微信一致（组件默认是分类栏在顶）。
  Widget _buildEmojiPanel() {
    final l10n = AppLocalizations.of(context)!;
    // 面板现在贴屏幕最底，把底部手势条/虚拟键的安全区让出来
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      // 面板高度约为屏幕的 42%（含底部安全区）：再高就把聊天内容区挤没了
      height: MediaQuery.of(context).size.height * 0.42,
      decoration: const BoxDecoration(
        // 与输入栏同色（#1A1A1A），上下连成一体
        color: AppTheme.chatInputBar,
        border: Border(top: BorderSide(color: AppTheme.chatDivider, width: 0.5)),
      ),
      // 左右留边：组件内部按「picker 宽度 / 列数」算格子尺寸，
      // 所以边距必须加在外面（用 gridPadding 会让格子比实际宽而被裁掉一列）
      child: Padding(
        padding: EdgeInsets.fromLTRB(6, 0, 6, bottomInset),
        child: EmojiPicker(
          onEmojiSelected: (_, emoji) => _sendEmoji(emoji.emoji),
          onBackspacePressed: _deleteLastChar,
          config: Config(
            // 高度交给外层 Container（传固定值会和外层叠加导致溢出）
            height: null,
            // 按系统语言取表情名，中文下搜索「笑」「哭」才有结果
            locale: Localizations.localeOf(context),
            // 过滤掉系统字体渲染不出来的 emoji（不然会出现方块豆腐块）
            checkPlatformCompatibility: true,
            emojiTextStyle: const TextStyle(fontSize: 26),
            emojiViewConfig: EmojiViewConfig(
              columns: 8,
              emojiSizeMax: 30,
              verticalSpacing: 4,
              horizontalSpacing: 4,
              backgroundColor: AppTheme.chatInputBar,
              gridPadding: const EdgeInsets.only(top: 8, bottom: 8),
              buttonMode: ButtonMode.MATERIAL,
              recentsLimit: 32,
              replaceEmojiOnLimitExceed: true,
              noRecents: Text(
                l10n.noData,
                style: const TextStyle(fontSize: 14, color: Colors.white38),
                textAlign: TextAlign.center,
              ),
              loadingIndicator: const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            viewOrderConfig: const ViewOrderConfig(
              top: EmojiPickerItem.emojiView,
              middle: EmojiPickerItem.categoryBar,
              bottom: EmojiPickerItem.searchBar,
            ),
            categoryViewConfig: const CategoryViewConfig(
              tabBarHeight: 44,
              initCategory: Category.SMILEYS,
              backgroundColor: AppTheme.chatInputBar,
              indicatorColor: AppTheme.accent,
              iconColor: Colors.white38,
              iconColorSelected: AppTheme.accent,
              dividerColor: AppTheme.chatDivider,
            ),
            bottomActionBarConfig: BottomActionBarConfig(
              backgroundColor: AppTheme.chatInputBar,
              buttonColor: AppTheme.surface,
              buttonIconColor: Colors.white70,
              customBottomActionBar: _buildEmojiBottomBar,
            ),
            searchViewConfig: SearchViewConfig(
              backgroundColor: AppTheme.chatInputBar,
              buttonIconColor: Colors.white54,
              hintText: l10n.search,
              hintTextStyle: const TextStyle(fontSize: 14, color: Colors.white38),
              inputTextStyle: const TextStyle(fontSize: 15, color: Colors.white),
            ),
            skinToneConfig: const SkinToneConfig(
              dialogBackgroundColor: AppTheme.surface,
              indicatorColor: AppTheme.accent,
            ),
          ),
        ),
      ),
    );
  }

  /// 表情面板底栏：左边搜索、右边退格（长按连删）
  ///
  /// 不用组件默认的底栏，是因为默认退格只有单击 —— 长按连删是组件在
  /// 传了 `textEditingController` 时才处理的分支，这里没传，所以自己接。
  Widget _buildEmojiBottomBar(
    Config config,
    EmojiViewState state,
    VoidCallback showSearchView,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      height: 44,
      color: config.bottomActionBarConfig.backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.search, size: 22),
            color: config.bottomActionBarConfig.buttonIconColor,
            tooltip: l10n.search,
            onPressed: showSearchView,
          ),
          const Spacer(),
          GestureDetector(
            onTap: state.onBackspacePressed,
            onLongPressStart: (_) => _startRepeatDelete(),
            onLongPressEnd: (_) => _stopRepeatDelete(),
            onLongPressCancel: _stopRepeatDelete,
            child: Container(
              width: 46,
              height: 32,
              decoration: BoxDecoration(
                color: config.bottomActionBarConfig.buttonColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.backspace_outlined,
                size: 20,
                color: config.bottomActionBarConfig.buttonIconColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 长按删除键：连续删除
  void _startRepeatDelete() {
    _deleteLastChar();
    _emojiDeleteTimer?.cancel();
    _emojiDeleteTimer =
        Timer.periodic(const Duration(milliseconds: 80), (_) => _deleteLastChar());
  }

  void _stopRepeatDelete() {
    _emojiDeleteTimer?.cancel();
    _emojiDeleteTimer = null;
  }

  /// 删除输入框里光标前的一个字符（有选中内容时先删选中）
  ///
  /// 退格按「显示字符」而不是 UTF-16 code unit 处理，细节见 [EmojiTextEditing]。
  void _deleteLastChar() {
    final next = EmojiTextEditing.deleteBackward(_controller.value);
    if (next == _controller.value) return;
    _controller.value = next;
    setState(() {});
  }

  /// 点选表情：插入到输入框光标处，面板保持打开，方便连续挑（微信行为）
  ///
  /// 原来每点一个表情就关面板并 `requestFocus()`，键盘会跟着弹出来，
  /// 想连发两个表情得反复开关面板。
  void _sendEmoji(String emoji) {
    _controller.value = EmojiTextEditing.insertAtCursor(_controller.value, emoji);
    // 输入栏要按「有无文字」切换发送/附件按钮，这里手动触发一次重建
    setState(() {});
  }
}

/// 全屏视频播放器页面
class VideoPlayerScreen extends StatefulWidget {
  final VideoPlayerController controller;
  final String url;
  const VideoPlayerScreen({super.key, required this.controller, required this.url});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() => setState(() {}));
    widget.controller.play();
  }

  @override
  void dispose() {
    // 不在这里 dispose，由调用方管理生命周期
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: widget.controller.value.isInitialized
            ? AspectRatio(
                aspectRatio: widget.controller.value.aspectRatio,
                child: VideoPlayer(widget.controller),
              )
            : const CircularProgressIndicator(color: Colors.white),
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
  final String pushStatus;
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
      id: MessageUtils.toInt(json['id']),
      fromUserId: MessageUtils.toInt(json['fromUserId']),
      toUserId: MessageUtils.toNullableInt(json['toUserId']),
      groupId: MessageUtils.toNullableInt(json['groupId']),
      type: json['type'] as String? ?? 'text',
      content: json['content'] as String? ?? '',
      status: parseMessageStatus(json['status']),
      pushStatus: json['pushStatus'] as String? ?? 'pending',
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
