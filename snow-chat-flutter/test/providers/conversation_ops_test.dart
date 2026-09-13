// 会话置顶/免打扰/删除 相关模型与 Provider 单元测试
//
// 背景：对标唐道道 IM 免费功能"会话置顶/免打扰/删除聊天"。会话需支持：
//   - 置顶：置顶会话排在列表最前，isPinned=true
//   - 免打扰：isMuted=true，新消息不发通知
//   - 删除：从会话列表移除
// 本测试验证 Conversation 模型携带新字段，以及 ChatProvider 的置顶/免打扰/
// 删除操作正确更新内存列表。
import 'package:flutter_test/flutter_test.dart';
import 'package:snow_chat/providers/chat_provider.dart';

void main() {
  group('Conversation', () {
    test('默认 isPinned=false 且 isMuted=false', () {
      final conv = Conversation(
        targetId: 1,
        targetType: 'friend',
        lastMsg: 'hi',
        lastMsgTime: 100,
      );
      expect(conv.isPinned, isFalse);
      expect(conv.isMuted, isFalse);
    });

    test('支持显式指定 isPinned 与 isMuted', () {
      final conv = Conversation(
        targetId: 1,
        targetType: 'friend',
        isPinned: true,
        isMuted: true,
      );
      expect(conv.isPinned, isTrue);
      expect(conv.isMuted, isTrue);
    });
  });

  group('ChatProvider 会话列表', () {
    test('togglePinned 可将会话置顶并回到列表顶', () {
      final provider = ChatProvider();
      provider.setConversations([
        Conversation(targetId: 2, targetType: 'friend', lastMsgTime: 200),
        Conversation(targetId: 1, targetType: 'friend', lastMsgTime: 100),
      ]);

      // 置顶 targetId=2 的会话
      provider.togglePinned(2, 'friend', pinned: true);
      expect(provider.conversations.first.targetId, 2);
      expect(provider.conversations.first.isPinned, isTrue);

      // 取消置顶后留在原位（不再排最前）
      provider.togglePinned(2, 'friend', pinned: false);
      expect(provider.conversations.firstWhere((c) => c.targetId == 2).isPinned, isFalse);
    });

    test('置顶列表按置顶在前、非置顶按时间倒序排列', () {
      final provider = ChatProvider();
      provider.setConversations([
        Conversation(targetId: 1, targetType: 'friend', lastMsgTime: 100),
        Conversation(targetId: 3, targetType: 'friend', lastMsgTime: 300),
        Conversation(targetId: 2, targetType: 'friend', lastMsgTime: 200, isPinned: true),
      ]);

      // 排序后置顶的 targetId=2 在最前
      expect(provider.conversations.first.targetId, 2);
    });

    test('toggleMuted 更新会话免打扰状态', () {
      final provider = ChatProvider();
      provider.setConversations([
        Conversation(targetId: 5, targetType: 'friend'),
      ]);
      provider.toggleMuted(5, 'friend', muted: true);
      expect(provider.conversations.first.isMuted, isTrue);
      provider.toggleMuted(5, 'friend', muted: false);
      expect(provider.conversations.first.isMuted, isFalse);
    });

    test('removeConversation 从列表移除指定会话', () {
      final provider = ChatProvider();
      provider.setConversations([
        Conversation(targetId: 1, targetType: 'friend'),
        Conversation(targetId: 2, targetType: 'group'),
      ]);
      provider.removeConversation(1, 'friend');
      expect(provider.conversations.length, 1);
      expect(provider.conversations.first.targetId, 2);
    });
  });

  // 聊天列表重复的防线：不同来源（本地库 / 服务端推送 / 通讯录跳转）都可能
  // 带进同一会话的多条记录，渲染前必须按 (targetType, targetId) 合并成一条。
  group('ChatProvider.setConversations 按会话 ID 去重', () {
    test('同一会话只保留最后消息时间最新的一条', () {
      final provider = ChatProvider();
      provider.setConversations([
        Conversation(targetId: 2, targetType: 'friend', lastMsg: 'old', lastMsgTime: 100),
        Conversation(targetId: 2, targetType: 'friend', lastMsg: 'new', lastMsgTime: 200),
      ]);

      expect(provider.conversations.length, 1);
      expect(provider.conversations.first.lastMsg, 'new');
      expect(provider.conversations.first.lastMsgTime, 200);
    });

    test('去重时保留置顶与免打扰标记（取并集，不丢用户设置）', () {
      final provider = ChatProvider();
      provider.setConversations([
        Conversation(targetId: 2, targetType: 'friend', lastMsgTime: 200, isPinned: true),
        Conversation(targetId: 2, targetType: 'friend', lastMsgTime: 100, isMuted: true),
      ]);

      final conv = provider.conversations.single;
      expect(conv.lastMsgTime, 200);
      expect(conv.isPinned, isTrue);
      expect(conv.isMuted, isTrue);
    });

    test('相同 id 但类型不同（好友/群）不合并', () {
      final provider = ChatProvider();
      provider.setConversations([
        Conversation(targetId: 2, targetType: 'friend'),
        Conversation(targetId: 2, targetType: 'group'),
      ]);

      expect(provider.conversations.length, 2);
    });
  });

  // 进入聊天页只清未读：不新建会话、不动最后消息与时间 ——
  // 这样「从通讯录点进某人的聊天再返回」不会让列表多出一条（也没有"新打开一条数据"的观感）。
  group('ChatProvider.clearUnread', () {
    test('只清未读数，不改最后消息与时间', () {
      final provider = ChatProvider();
      provider.setConversations([
        Conversation(
          targetId: 2,
          targetType: 'friend',
          lastMsg: 'hello',
          lastMsgTime: 100,
          unreadCount: 5,
        ),
      ]);

      provider.clearUnread(2, 'friend');

      final conv = provider.conversations.single;
      expect(conv.unreadCount, 0);
      expect(conv.lastMsg, 'hello');
      expect(conv.lastMsgTime, 100);
      expect(provider.conversations.length, 1);
    });

    test('会话不存在时什么也不做（不会凭空新建会话）', () {
      final provider = ChatProvider();
      provider.setConversations([
        Conversation(targetId: 2, targetType: 'friend'),
      ]);

      provider.clearUnread(99, 'friend');

      expect(provider.conversations.length, 1);
      expect(provider.conversations.first.targetId, 2);
    });
  });
}