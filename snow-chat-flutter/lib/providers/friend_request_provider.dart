import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../services/contact_service.dart';
import '../core/network/api_client.dart';

/// 管理未读好友请求数量的 Provider
class FriendRequestProvider extends ChangeNotifier {
  final ApiClient _apiClient;
  int _unreadCount = 0;
  Timer? _pollTimer;
  int? _currentUserId;

  FriendRequestProvider(this._apiClient);

  int get unreadCount => _unreadCount;
  bool get hasUnread => _unreadCount > 0;

  /// 设置当前用户ID并开始轮询
  void startPolling(int userId) {
    _currentUserId = userId;
    _stopPolling();
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
    try {
      final service = ContactService(_apiClient);
      final requests = await service.getReceivedRequests(_currentUserId!);
      final count = requests.length;
      if (_unreadCount != count) {
        _unreadCount = count;
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) print('Fetch unread friend requests error: $e');
    }
  }

  /// 手动刷新未读数量
  Future<void> refresh() async {
    await _fetchUnreadCount();
  }

  /// 标记为已读（进入"新的朋友"页面时调用）
  void markAsRead() {
    if (_unreadCount > 0) {
      _unreadCount = 0;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }
}
