import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';
import '../../l10n/app_localizations.dart';

/// SQLite 浏览器页面（调试工具）
///
/// 通过快速点击"关于"多次触发，可查看本地数据库结构：
/// - 列出所有数据表
/// - 点击表名进入数据浏览，支持分页（每页 20 条）
class SqliteBrowserScreen extends StatefulWidget {
  const SqliteBrowserScreen({super.key});

  @override
  State<SqliteBrowserScreen> createState() => _SqliteBrowserScreenState();
}

class _SqliteBrowserScreenState extends State<SqliteBrowserScreen> {
  List<Map<String, dynamic>> _tables = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  /// 加载所有用户表（排除 sqlite_master 系统表）
  Future<void> _loadTables() async {
    try {
      final db = await DatabaseHelper().database;
      // 查询 sqlite_master 中 type='table' 且名称不以 'sqlite_' 开头的记录
      final List<Map<String, dynamic>> rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
      );
      if (mounted) {
        setState(() {
          _tables = rows;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('SQLite 浏览器'),
        leading: const BackButton(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error != null
              ? Center(
                  child: Text('加载失败: $_error', style: const TextStyle(color: Colors.red)),
                )
              : _tables.isEmpty
                  ? Center(
                      child: Text(
                        l10n.noData,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _tables.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0x1FFFFFFF)),
                      itemBuilder: (context, index) {
                        final tableName = _tables[index]['name'] as String;
                        return ListTile(
                          leading: const Icon(Icons.table_chart, color: Colors.blueAccent),
                          title: Text(tableName, style: const TextStyle(color: Colors.white)),
                          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                          onTap: () => _openTableDetail(context, tableName),
                        );
                      },
                    ),
    );
  }

  /// 打开指定表的详情页面（含分页数据浏览）
  void _openTableDetail(BuildContext context, String tableName) async {
    final navigator = Navigator.of(context);
    final l10n = AppLocalizations.of(context)!;

    await navigator.push(
      MaterialPageRoute(
        builder: (_) => _TableDetailScreen(
          tableName: tableName,
          l10n: l10n,
        ),
      ),
    );
  }
}

/// 单个表的数据浏览页面，支持分页（每页 20 条）
class _TableDetailScreen extends StatefulWidget {
  final String tableName;
  final AppLocalizations l10n;

  const _TableDetailScreen({required this.tableName, required this.l10n});

  @override
  State<_TableDetailScreen> createState() => _TableDetailScreenState();
}

class _TableDetailScreenState extends State<_TableDetailScreen> {
  static const int _pageSize = 20;
  int _page = 0;
  int _totalRows = 0;
  List<Map<String, dynamic>> _rows = [];
  List<String> _columns = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// 加载表结构和第一页数据
  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final db = await DatabaseHelper().database;

      // 查询列名（PRAGMA 返回 {name, cid, type, notnull, dflt_value, pk}）
      final List<dynamic> pragmaResult = await db.rawQuery(
        'PRAGMA table_info(${widget.tableName})',
      );
      final columns = pragmaResult.map((m) => m['name'] as String).toList();

      // 查询总行数（用 count(*) 获取准确数字）
      final countResult = await db.rawQuery('SELECT COUNT(*) as cnt FROM "${widget.tableName}"');
      final total = (countResult.first['cnt'] as int? ?? 0);

      // 查询当前页数据（LIMIT + OFFSET）
      final data = await db.rawQuery(
        'SELECT * FROM "${widget.tableName}" LIMIT $_pageSize OFFSET ${_page * _pageSize}',
      );

      if (mounted) {
        setState(() {
          _columns = columns;
          _rows = data;
          _totalRows = total;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _prevPage() {
    if (_page > 0) {
      setState(() => _page--);
      _loadData();
    }
  }

  void _nextPage() {
    if ((_page + 1) * _pageSize < _totalRows) {
      setState(() => _page++);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalPages = (_totalRows + _pageSize - 1) ~/ _pageSize;

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.tableName),
        leading: const BackButton(color: Colors.white),
        actions: [
          // 刷新按钮
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: '刷新',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error != null
              ? Center(child: Text('加载失败: $_error', style: const TextStyle(color: Colors.red)))
              : Column(
                  children: [
                    // 分页信息条
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: const Color(0xFF1E1E1E),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${widget.l10n.total}: $_totalRows | ${widget.l10n.page}: ${_page + 1}/$totalPages',
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left, color: Colors.white70, size: 20),
                                onPressed: _prevPage,
                                tooltip: '上一页',
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right, color: Colors.white70, size: 20),
                                onPressed: _nextPage,
                                tooltip: '下一页',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // 数据表格
                    Expanded(
                      child: _rows.isEmpty
                          ? Center(
                              child: Text(
                                widget.l10n.noData,
                                style: const TextStyle(color: Colors.grey),
                              ),
                            )
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(const Color(0xFF2A2A2A)),
                                dataRowColor: WidgetStateProperty.all(const Color(0xFF1A1A1A)),
                                columns: _columns
                                    .map((col) => DataColumn(
                                          label: Text(
                                            col,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ))
                                    .toList(),
                                rows: _rows.map((row) {
                                  return DataRow(
                                    cells: _columns.map((col) {
                                      final value = row[col];
                                      // 将值转为可读字符串，null 显示为 "-"
                                      final display = value == null
                                          ? '-'
                                          : value.toString().length > 50
                                              ? '${value.toString().substring(0, 50)}...'
                                              : value.toString();
                                      return DataCell(
                                        Text(
                                          display,
                                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                  );
                                }).toList(),
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }
}
