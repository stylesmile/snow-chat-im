// ChatProvider 单元测试
// 覆盖：会话排序（置顶优先/同时间倒序）、去重保留最新+并集置顶/免打扰、
// updateConversation 保留已有置顶/免打扰、clearUnread 只改未读数、
// togglePinned / toggleMuted / removeConversation 等关键路径
import 'package:flutter_test/flutter_test.dart';
import 'package:snow_chat/providers/chat_provider.dart';

void main() {
  late ChatProvider provider;

  setUp(() {
    provider = ChatProvider();
  });

  group('ChatProvider.setConversations', () {
    test('排序：置顶会话排在前面', () {
      final recent = Conversation(targetId: 1, targetType: 'friend', lastMsgTime: 200);
      final old = Conversation(targetId: 2, targetType: 'friend', lastMsgTime: 100, isPinned: true);
      provider.setConversations([recent, old]);
      // pinned 在前，即便 its lastMsgTime 较小
      expect(provider.conversations[0].targetId, equals(2));
      expect(provider.conversations[1].targetId, equals(1));
    });

    test('排序：同置顶状态按 lastMsgTime 倒序', () {
      final a = Conversation(targetId: 1, targetType: 'friend', lastMsgTime: 300);
      final b = Conversation(targetId: 2, targetType: 'friend', lastMsgTime: 100);
      provider.setConversations([a, b]);
      expect(provider.conversations[0].targetId, equals(1));
      expect(provider.conversations[1].targetId, equals(2));
    });
  });

  group('ChatProvider._dedup', () {
    test('相同 (targetId, targetType) 只保留最后消息时间更大的一条', () {
      final older = Conversation(targetId: 10, targetType: 'friend', lastMsgTime: 100, lastMsg: 'old');
      final newer = Conversation(targetId: 10, targetType: 'friend', lastMsgTime: 200, lastMsg: 'new');
      provider.setConversations([older, newer]);
      expect(provider.conversations.length, equals(1));
      expect(provider.conversations.single.lastMsg, equals('new'));
      expect(provider.conversations.single.lastMsgTime, equals(200));
    });

    test('去重时置顶/免打扰取并集，避免丢失用户设置', () {
      final kept = Conversation(targetId: 1, targetType: 'friend', isPinned: true, isMuted: false);
      final incoming = Conversation(targetId: 1, targetType: 'friend', isPinned: false, isMuted: true);
      provider.setConversations([kept, incoming]);
      final result = provider.conversations.single;
      expect(result.isPinned, isTrue);
      expect(result.isMuted, isTrue);
    });
  });

  group('ChatProvider.updateConversation', () {
    test('新增一条不存在的会话会插到列表头部', () {
      provider.setConversations([]);
      final conv = Conversation(targetId: 5, targetType: 'friend', lastMsgTime: 10);
      provider.updateConversation(conv);
      expect(provider.conversations.length, equals(1));
      expect(provider.conversations.first.targetId, equals(5));
    });

    test('更新已存在会话时，保留原有的 isPinned / isMuted', () {
      final existing = Conversation(targetId: 5, targetType: 'friend', lastMsgTime: 100, isPinned: true, isMuted: true);
      provider.setConversations([existing]);
      // 外部 push 来的对话对象未携带置顶/免打扰，不应覆盖用户设置
      final patch = Conversation(targetId: 5, targetType: 'friend', lastMsgTime: 150, lastMsg: 'hi');
      provider.updateConversation(patch);
      final updated = provider.conversations.single;
      expect(updated.isPinned, isTrue);
      expect(updated.isMuted, isTrue);
      expect(updated.lastMsg, equals('hi'));
    });
  });

  group('ChatProvider.clearUnread', () {
    test('把未读数清 0，其他字段不变', () {
      final conv = Conversation(targetId: 9, targetType: 'friend', lastMsgTime: 100, unreadCount: 5, isPinned: true);
      provider.setConversations([conv]);
      provider.clearUnread(9, 'friend');
      final after = provider.conversations.single;
      expect(after.unreadCount, equals(0));
      expect(after.isPinned, isTrue);
      expect(after.lastMsgTime, equals(100));
    });

    test('0 未读时不调用 notifyListeners（通过不触发 listener 验证）', () {
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);
      final conv = Conversation(targetId: 1, targetType: 'friend', unreadCount: 0);
      provider.setConversations([conv]);
      provider.clearUnread(1, 'friend');
      expect(notifyCount, equals(0));
    });

    test('列表中不存在该会话时不报错', () {
      provider.setConversations([]);
      expect(() => provider.clearUnread(99, 'friend'), returnsNormally);
      expect(provider.conversations, isEmpty);
    });
  });

  group('ChatProvider.togglePinned', () {
    test('置顶指定会话，并重排列表', () {
      final a = Conversation(targetId: 1, targetType: 'friend', lastMsgTime: 200);
      final b = Conversation(targetId: 2, targetType: 'friend', lastMsgTime: 100);
      provider.setConversations([a, b]);
      provider.togglePinned(2, 'friend', pinned: true);
      expect(provider.conversations[0].targetId, equals(2));
      expect(provider.conversations[1].targetId, equals(1));
    });

    test('取消置顶后恢复正常排序', () {
      final pinned = Conversation(targetId: 2, targetType: 'friend', lastMsgTime: 100, isPinned: true);
      final normal = Conversation(targetId: 1, targetType: 'friend', lastMsgTime: 200);
      provider.setConversations([pinned, normal]);
      provider.togglePinned(2, 'friend', pinned: false);
      expect(provider.conversations[0].targetId, equals(1));
      expect(provider.conversations[1].targetId, equals(2));
    });

    test('列表中不存在该会话时不报错', () {
      provider.setConversations([]);
      expect(() => provider.togglePinned(99, 'friend', pinned: true), returnsNormally);
    });
  });

  group('ChatProvider.toggleMuted', () {
    test('开启/关闭免打扰', () {
      final conv = Conversation(targetId: 3, targetType: 'friend', isMuted: false);
      provider.setConversations([conv]);
      provider.toggleMuted(3, 'friend', muted: true);
      expect(provider.conversations.single.isMuted, isTrue);
      provider.toggleMuted(3, 'friend', muted: false);
      expect(provider.conversations.single.isMuted, isFalse);
    });

    test('列表中不存在该会话时不报错', () {
      provider.setConversations([]);
      expect(() => provider.toggleMuted(99, 'friend', muted: true), returnsNormally);
    });
  });

  group('ChatProvider.removeConversation', () {
    test('从列表中移除指定会话', () {
      final a = Conversation(targetId: 1, targetType: 'friend');
      final b = Conversation(targetId: 2, targetType: 'friend');
      provider.setConversations([a, b]);
      provider.removeConversation(1, 'friend');
      expect(provider.conversations.length, equals(1));
      expect(provider.conversations.single.targetId, equals(2));
    });

    test('列表中不存在该会话时不报错', () {
      provider.setConversations([]);
      expect(() => provider.removeConversation(99, 'friend'), returnsNormally);
    });
  });

  group('ChatProvider.messages', () {
    test('addMessage / setMessages / clearMessages', () {
      provider.setMessages([]);
      expect(provider.messages, isEmpty);
      provider.addMessage(ChatMessage(id: 1, fromUserId: 10, type: 'text', content: 'hi', status: 'sent', createTime: 1));
      expect(provider.messages.length, equals(1));
      provider.clearMessages();
      expect(provider.messages, isEmpty);
    });
  });

  group('ChatProvider.totalUnreadCount', () {
    test('汇总所有会话未读数', () {
      final list = <Conversation>[
        Conversation(targetId: 1, targetType: 'friend', unreadCount: 3),
        Conversation(targetId: 2, targetType: 'friend', unreadCount: 7),
      ];
      provider.setConversations(list);
      expect(provider.totalUnreadCount, equals(10));
    });

    test('空列表总未读数为 0', () {
      provider.setConversations([]);
      expect(provider.totalUnreadCount, equals(0));
    });
  });
}
