import 'package:flutter_test/flutter_test.dart';
import 'package:snow_chat/services/notification_policy.dart';

void main() {
  group('NotificationPolicy.buildIncomingMessageNotification', () {
    test('should build plain text notification with preview body', () {
      // 准备 - 一条普通好友文本消息数据
      final data = <String, dynamic>{
        'fromUserId': 100,
        'toUserId': 200,
        'type': 'text',
        'content': '你好呀',
      };

      // 执行 - 构建通知内容
      final result = NotificationPolicy.buildIncomingMessageNotification(
        data: data,
        currentUserId: 200,
        senderName: '小明',
      );

      // 验证 - 标题为发送方昵称，正文为文本摘要
      expect(result, isNotNull);
      expect(result!.title, equals('小明'));
      expect(result.body, equals('你好呀'));
      expect(result.isGroup, isFalse);
      expect(result.fromUserId, equals(100));
    });

    test('should skip file-helper self message', () {
      // 准备 - 文件传输助手把自己发给自己的回推（type=self，from==to==自己）
      final data = <String, dynamic>{
        'fromUserId': 42,
        'toUserId': 42,
        'type': 'self',
        'content': 'https://oss.example.com/images/a.png',
      };

      // 执行 + 验证 - 自己发给自己不弹通知
      final result = NotificationPolicy.buildIncomingMessageNotification(
        data: data,
        currentUserId: 42,
      );
      expect(result, isNull);
    });

    test('should show image placeholder for image message', () {
      // 准备 - 图片消息（type=image）
      final data = <String, dynamic>{
        'fromUserId': 100,
        'toUserId': 200,
        'type': 'image',
        'content': 'https://oss.example.com/b.png',
      };

      // 执行 - 构建通知内容
      final result = NotificationPolicy.buildIncomingMessageNotification(
        data: data,
        currentUserId: 200,
        senderName: '小红',
      );

      // 验证 - 正文为图片占位
      expect(result, isNotNull);
      expect(result!.body, equals('[图片]'));
    });

    test('should mark group message and fallback to default title when name empty',
        () {
      // 准备 - 群消息数据，senderName 缺省
      final data = <String, dynamic>{
        'fromUserId': 100,
        'toUserId': 200,
        'groupId': 300,
        'type': 'text',
        'content': '大家好',
      };

      // 执行 - 群消息且无昵称
      final result = NotificationPolicy.buildIncomingMessageNotification(
        data: data,
        currentUserId: 200,
      );

      // 验证 - 群消息标识正确、标题回落为默认文案
      expect(result, isNotNull);
      expect(result!.isGroup, isTrue);
      expect(result.title, equals(NotificationPolicy.defaultTitle));
      expect(result.body, equals('大家好'));
    });
  });
}