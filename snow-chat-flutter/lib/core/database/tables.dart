class Tables {
  /// 生成带用户ID前缀的表名，实现多用户数据隔离
  /// 例如：userId=123 → local_messages_123
  static String messagesTable(int userId) => 'local_messages_$userId';
  static String conversationsTable(int userId) => 'conversations_$userId';
  static String friendsTable(int userId) => 'local_friends_$userId';
  static String groupsTable(int userId) => 'local_groups_$userId';
  static String groupMembersTable(int userId) => 'group_members_$userId';
  static String sessionsTable(int userId) => 'sessions_$userId';
  static String favoritesTable(int userId) => 'favorites_$userId';

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
      is_pinned INTEGER DEFAULT 0,
      update_time INTEGER,
      UNIQUE(user_id, target_id, target_type)
    )
  ''';

  /// 会话表唯一索引名：同一 (user_id, target_id, target_type) 只允许一行
  static String sessionsUniqueIndexName(int userId) => 'idx_${sessionsTable(userId)}_uniq';

  /// 为会话表补建唯一索引（幂等）
  ///
  /// 早期版本的 [createSessionsTable] 没有 `UNIQUE(user_id, target_id, target_type)`，
  /// 而 `CREATE TABLE IF NOT EXISTS` **不会给已存在的表补约束** —— 于是那些老库上
  /// 「同一个会话只保留一行」的语义失效，每进一次聊天就攒一行，聊天列表看起来重复。
  /// 这里用唯一索引把语义补回来（建索引前必须先合并历史重复行，否则会建失败）。
  static String createSessionsUniqueIndex(int userId) => '''
    CREATE UNIQUE INDEX IF NOT EXISTS ${sessionsUniqueIndexName(userId)}
    ON ${sessionsTable(userId)}(user_id, target_id, target_type)
  ''';

  /// 生成收藏表建表SQL（带用户ID前缀）
  /// message_id 加 UNIQUE 约束，保证同一消息只能收藏一次（去重）
  static String createFavoritesTable(int userId) => '''
    CREATE TABLE IF NOT EXISTS ${favoritesTable(userId)} (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      message_id INTEGER,
      msg_type TEXT DEFAULT 'text',
      content TEXT,
      from_user_id INTEGER,
      from_nickname TEXT DEFAULT '',
      create_time INTEGER,
      UNIQUE(message_id)
    )
  ''';
}
