import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
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
import '../../models/message_model.dart';
import '../../core/cache/message_cache_manager.dart';
import '../../core/cache/favorite_cache_manager.dart';
import '../../models/favorite_model.dart';
import '../../services/conversation_service.dart';
import '../../providers/chat_provider.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/message_delivery_status.dart';
import '../widgets/message_action_sheet.dart';
import '../widgets/forward_picker_sheet.dart';
import '../../services/contact_service.dart';
import '../../models/friend_model.dart';
import 'group_detail_screen.dart';
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
  File? _pendingMediaFile;
  String _pendingMediaType = 'text'; // text / image / video / file / voice
  String? _pendingMediaUrl;
  String? _pendingFileName;

  // 表情面板状态
  bool _showEmojiPanel = false;
  // 丰富的表情列表（参考微信表情）
  static const List<String> _emojiList = [
    '😀','😃','😄','😁','😆','😅','🤣','😂',
    '🙂','😊','😇','🥰','😍','🤩','😘','😗',
    '😚','😙','🥲','😋','😛','😜','🤪','😝',
    '🤑','🤗','🤭','🫢','🤫','🤔','🫡','🤐',
    '🤨','😐','😑','😶','🫥','😏','😒','🙄',
    '😬','🤥','😌','😔','😪','🤤','😴','😷',
    '🤒','🤕','🤢','🤮','🥵','🥶','🥴','😵',
    '🤯','🤠','🥳','🥸','😎','🤓','🧐','😕',
    '🫤','😟','🙁','☹️','😮','😯','😲','😳',
    '🥺','🥹','😦','😧','😨','😰','😥','😢',
    '😭','😱','😖','😣','😞','😓','😩','😫',
    '🥱','😤','😡','😠','🤬','😈','👿','💀',
    '☠️','💩','🤡','👹','👺','👻','👽','👾',
    '🤖','😺','😸','😹','😻','😼','😽','🙀',
    '😿','😾','🙈','🙉','🙊','💋','👋','🤚',
    '🖐','✋','🖖','🫱','🫲','🫳','🫴','👌',
    '🤌','🤏','✌️','🤞','🫰','🤟','🤘','🤙',
    '👈','👉','👆','🖕','👇','☝️','�指','👍',
    '👎','✊','👊','🤛','🤜','👏','🙌','🫰',
    '👐','🤲','🤝','🙏','✍️','💅','🤳','💪',
    '🦾','🦿','🦵','🦶','👂','🦻','👃','🧠',
    '🫀','🫁','🦷','🦴','👀','👁','👅','👄',
    '👶','🧒','👦','👧','🧑','👱','👨','🧔',
    '👩','🧓','👴','👵','🙍','🙎','🙅','🙆',
    '💁','🙋','🧏','🙇','🤦','🤷','👮','🕵️',
    '💂','🥷','👷','🤴','👸','👳','👲','🧕',
    '🤵','👰','🤰','🤱','👼','🎅','🤶','🦸',
    '🦹','🧙','🧚','🧛','🧜','🧝','🧞','🧟',
    '💆','💇','🚶','🧍','🧎','🏃','💃','🕺',
    '👯','🧖','🧗','🤸','⛹️','🏋️','🚴','🚵',
    '🤼','🤽','🤾','🤺','⛷','🏂','🏄','🏊',
    '🤺','⛹️','🏋️','🚴','🚵','🤸','⛷','🏂',
    '🏄','🏊','🤽','🤾','🤺','🏇','🧘','🛀',
    '🛌','👭','👫','👬','💏','💑','🔥','⭐',
    '🌟','✨','💫','💥','🔆','🔅','☀️','🌤',
    '⛅','🌥','☁️','🌦','🌈','☔','⚡','❄️',
    '🔥','💧','🌊','🎉','🎊','🎈','🎁','🏆',
    '🥇','🥈','🥉','⚽','🏀','🏈','⚾','🥎',
    '🎾','🏐','🏉','🥏','🎱','🪀','🏓','🏸',
    '🏒','🥍','🏏','🪃','🥅','⛳','🏹','🎣',
    '🤿','🎽','🛹','🛼','🥾','👑','💎',
  ];

  // 视频播放器控制器（每个视频消息独立持有）
  final Map<int, VideoPlayerController> _videoPlayers = {};

  // 音频播放器（全局单例，同一时刻只播一条语音）
  final AudioPlayer _audioPlayer = AudioPlayer();

  // 录音状态（record 4.4.4 使用 Record 类，非 AudioRecorder）
  final Record _recorder = Record();
  String? _recordingPath;
  bool _isRecording = false;
  Duration? _recordDuration;

  // 当前播放中的语音消息 ID（用于气泡更新播放状态）
  int? _playingVoiceMsgId;

  @override
  void initState() {
    super.initState();
    _ensureConversationSaved();
    _initCache();
    _initMqtt();
  }

  @override
  void dispose() {
    _controller.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    _mqttClient?.disconnect();
    // 释放所有视频播放器
    for (final controller in _videoPlayers.values) {
      controller.dispose();
    }
    _videoPlayers.clear();
    // 停止音频播放
    _audioPlayer.stop();
    // 停止录音（如有）
    if (_isRecording) {
      _recorder.stop();
    }
    super.dispose();
  }

  /// 进入聊天页时把该对话保存到本地会话列表，并清空未读数。
  Future<void> _ensureConversationSaved() async {
    final auth = context.read<AuthProvider>();
    if (auth.userId == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await ConversationService().saveSession(
      context: context,
      targetId: widget.targetId,
      targetType: widget.targetType,
      lastMsg: widget.targetName ?? '',
      lastMsgTime: now,
      unreadCount: 0,
    );
    final service = ChatService(auth.apiClient);
    service.markAsRead(auth.userId!, widget.targetId, widget.targetType);
    if (!mounted) return;
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

  /// 开始录音
  Future<void> _startRecording() async {
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
        _recordingPath = path;
        _recordDuration = Duration.zero;
      });
      // 定时更新录音时长
      Timer.periodic(const Duration(seconds: 1), (timer) {
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

  /// 停止录音并上传
  Future<void> _stopRecording() async {
    try {
      if (!_isRecording) return;
      final path = await _recorder.stop();
      setState(() => _isRecording = false);
      if (path == null) return;
      // 上传语音并发送
      final file = File(path);
      _onMediaPicked(file, 'voice');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context)!.voiceStopFailed}: $e')),
      );
    }
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
        _pendingMediaFile = null;
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

  /// 用户点击附件按钮：按当前选中类型触发对应选择器
  void _onAttachTap() {
    switch (_pendingMediaType) {
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

  /// 选择媒体/文件/语音后的统一处理：
  /// 1. 上传到对象存储（POST /file/media/{type}）
  /// 2. 将返回的 URL 暂存为 _pendingMediaUrl，类型暂存为 _pendingMediaType
  /// 3. 切换到预览状态，等待用户点击发送
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
      setState(() {
        _pendingMediaType = type;
        _pendingMediaUrl = result.url;
        _pendingMediaFile = file;
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
        // 使用略浅于页面的背景色 + 轻微阴影，让 AppBar 在视觉上有明确边界
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 1,
        title: Text(displayName),
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
          // 预览区域
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
                      ),
          ),
          _buildInputBar(theme, l10n),
        ],
      ),
    );
  }

  /// 构建媒体预览组件
  Widget _buildMediaPreview(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final isImage = _pendingMediaType == 'image';
    final isVideo = _pendingMediaType == 'video';
    final isVoice = _pendingMediaType == 'voice';
    return Container(
      padding: const EdgeInsets.all(8),
      color: theme.cardColor,
      child: Row(
        children: [
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
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image, color: Colors.white54),
                    ),
                  )
                : isVideo
                    ? const Icon(Icons.videocam, color: Colors.white54)
                    : isVoice
                        ? const Icon(Icons.mic, color: Colors.white54)
                        : const Icon(Icons.insert_drive_file, color: Colors.white54),
          ),
          const SizedBox(width: 8),
          if (_pendingFileName != null)
            Expanded(
              child: Text(
                _pendingFileName!,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          if (isVoice && _recordDuration != null) ...[
            const SizedBox(width: 8),
            Text(
              '${_recordDuration!.inSeconds}""',
              style: const TextStyle(fontSize: 13),
            ),
          ],
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: l10n.cancel,
            onPressed: () {
              setState(() {
                _pendingMediaType = 'text';
                _pendingMediaUrl = null;
                _pendingMediaFile = null;
                _pendingFileName = null;
                _recordDuration = null;
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
          Flexible(
            child: GestureDetector(
              // 长按气泡弹出操作菜单（复制/撤回/转发）
              onLongPress: () => _showMessageActionMenu(msg, isMe),
              child: _buildMessageBubbleByType(msg, isMe, theme),
            ),
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
        'video' => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => _openVideoPlayer(msg.id, msg.content),
                child: Stack(
                  children: [
                    Container(
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
                    // TODO: 后续用 VideoPlayerController 展示首帧
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
        'voice' => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => _playVoice(msg.id, msg.content),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _playingVoiceMsgId == msg.id
                          ? Icons.stop_circle
                          : Icons.play_arrow,
                      color: textColor,
                      size: 24,
                    ),
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
                  Flexible(child: Text(msg.content, style: TextStyle(color: textColor))),
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
      },
    );
  }

  Widget _fallbackPlaceholder(ThemeData theme, Color textColor, IconData icon) {
    return Container(
      width: 200,
      height: 150,
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
      child: Icon(icon, color: textColor.withOpacity(0.5), size: 32),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 微信风格：表情面板从底部滑入，覆盖在输入栏上方
        if (_showEmojiPanel) _buildEmojiPanel(theme),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: theme.cardColor,
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
          ),
          child: Row(
            children: [
              // 表情按钮
              IconButton(
                icon: const Icon(Icons.emoji_emotions),
                tooltip: l10n.emoji,
                onPressed: () {
                  setState(() {
                    _showEmojiPanel = !_showEmojiPanel;
                    if (!_showEmojiPanel) {
                      _pendingMediaType = 'text';
                      _pendingMediaUrl = null;
                      _pendingMediaFile = null;
                      _pendingFileName = null;
                    }
                  });
                },
              ),
              // 附件按钮
              PopupMenuButton<String>(
                icon: const Icon(Icons.attach_file),
                tooltip: l10n.attach,
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'image', child: Row(children: [const Icon(Icons.photo_library, size: 18), const SizedBox(width: 8), Text(l10n.image)])),
                  PopupMenuItem(value: 'video', child: Row(children: [const Icon(Icons.videocam, size: 18), const SizedBox(width: 8), Text(l10n.video)])),
                  PopupMenuItem(value: 'file', child: Row(children: [const Icon(Icons.insert_drive_file, size: 18), const SizedBox(width: 8), Text(l10n.file)])),
                ],
                onSelected: (type) {
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
                  focusNode: _inputFocusNode,
                  decoration: InputDecoration(
                    hintText: l10n.inputMessage,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.none,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 4),
              // 语音按钮：长按录音，松开发送
              if (!_isRecording)
                IconButton(
                  icon: const Icon(Icons.mic),
                  tooltip: l10n.voice,
                  onPressed: () => _startRecording(),
                )
              else
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: l10n.cancel,
                  onPressed: () => _stopRecording(),
                ),
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

  /// 构建微信风格的底部表情面板，从底部向上滑入
  Widget _buildEmojiPanel(ThemeData theme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      // 面板高度约为屏幕的 60%
      height: MediaQuery.of(context).size.height * 0.6,
      color: Colors.grey[900] ?? const Color(0xFF1A1A1A),
      child: Column(
        children: [
          // 顶部工具栏：关闭按钮 + 提示文字
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '表情',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                // 右下角删除按钮（微信风格）
                GestureDetector(
                  onTap: () {
                    // 删除输入框最后一个字符
                    if (_controller.text.isNotEmpty) {
                      final text = _controller.text;
                      // 处理 UTF-16 surrogate pair（某些 emoji 占两个 char）
                      final lastCharLen = _getCharLength(text);
                      setState(() {
                        _controller.text = text.substring(0, text.length - lastCharLen);
                      });
                    }
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.backspace, color: Colors.white70, size: 22),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.grey, height: 1),
          // 表情 Grid
          Expanded(
            child: GridView.count(
              crossAxisCount: 8,
              padding: const EdgeInsets.all(8),
              childAspectRatio: 1.3,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              physics: const BouncingScrollPhysics(),
              children: _emojiList.map((emoji) {
                return _buildEmojiCell(emoji);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// 单个表情格子
  Widget _buildEmojiCell(String emoji) {
    return GestureDetector(
      onTap: () => _sendEmoji(emoji),
      child: Center(
        child: Text(emoji, style: const TextStyle(fontSize: 30)),
      ),
    );
  }

  /// 发送表情并关闭面板
  void _sendEmoji(String emoji) {
    // 直接在输入框追加 emoji，用户确认后再发送（更贴近微信行为）
    _controller.text += emoji;
    setState(() => _showEmojiPanel = false);
    // 将焦点还给输入框
    Future.microtask(() {
      if (mounted) _inputFocusNode.requestFocus();
    });
  }

  /// 计算字符串末尾字符的实际长度（处理 surrogate pair）
  int _getCharLength(String text) {
    if (text.isEmpty) return 0;
    final rune = text.codeUnitAt(text.length - 1);
    // UTF-16 surrogate pair：高位 surrogate (D800-DFFF) 占用 2 个 char
    return (rune >= 0xD800 && rune <= 0xDBFF) ? 2 : 1;
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
