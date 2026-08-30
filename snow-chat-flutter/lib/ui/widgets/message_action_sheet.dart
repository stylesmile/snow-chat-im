// MessageActionSheet（消息长按操作菜单）
//
// 提供消息气泡长按后的操作项（复制 / 撤回 / 转发）。
// 会话功能的共用入口：复制（需求1）、撤回（需求2）、转发（需求3）都会复用。
//
// 设计原因：
// - ChatDetailScreen 直接 pump 会有 MQTT/SQLite 依赖，无法纯 UI 测试；
//   因此把菜单抽为独立组件，可单独做 widget 测试。
// - 组件通过 [onAction] 回调把用户选择的动作传出（测试友好）；
//   同时提供 [showMessageActionSheet] 便捷方法，以底部弹窗形式弹出并返回所选动作。
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

/// 消息长按菜单可选操作
enum MessageAction { copy, recall, forward, favorite }

/// 以底部弹窗形式展示消息操作菜单。
///
/// [canRecall] 是否允许撤回（本人发送且在 3 分钟内，或群主/管理员）。
/// [canForward] 是否允许转发。
/// [canFavorite] 是否允许收藏（文本/图片消息）。
/// 返回用户选择的 [MessageAction]，取消（点空白处关闭）返回 null。
Future<MessageAction?> showMessageActionSheet(
  BuildContext context, {
  required bool canRecall,
  required bool canForward,
  bool canFavorite = false,
}) {
  // 用底部弹窗承载菜单，返回所选动作
  return showModalBottomSheet<MessageAction>(
    context: context,
    // 圆角 + 保底安全边距，贴合深色主题
    backgroundColor: const Color(0xFF1E1E1E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => MessageActionSheet(
      canRecall: canRecall,
      canForward: canForward,
      canFavorite: canFavorite,
    ),
  );
}

/// 消息操作菜单内容组件。
///
/// 按用户权限渲染操作项。点击某项时：
/// 1. 若提供了 [onAction] 则回调该动作（用于单元测试）；
/// 2. 若作为底部弹窗展示，则同时 [Navigator.pop] 返回该动作。
class MessageActionSheet extends StatelessWidget {
  /// 是否展示"撤回"操作项
  final bool canRecall;

  /// 是否展示"转发"操作项
  final bool canForward;

  /// 是否展示"收藏"操作项（文本/图片消息可收藏）
  final bool canFavorite;

  /// 用户点击某项时的回调；不传则依赖底部弹窗 pop 返回
  final ValueChanged<MessageAction>? onAction;

  const MessageActionSheet({
    super.key,
    required this.canRecall,
    required this.canForward,
    this.canFavorite = false,
    this.onAction,
  });

  // 组装菜单项：文案走本地化（多语言支持）
  List<({MessageAction action, IconData icon, String label})> _items(BuildContext context) {
    // 读取当前语言的本地化文案
    final l10n = AppLocalizations.of(context)!;
    return [
      (action: MessageAction.copy, icon: Icons.copy_rounded, label: l10n.copy),
      // 仅本人可撤回时才展示"撤回"
      if (canRecall)
        (action: MessageAction.recall, icon: Icons.history_edu_rounded, label: l10n.recallMessage),
      if (canForward)
        (action: MessageAction.forward, icon: Icons.send_rounded, label: l10n.forward),
      // 文本/图片消息可收藏
      if (canFavorite)
        (action: MessageAction.favorite, icon: Icons.star_rounded, label: l10n.favorite),
    ];
  }

  void _handleTap(BuildContext context, MessageAction action) {
    // 通知外部回调（单元测试场景）
    onAction?.call(action);
    // 若处于底部弹窗中，pop 返回所选动作
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(action);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _items(context).map((item) {
            // 每个操作项：图标 + 文案，左右留白
            return ListTile(
              leading: Icon(item.icon, color: Colors.white70),
              title: Text(item.label, style: const TextStyle(color: Colors.white)),
              onTap: () => _handleTap(context, item.action),
            );
          }).toList(),
        ),
      ),
    );
  }
}