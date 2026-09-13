import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'tables.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'snow_chat.db');

    return await openDatabase(
      path,
      version: 6, // 升级到v6，为旧会话表补齐「同一会话只留一行」的唯一索引
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// 建表时按用户ID生成独立的表名
  Future<void> _onCreate(Database db, int version) async {
    // 注意：新建数据库时还没有用户ID，先创建默认表（userId=0）
    // 实际使用时会在登录成功后重新初始化
    await _createUserTables(db, 0);
  }

  /// 为指定用户创建所有表
  Future<void> _createUserTables(Database db, int userId) async {
    await db.execute(Tables.createMessagesTable(userId));
    await db.execute(Tables.createMessagesSessionIndex(userId));
    await db.execute(Tables.createConversationsTable(userId));
    await db.execute(Tables.createFriendsTable(userId));
    await db.execute(Tables.createGroupsTable(userId));
    await db.execute(Tables.createGroupMembersTable(userId));
    await db.execute(Tables.createSessionsTable(userId));
    await db.execute(Tables.createFavoritesTable(userId));
  }

  /// 数据库升级逻辑
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // v2: 消息表增加 session_id 字段（兼容旧表）
      await db.execute('ALTER TABLE local_messages ADD COLUMN session_id TEXT DEFAULT ""');
      await db.execute(Tables.createMessagesSessionIndex(0));
    }
    if (oldVersion < 3) {
      // v3: 消息表增加推送状态字段
      await db.execute("ALTER TABLE local_messages ADD COLUMN push_status TEXT DEFAULT 'pending'");
    }
    if (oldVersion < 4) {
      // v4: 迁移到按用户分表
      // 将旧表数据迁移到新表（userId=0 的表迁移为当前用户的表）
      await _migrateToUserTables(db, 0);
    }
    if (oldVersion < 5) {
      // v5: 复制置顶功能需要的 is_pinned 列
      // 对库中所有按用户分表的会话表补齐 is_pinned 列（兼容更早版本建的表）
      await _ensureAllSessionsPinned(db);
    }
    if (oldVersion < 6) {
      // v6: 会话去重 —— 为早期没有 UNIQUE 约束的会话表补唯一索引，
      // 否则同一好友每进一次聊天就多一行（聊天列表看起来重复）
      await _ensureAllSessionsUnique(db);
    }
  }

  /// 遍历库中所有按用户分表的会话表，为其补建「同一会话只留一行」的唯一索引
  /// SQL 注入安全：表名来自 sqlite_master 且已按固定的 sessions_ 前缀过滤
  Future<void> _ensureAllSessionsUnique(Database db) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'sessions_%'",
    );
    for (final row in rows) {
      await DatabaseHelper.ensureSessionsUniqueIndex(db, row['name'] as String);
    }
  }

  /// 幂等地为会话表补唯一索引，返回是否合并过历史重复行
  ///
  /// 1. `PRAGMA index_list` 判断是否已有唯一索引（建表语句里的 `UNIQUE(...)` 会生成
  ///    一个 `sqlite_autoindex_*`，同样算命中）→ 有则直接返回，不重复建；
  /// 2. 合并重复行：同一 `(user_id, target_id, target_type)` 只保留 `id` 最大的一行
  ///    （即最后一次写入的状态），其余删除；
  /// 3. 显式建唯一索引，让「同键只留一行」从此由数据库强制保证。
  static Future<bool> ensureSessionsUniqueIndex(Database db, String table) async {
    final indexes = await db.rawQuery('PRAGMA index_list($table)');
    final hasUnique = indexes.any((row) => (row['unique'] as int? ?? 0) == 1);
    if (hasUnique) return false;

    // 先合并历史重复行，否则第 3 步建唯一索引会直接失败
    final removed = await db.delete(
      table,
      where: 'id NOT IN (SELECT MAX(id) FROM $table GROUP BY user_id, target_id, target_type)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_${table}_uniq '
      'ON $table(user_id, target_id, target_type)',
    );
    return removed > 0;
  }

  /// 遍历库中所有按用户分表的会话表，为其补齐 is_pinned 列
  /// SQL 注入安全：表名来自 sqlite_master 且已按固定的 sessions_ 前缀过滤
  Future<void> _ensureAllSessionsPinned(Database db) async {
    // 查询所有以 sessions_ 开头的用户分表名
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'sessions_%'",
    );
    // 对每个会话表执行幂等的列补齐迁移
    for (final row in rows) {
      await DatabaseHelper.ensurePinnedColumn(db, row['name'] as String);
    }
  }

  /// 幂等地为指定会话表补齐 is_pinned 列（已存在则跳过）
  /// 用于兼容早期版本创建的本地库，避免查询 is_pinned 时 SQLite 报 unknown column
  static Future<void> ensurePinnedColumn(Database db, String table) async {
    // 用 PRAGMA table_info 读取当前表的列信息
    final cols = await db.rawQuery('PRAGMA table_info($table)');
    // 判断是否已包含 is_pinned 列
    final hasPinned = cols.any((c) => c['name'] == 'is_pinned');
    if (!hasPinned) {
      // 缺少则添加列，默认 0（未置顶），保证历史会话顶置状态安全初始化
      await db.execute('ALTER TABLE $table ADD COLUMN is_pinned INTEGER DEFAULT 0');
    }
  }

  /// 将旧表数据迁移到按用户分表的格式
  Future<void> _migrateToUserTables(Database db, int userId) async {
    final messagesTable = Tables.messagesTable(userId);
    final conversationsTable = Tables.conversationsTable(userId);
    final friendsTable = Tables.friendsTable(userId);
    final groupsTable = Tables.groupsTable(userId);
    final groupMembersTable = Tables.groupMembersTable(userId);
    final sessionsTable = Tables.sessionsTable(userId);

    // 迁移消息表
    final hasMessages = await _tableExists(db, 'local_messages');
    if (hasMessages) {
      await db.execute(Tables.createMessagesTable(userId));
      await db.execute(Tables.createMessagesSessionIndex(userId));
      await db.execute(
        'INSERT OR REPLACE INTO $messagesTable SELECT * FROM local_messages',
      );
      await db.execute('DROP TABLE local_messages');
    }

    // 迁移会话表
    final hasConversations = await _tableExists(db, 'conversations');
    if (hasConversations) {
      await db.execute(Tables.createConversationsTable(userId));
      await db.execute(
        'INSERT OR REPLACE INTO $conversationsTable SELECT * FROM conversations',
      );
      await db.execute('DROP TABLE conversations');
    }

    // 迁移好友表
    final hasFriends = await _tableExists(db, 'local_friends');
    if (hasFriends) {
      await db.execute(Tables.createFriendsTable(userId));
      await db.execute(
        'INSERT OR REPLACE INTO $friendsTable SELECT * FROM local_friends',
      );
      await db.execute('DROP TABLE local_friends');
    }

    // 迁移群组表
    final hasGroups = await _tableExists(db, 'local_groups');
    if (hasGroups) {
      await db.execute(Tables.createGroupsTable(userId));
      await db.execute(
        'INSERT OR REPLACE INTO $groupsTable SELECT * FROM local_groups',
      );
      await db.execute('DROP TABLE local_groups');
    }

    // 迁移群成员表
    final hasGroupMembers = await _tableExists(db, 'group_members');
    if (hasGroupMembers) {
      await db.execute(Tables.createGroupMembersTable(userId));
      await db.execute(
        'INSERT OR REPLACE INTO $groupMembersTable SELECT * FROM group_members',
      );
      await db.execute('DROP TABLE group_members');
    }

    // 迁移会话记录表
    final hasSessions = await _tableExists(db, 'sessions');
    if (hasSessions) {
      await db.execute(Tables.createSessionsTable(userId));
      await db.execute(
        'INSERT OR REPLACE INTO $sessionsTable SELECT * FROM sessions',
      );
      await db.execute('DROP TABLE sessions');
    }
  }

  /// 检查表是否存在
  Future<bool> _tableExists(Database db, String tableName) async {
    final result = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tableName],
    );
    return result.isNotEmpty;
  }

  /// 确保指定用户的表已创建（登录成功后调用）
  Future<void> ensureUserTables(int userId) async {
    final db = await database;
    // 检查消息表是否存在，不存在则创建
    final hasMessages = await _tableExists(db, Tables.messagesTable(userId));
    if (!hasMessages) {
      await _createUserTables(db, userId);
    }
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
