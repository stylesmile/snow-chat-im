import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/contact_service.dart';
import '../core/network/api_client.dart';

/// 管理未读好友请求数量的 Provider
///
/// 未读判定采用「已读水位」而非全量计数：只统计 id 大于
/// [_lastSeenMaxId]（已看过的最大请求 id）的请求。否则进过「新的朋友」
/// 页清零后，下一次轮询会把同样的旧请求再次算成未读，红点永远消不掉。
/// 水位按用户持久化到 SharedPreferences，重启 App 后也不会复活红点。
class FriendRequestProvider extends ChangeNotifier {
  final ApiClient _apiClient;
  int _unreadCount = 0;
  Timer? _pollTimer;
  int? _currentUserId;

  /// 已读水位：已看过的最大好友请求 id，只有 id 更大的新请求才算未读
  int _lastSeenMaxId = 0;

  /// 水位是否已按当前用户加载完成（refresh 独立调用时按需懒加载）
  bool _seenLoaded = false;

  /// 最近一次拉取到的请求列表，markAsRead 时据此推进水位
  List<FriendRequest> _lastRequests = [];

  FriendRequestProvider(this._apiClient);

  /// 已读水位的持久化 key（按用户区分，避免多账号串水位）
  static String _seenKey(int userId) => 'friend_req_seen_max_id_$userId';

  int get unreadCount => _unreadCount;
  bool get hasUnread => _unreadCount > 0;

  /// 绑定当前用户并从持久化存储加载已读水位
  ///
  /// 从 [startPolling] 中拆出为独立公开方法，便于单元测试在不启动
  /// 定时器的情况下复现"绑定用户 → 拉取 → 已读"的完整生命周期。
  Future<void> bindUser(int userId) async {
    _currentUserId = userId;
    // 水位随用户切换重新加载，防止上一个账号的已读记录串到新账号
    final prefs = await SharedPreferences.getInstance();
    _lastSeenMaxId = prefs.getInt(_seenKey(userId)) ?? 0;
    _seenLoaded = true;
  }

  /// 设置当前用户ID并开始轮询
  Future<void> startPolling(int userId) async {
    _stopPolling();
    // 先绑定用户并恢复已读水位，再开始拉取
    await bindUser(userId);
    // 延迟到首帧绘制后执行首次拉取，避免在 widget 构建过程中 notifyListeners
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchUnreadCount());
    // 每 30 秒轮询一次
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _fetchUnreadCount();
    });
  }

  /// 停止轮询
  ///
  /// [notify] 为 false 时只清理资源，不触发 UI 重建，适用于 dispose 场景。
  void stopPolling({bool notify = true}) {
    _stopPolling();
    _currentUserId = null;
    if (notify && _unreadCount != 0) {
      _unreadCount = 0;
      notifyListeners();
    }
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// 获取未读好友请求数量
  Future<void> _fetchUnreadCount() async {
    if (_currentUserId == null) return;
    // refresh 可能先于 startPolling 被调用，此时水位尚未加载，按需懒加载
    if (!_seenLoaded) await bindUser(_currentUserId!);
    try {
      final service = ContactService(_apiClient);
      final requests = await service.getReceivedRequests(_currentUserId!);
      _lastRequests = requests;
      // 只统计已读水位之上的请求：旧请求即使仍是 pending 也不再点亮红点
      final count = requests.where((r) => r.id > _lastSeenMaxId).length;
      if (_unreadCount != count) {
        _unreadCount = count;
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) print('Fetch unread friend requests error: $e');
    }
  }

  /// 手动刷新未读数量（MQTT 收到好友申请通知时也会调用）
  Future<void> refresh() async {
    await _fetchUnreadCount();
  }

  /// 标记为已读（进入"新的朋友"页面时调用）
  ///
  /// 把已读水位推进到当前最大请求 id 并持久化，此后轮询拉到的旧请求
  /// （id ≤ 水位）不再计入未读，红点保持熄灭直到新申请到达。
  void markAsRead() {
    // 用当前列表的最大 id 推进水位；列表为空时保持水位不变
    if (_lastRequests.isNotEmpty) {
      final maxId = _lastRequests.map((r) => r.id).reduce(max);
      if (maxId > _lastSeenMaxId) {
        _lastSeenMaxId = maxId;
        // 异步持久化，失败只影响"重启后红点复活一次"，不阻塞 UI
        _persistSeenWatermark();
      }
    }
    if (_unreadCount > 0) {
      _unreadCount = 0;
      notifyListeners();
    }
  }

  /// 把已读水位写入 SharedPreferences（按用户区分 key）
  Future<void> _persistSeenWatermark() async {
    final userId = _currentUserId;
    if (userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_seenKey(userId), _lastSeenMaxId);
    } catch (e) {
      if (kDebugMode) print('Persist friend request seen watermark failed: $e');
    }
  }

  /// 测试专用：直接注入未读数量，绕过网络轮询验证 UI 渲染契约
  @visibleForTesting
  void forceUnread(int count) {
    _unreadCount = count;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }
}
