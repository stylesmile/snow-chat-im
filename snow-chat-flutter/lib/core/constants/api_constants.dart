you/// REST 端点路径常量
/// REST endpoint path constants
class ApiConstants {
  // ---------------------------------------------------------------------------
  // 认证与用户
  // Auth & user
  static const String loginPath = '/chat/user/login';
  static const String userInfoPath = '/chat/user/info';
  static const String searchUserPath = '/chat/user/search';
  static const String profilePath = '/chat/user/profile';

  // ---------------------------------------------------------------------------
  // 好友
  // Friend
  static const String friendListPath = '/chat/friend/list';
  static const String sendFriendRequestPath = '/chat/friend/request';
  static const String handleFriendRequestPath = '/chat/friend/handle';
  static const String pendingRequestsPath = '/chat/friend/pending';
  static const String deleteFriendPath = '/chat/friend';

  // ---------------------------------------------------------------------------
  // 群组
  // Group
  static const String createGroupPath = '/chat/group/create';
  static const String groupInfoPath = '/chat/group';
  static const String groupListPath = '/chat/group/list';
  static const String groupMembersPath = '/chat/group/members';

  // ---------------------------------------------------------------------------
  // 消息
  // Message
  static const String messageHistoryPath = '/chat/message/history';
  static const String recallMessagePath = '/chat/message/recall';
  static const String markReadPath = '/chat/message/read';
  static const String sendMessagePath = '/chat/message/send';

  // ---------------------------------------------------------------------------
  // 会话
  // Session
  static const String sessionListPath = '/chat/session/list';
  static const String clearUnreadPath = '/chat/session/unread/clear';
}
