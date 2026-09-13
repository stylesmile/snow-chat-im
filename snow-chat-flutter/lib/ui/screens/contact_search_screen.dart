import 'package:flutter/material.dart';
import 'package:lpinyin/lpinyin.dart' as lpinyin;
import '../../l10n/app_localizations.dart';
import '../../models/friend_model.dart';
import '../widgets/avatar_widget.dart';
import 'chat_detail_screen.dart';

/// 通讯录搜索页：只在「已添加的好友」范围内检索，不碰加好友流程。
///
/// 入口是通讯录标题栏的搜索按钮。该按钮此前误跳「添加好友」页，与它右侧的
/// person_add 按钮功能完全重复（两处都打开 AddFriendScreen），导致在通讯录里
/// 搜自己的好友永远搜不到。本页把搜索范围收敛为通讯录好友，点击结果直接进单聊。
///
/// 数据源由调用方 ContactTab 传入（它已经做过「本地缓存优先 + 服务端刷新」），
/// 所以本页不再发起任何请求：打开即可输入，输入即过滤，没有网络等待。
class ContactSearchScreen extends StatefulWidget {
  /// 通讯录当前展示的好友列表（页面内的只读快照）
  final List<FriendModel> friends;

  const ContactSearchScreen({super.key, required this.friends});

  @override
  State<ContactSearchScreen> createState() => _ContactSearchScreenState();
}

class _ContactSearchScreenState extends State<ContactSearchScreen> {
  final TextEditingController _controller = TextEditingController();

  /// 当前关键词（与输入框内容同步，用 setState 逐字刷新结果）
  String _keyword = '';

  /// 好友 userId -> 拼音检索串 的缓存。
  /// 拼音转换是全表最贵的一步，缓存后每次输入只做字符串 contains，
  /// 否则每敲一个字都要对全部好友重新跑一遍拼音字典。
  Map<int, String>? _pinyinCache;

  @override
  void didUpdateWidget(covariant ContactSearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 好友列表被整体替换时（下拉刷新后重新打开）缓存失效，否则会搜到旧拼音
    if (!identical(oldWidget.friends, widget.friends)) {
      _pinyinCache = null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 通讯录展示名：有备注优先用备注，与 ContactTab 列表的口径保持一致
  String _displayName(FriendModel f) => f.remark.isNotEmpty ? f.remark : f.nickname;

  /// 生成一个名称的拼音检索串：同时包含全拼与首字母。
  ///
  /// 中文用户搜人时两种输入习惯都有——「zhangsan」和「zs」都应命中「张三」，
  /// 所以把 `zhangsan zs` 拼在一起交给 contains 判断，命中任一即算匹配。
  static String _pinyinOf(String text) {
    if (text.isEmpty) return '';
    try {
      final full = lpinyin.PinyinHelper.getPinyinE(text, separator: '').toLowerCase();
      final short = lpinyin.PinyinHelper.getShortPinyin(text).toLowerCase();
      return '$full $short';
    } catch (_) {
      // 拼音库异常不应影响搜索，退化为「只按原文匹配」
      return '';
    }
  }

  Map<int, String> get _pinyin => _pinyinCache ??= {
        for (final f in widget.friends)
          // 备注与昵称都要能搜到，各自生成一份拼音
          f.userId: '${_pinyinOf(_displayName(f))} ${_pinyinOf(f.nickname)}',
      };

  /// 是否命中关键词：昵称 / 备注原文包含，或拼音（全拼、首字母）包含
  bool _matches(FriendModel f, String kw) {
    if (f.nickname.toLowerCase().contains(kw)) return true;
    if (f.remark.toLowerCase().contains(kw)) return true;
    return (_pinyin[f.userId] ?? '').contains(kw);
  }

  /// 当前结果：关键词为空时返回全部好友（进页即可点选），否则按关键词过滤
  List<FriendModel> get _results {
    final kw = _keyword.trim().toLowerCase();
    final list = kw.isEmpty
        ? List<FriendModel>.of(widget.friends)
        : widget.friends.where((f) => _matches(f, kw)).toList();
    // 与通讯录列表同样按展示名排序，结果顺序稳定且可预期
    list.sort((a, b) => _displayName(a).compareTo(_displayName(b)));
    return list;
  }

  /// 点击结果：进入与该好友的单聊
  void _openChat(FriendModel friend) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          targetId: friend.userId,
          targetType: 'friend',
          targetName: _displayName(friend),
        ),
      ),
    );
  }

  void _clearKeyword() {
    _controller.clear();
    setState(() => _keyword = '');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final results = _results;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 1,
        title: Text(l10n.search),
      ),
      body: Column(
        children: [
          // 顶部输入框：自动聚焦，进页即可打字
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: (value) => setState(() => _keyword = value),
              decoration: InputDecoration(
                // 用「搜索」而不是全局搜索页的「请输入用户名或昵称」：
                // 后者会引导用户去输用户名，而本页只在好友的昵称/备注/拼音里找，
                // 按用户名搜是本页不支持的能力，提示词不该这么写。
                hintText: l10n.search,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _keyword.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearKeyword,
                      ),
                filled: true,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(child: _buildResultArea(l10n, results)),
        ],
      ),
    );
  }

  /// 结果区：空通讯录 / 无命中 / 命中列表 三态
  Widget _buildResultArea(AppLocalizations l10n, List<FriendModel> results) {
    // 通讯录本身就没有好友，与「搜不到」区分开，避免误导用户以为输错了字
    if (widget.friends.isEmpty) {
      return _buildEmptyHint(l10n.noContacts);
    }
    if (results.isEmpty) {
      return _buildEmptyHint(l10n.noSearchResult);
    }
    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) => _buildFriendTile(results[index]),
    );
  }

  Widget _buildEmptyHint(String text) {
    return Center(
      child: Text(
        text,
        style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
      ),
    );
  }

  /// 好友结果条目：头像 + 展示名；用了备注时把昵称放在副标题，便于确认是谁
  Widget _buildFriendTile(FriendModel friend) {
    final name = _displayName(friend);
    final showNickname = friend.remark.isNotEmpty &&
        friend.nickname.isNotEmpty &&
        friend.remark != friend.nickname;

    return ListTile(
      leading: AvatarWidget(
        imageUrl: friend.avatar,
        initials: name.isNotEmpty ? name[0] : '?',
        size: 40,
      ),
      title: Text(name, style: const TextStyle(fontSize: 15)),
      subtitle: showNickname
          ? Text(friend.nickname, style: const TextStyle(fontSize: 12, color: Colors.white54))
          : null,
      onTap: () => _openChat(friend),
    );
  }
}
