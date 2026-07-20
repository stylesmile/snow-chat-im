class ApiConstants {
  // 通过 --dart-define=API_BASE_URL=http://your-ip:8091 覆盖默认值
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    // defaultValue: 'http://192.168.0.101:8091',
    defaultValue: 'http://192.168.10.103:8091',
  );
  static const String mqttHost = String.fromEnvironment(
    'MQTT_HOST',
    // defaultValue: '192.168.0.101',
    defaultValue: '192.168.10.103',
  );
  static const int mqttPort = int.fromEnvironment('MQTT_PORT', defaultValue: 1883);
  static const String mqttUsername = String.fromEnvironment(
    'MQTT_USERNAME',
    defaultValue: 'mica',
  );
  static const String mqttPassword = String.fromEnvironment(
    'MQTT_PASSWORD',
    defaultValue: '123456',
  );

  // REST endpoints
  static const String loginPath = '/chat/user/login';
  static const String userInfoPath = '/chat/user/info';
  static const String searchUserPath = '/chat/user/search';
  static const String profilePath = '/chat/user/profile';

  // Friend endpoints
  static const String friendListPath = '/chat/friend/list';
  static const String sendFriendRequestPath = '/chat/friend/request';
  static const String handleFriendRequestPath = '/chat/friend/handle';
  static const String pendingRequestsPath = '/chat/friend/pending';
  static const String deleteFriendPath = '/chat/friend';

  // Group endpoints
  static const String createGroupPath = '/chat/group/create';
  static const String groupInfoPath = '/chat/group';
  static const String groupListPath = '/chat/group/list';
  static const String groupMembersPath = '/chat/group/members';

  // Message endpoints
  static const String messageHistoryPath = '/chat/message/history';
  static const String recallMessagePath = '/chat/message/recall';
  static const String markReadPath = '/chat/message/read';
  static const String sendMessagePath = '/chat/message/send';

  // Session endpoints
  static const String sessionListPath = '/chat/session/list';
  static const String clearUnreadPath = '/chat/session/unread/clear';
}
