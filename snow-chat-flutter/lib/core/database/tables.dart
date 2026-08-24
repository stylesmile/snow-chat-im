class Tables {
  /// 生成带用户ID前缀的表名，实现多用户数据隔离
  /// 例如：userId=123 → local_messages_123
  static String messagesTable(int userId) => 'local_messages_$userId';
  static String conversationsTable(int userId) => 'conversations_$userId';
  static String friendsTable(int userId) => 'local_friends_$userId';
  static String groupsTable(int userId) => 'local_groups_$userId';
  static String groupMembersTable(int userId) => 'group_members_$userId';
  static String sessionsTable(int userId) => 'sessions_$userId';

  /// 生成消息表建表SQL（带用户ID前缀）
  static String createMessagesTable(int userId) => '''
    CREATE TABLE IF NOT EXISTS ${messagesTable(userId)} (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      msg_id INTEGER,
      session_id TEXT NOT NULL,
      from_user_id INTEGER,
      to_user_id INTEGER,
      group_id INTEGER,
      msg_type TEXT DEFAULT 'text',
      content TEXT,
      local_seq INTEGER DEFAULT 0,
      status TEXT DEFAULT 'sent',
      push_status TEXT DEFAULT 'pending',
      create_time INTEGER,
      update_time INTEGER
    )
  ''';

  /// 生成消息会话索引SQL（带用户ID前缀）
  static String createMessagesSessionIndex(int userId) => '''
    CREATE INDEX IF NOT EXISTS idx_${messagesTable(userId)}_session_time
    ON ${messagesTable(userId)}(session_id, create_time)
  ''';

  /// 生成会话表建表SQL（带用户ID前缀）
  static String createConversationsTable(int userId) => '''
    CREATE TABLE IF NOT EXISTS ${conversationsTable(userId)} (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      target_id INTEGER NOT NULL,
      target_type TEXT NOT NULL,
      last_msg TEXT DEFAULT '',
      last_msg_time INTEGER,
      unread_count INTEGER DEFAULT 0,
      is_muted INTEGER DEFAULT 0,
      update_time INTEGER
    )
  ''';

  /// 生成好友表建表SQL（带用户ID前缀）
  static String createFriendsTable(int userId) => '''
    CREATE TABLE IF NOT EXISTS ${friendsTable(userId)} (
      user_id INTEGER PRIMARY KEY,
      nickname TEXT,
      avatar TEXT DEFAULT '',
      remark TEXT DEFAULT '',
      update_time INTEGER
    )
  ''';

  /// 生成群组表建表SQL（带用户ID前缀）
  static String createGroupsTable(int userId) => '''
    CREATE TABLE IF NOT EXISTS ${groupsTable(userId)} (
      id INTEGER PRIMARY KEY,
      name TEXT,
      avatar TEXT DEFAULT '',
      owner_id INTEGER,
      member_count INTEGER DEFAULT 0,
      update_time INTEGER
    )
  ''';

  /// 生成群成员表建表SQL（带用户ID前缀）
  static String createGroupMembersTable(int userId) => '''
    CREATE TABLE IF NOT EXISTS ${groupMembersTable(userId)} (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      group_id INTEGER NOT NULL,
      user_id INTEGER NOT NULL,
      role TEXT DEFAULT 'member',
      UNIQUE(group_id, user_id)
    )
  ''';

  /// 生成会话记录表建表SQL（带用户ID前缀）
  static String createSessionsTable(int userId) => '''
    CREATE TABLE IF NOT EXISTS ${sessionsTable(userId)} (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      target_id INTEGER NOT NULL,
      target_type TEXT NOT NULL,
      last_msg TEXT DEFAULT '',
      last_msg_time INTEGER,
      unread_count INTEGER DEFAULT 0,
      is_muted INTEGER DEFAULT 0,
      update_time INTEGER,
      UNIQUE(user_id, target_id, target_type)
    )
  ''';
}
