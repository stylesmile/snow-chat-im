import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../core/cache/favorite_cache_manager.dart';
import '../../core/utils/date_utils.dart' as app_date_utils;
import '../../models/favorite_model.dart';

/// "我的收藏"页面（对标唐道道 IM 收藏模块）
///
/// 展示当前用户收藏的文本/图片消息列表，来自本地 SQLite（favorites_{userId} 表）。
/// 交互与设计（对应唐道道"收藏"免费功能 + Snow Chat 深色风格）：
/// 1. 顶部 AppBar 标题"我的收藏"
/// 2. 列表项：消息类型图标 + 内容 + 来源昵称 + 收藏时间
/// 3. 长按项弹出确认框，可"取消收藏"
/// 4. 无收藏时显示空态文案"暂无收藏"
///
/// [cache] 可选注入的收藏缓存管理器（供测试替换为内存 SQLite 实例）。
/// [userId] 可选注入的当前用户ID（供测试绕过登录态，生产从 AuthProvider 读取）。
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key, this.cache, this.userId});

  /// 测试注入用：默认使用单例 FavoriteCacheManager
  final FavoriteCacheManager? cache;

  /// 测试注入用：默认从 AuthProvider 读取当前登录用户
  final int? userId;

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  // 卡片/背景色与个人中心、设置页保持一致
  static const Color _bgColor = Color(0xFF111111);
  static const Color _cardColor = Color(0xFF1E1E1E);

  // 已加载的收藏列表与加载状态
  List<FavoriteModel> _favorites = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // 页面初始化时加载收藏列表
    _loadFavorites();
  }

  /// 从本地 SQLite 加载当前用户的收藏列表
  Future<void> _loadFavorites() async {
    // 需要登录用户才能生成带用户ID前缀的表（测试通过 userId 注入）
    final userId = widget.userId ?? context.read<AuthProvider>().userId;
    if (userId == null) {
      // 未登录置为非加载态
      if (mounted) setState(() => _loading = false);
      return;
    }

    // 使用注入实例（测试）或生产单例
    final cache = widget.cache ?? FavoriteCacheManager()
      ..setUserId(userId);
    // 单例需初始化底层数据库；测试注入的实例 init() 为空操作不破坏注入
    await cache.init();

    final items = await cache.list();
    if (!mounted) return;
    setState(() {
      _favorites = items;
      _loading = false;
    });
  }

  /// 长按收藏项：弹出确认框，确认后取消收藏并刷新列表
  Future<void> _confirmRemove(FavoriteModel favorite) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _cardColor,
          title: Text(l10n.removeFavorite, style: const TextStyle(color: Colors.white)),
          content: Text(
            favorite.type == 'image'
                ? '${l10n.image}（${l10n.removeFavorite}）'
                : favorite.content,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            // 取消：关闭弹窗，不做删除
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel, style: const TextStyle(color: Colors.white70)),
            ),
            // 确认删除
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.removeFavorite, style: const TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    // 执行取消收藏
    final userId = widget.userId ?? context.read<AuthProvider>().userId;
    if (userId == null) return;
    final cache = widget.cache ?? FavoriteCacheManager()..setUserId(userId);
    await cache.removeById(favorite.id);

    // 从列表移除该收藏，刷新界面
    if (!mounted) return;
    setState(() => _favorites.removeWhere((f) => f.id == favorite.id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _cardColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(l10n.myFavorites),
        leading: const BackButton(color: Colors.white),
      ),
      body: _buildBody(l10n),
    );
  }

  /// 根据加载/空/有数据三种状态渲染主体
  Widget _buildBody(AppLocalizations l10n) {
    // 加载中：居中转圈
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    // 无收藏：空态文案
    if (_favorites.isEmpty) {
      return Center(
        child: Text(_placeholderText(l10n), style: const TextStyle(color: Colors.grey)),
      );
    }
    // 有收藏：列表
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      separatorBuilder: (_, __) =>
          Divider(height: 1, indent: 64, color: Colors.white.withValues(alpha: 0.06)),
      itemCount: _favorites.length,
      itemBuilder: (context, index) => _buildItem(_favorites[index]),
    );
  }

  /// 空态文案：图片/文本统一用"暂无收藏"
  String _placeholderText(AppLocalizations l10n) => l10n.favoriteEmpty;

  /// 构建单个收藏项（类型图标 + 内容 + 来源 + 时间）
  Widget _buildItem(FavoriteModel favorite) {
    final l10n = AppLocalizations.of(context)!;
    // 图片类型的占位文案（图片 content 为 URL，列表页不加载缩略图）
    final isImage = favorite.type == 'image';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isImage ? const Color(0xFF3B82F6) : const Color(0xFF00C8E8),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          isImage ? Icons.image : Icons.text_fields_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
      title: Text(
        isImage ? l10n.image : favorite.content,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontSize: 15),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          '${favorite.fromNickname} · ${app_date_utils.DateUtils.formatTime(favorite.createTime)}',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
        ),
      ),
      // 长按呼出"取消收藏"确认
      onLongPress: () => _confirmRemove(favorite),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
    );
  }
}