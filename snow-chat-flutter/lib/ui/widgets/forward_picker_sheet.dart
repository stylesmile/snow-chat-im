// ForwardPickerSheet（消息转发目标选择器）
//
// 消息长按菜单选择"转发"后弹出，让用户选择要把消息转发到哪个会话（好友）。
// 会话功能共用入口：需求3（消息转发）。
//
// 设计原因：
// - ChatDetailScreen 直接 pump 会有 MQTT/SQLite 依赖，无法纯 UI 测试；
//   因此把转发选择器抽为独立组件，可单独做 widget 测试。
// - 组件通过 [onSelect] 回调把用户选中的目标传出（测试友好）；
//   同时提供 [showForwardPickerSheet] 便捷方法，以底部弹窗形式弹出并返回所选目标。
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

/// 转发目标类型
enum ForwardTargetType { friend, group }

/// 转发选择器中的一个可选目标
///
/// [targetId] 对端用户ID（私聊）或群组ID；
/// [targetType] 会话类型：friend=私聊 / group=群聊；
/// [displayName] 展示名称（昵称/群名）；
/// [avatar] 可选头像地址，为空时用名称首字符占位。
class ForwardTarget {
  final int targetId;

  /// 会话类型：friend / group
  final String targetType;

  /// 展示名称
  final String displayName;

  /// 头像地址（可选）
  final String? avatar;

  const ForwardTarget({
    required this.targetId,
    required this.targetType,
    required this.displayName,
    this.avatar,
  });
}

/// 以底部弹窗形式展示转发目标选择器。
///
/// [targets] 可选的转发目标列表。
/// 返回用户选中的 [ForwardTarget]，取消（点空白处关闭）返回 null。
Future<ForwardTarget?> showForwardPickerSheet(
  BuildContext context,
  List<ForwardTarget> targets,
) {
  // 用底部弹窗承载目标列表，返回所选目标
  return showModalBottomSheet<ForwardTarget>(
    context: context,
    // 圆角 + 深色背景，贴合消息操作菜单的视觉风格
    backgroundColor: const Color(0xFF1E1E1E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => ForwardPickerSheet(targets: targets),
  );
}

/// 转发目标选择器内容组件。
///
/// 顶部展示标题，下方列出可选目标。点击某个目标时：
/// 1. 若提供了 [onSelect] 则回调该目标（用于单元测试）；
/// 2. 若作为底部弹窗展示，则同时 [Navigator.pop] 返回该目标。
class ForwardPickerSheet extends StatelessWidget {
  /// 可选的转发目标列表
  final List<ForwardTarget> targets;

  /// 用户点击目标时的回调；不传则依赖底部弹窗 pop 返回
  final ValueChanged<ForwardTarget>? onSelect;

  const ForwardPickerSheet({
    super.key,
    required this.targets,
    this.onSelect,
  });

  void _handleSelect(BuildContext context, ForwardTarget target) {
    // 通知外部回调（单元测试场景）
    onSelect?.call(target);
    // 若处于底部弹窗中，pop 返回所选目标
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 读取当前语言的本地化文案
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: SizedBox(
        // 列表较高时允许内部滚动；用 min 高度避免顶满全屏
        height: MediaQuery.of(context).size.height * 0.5,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 顶部标题
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.selectForwardTarget,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // 目标列表（无目标时展示空态提示）
            Expanded(
              child: targets.isEmpty
                  ? Center(
                      child: Text(
                        l10n.noData,
                        style: const TextStyle(color: Colors.white38),
                      ),
                    )
                  : ListView.builder(
                      itemCount: targets.length,
                      itemBuilder: (ctx, index) {
                        final t = targets[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blueGrey,
                            // 名称不为空时取首字符作占位头像
                            child: Text(
                              t.displayName.isNotEmpty ? t.displayName[0] : '?',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(
                            t.displayName,
                            style: const TextStyle(color: Colors.white),
                          ),
                          onTap: () => _handleSelect(ctx, t),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}