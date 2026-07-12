class Tables {
  static const String createMessagesTable = '''
    CREATE TABLE IF NOT EXISTS local_messages (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      msg_id INTEGER,
      from_user_id INTEGER,
      to_user_id INTEGER,
      group_id INTEGER,
      msg_type TEXT DEFAULT 'text',
      content TEXT,
      local_seq INTEGER DEFAULT 0,
      status TEXT DEFAULT 'sent',
      create_time INTEGER,
      update_time INTEGER
    )
  ''';

  static const String createConversationsTable = '''
    CREATE TABLE IF NOT EXISTS conversations (
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

  static const String createFriendsTable = '''
    CREATE TABLE IF NOT EXISTS local_friends (
      user_id INTEGER PRIMARY KEY,
      nickname TEXT,
      avatar TEXT DEFAULT '',
      remark TEXT DEFAULT '',
      update_time INTEGER
    )
  ''';

  static const String createGroupsTable = '''
    CREATE TABLE IF NOT EXISTS local_groups (
      id INTEGER PRIMARY KEY,
      name TEXT,
      avatar TEXT DEFAULT '',
      owner_id INTEGER,
      member_count INTEGER DEFAULT 0,
      update_time INTEGER
    )
  ''';

  static const String createGroupMembersTable = '''
    CREATE TABLE IF NOT EXISTS group_members (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      group_id INTEGER NOT NULL,
      user_id INTEGER NOT NULL,
      role TEXT DEFAULT 'member',
      UNIQUE(group_id, user_id)
    )
  ''';

  static const String createSessionsTable = '''
    CREATE TABLE IF NOT EXISTS sessions (
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
