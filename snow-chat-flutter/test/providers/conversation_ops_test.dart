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
}