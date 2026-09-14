// MessageUtils 工具方法测试
//
// 覆盖撤回权限判断逻辑：
// 1. 仅本人发送的消息可撤回
// 2. 仅限发送成功/已读且 2 分钟内可撤回
// 3. 发送中/失败、超过 2 分钟的消息不可撤回
import 'package:flutter_test/flutter_test.dart';
import 'package:snow_chat/core/utils/message_utils.dart';

void main() {
  final now = DateTime.now().millisecondsSinceEpoch;

  group('MessageUtils.canRecallMessage', () {
    test('本人消息且 2 分钟内已发送成功，可以撤回', () {
      final canRecall = MessageUtils.canRecallMessage(
        isMe: true,
        createTime: now - 60000, // 1 分钟前
        status: 'sent',
        nowMillis: now,
      );
      expect(canRecall, isTrue);
    });

    test('本人消息且已读但 2 分钟内，可以撤回', () {
      final canRecall = MessageUtils.canRecallMessage(
        isMe: true,
        createTime: now - 90000,
        status: 'read',
        nowMillis: now,
      );
      expect(canRecall, isTrue);
    });

    test('非本人消息不可撤回', () {
      final canRecall = MessageUtils.canRecallMessage(
        isMe: false,
        createTime: now - 10000,
        status: 'sent',
        nowMillis: now,
      );
      expect(canRecall, isFalse);
    });

    test('发送中（sending）的消息不可撤回', () {
      final canRecall = MessageUtils.canRecallMessage(
        isMe: true,
        createTime: now - 5000,
        status: 'sending',
        nowMillis: now,
      );
      expect(canRecall, isFalse);
    });

    test('发送失败（failed）的消息不可撤回', () {
      final canRecall = MessageUtils.canRecallMessage(
        isMe: true,
        createTime: now - 5000,
        status: 'failed',
        nowMillis: now,
      );
      expect(canRecall, isFalse);
    });

    test('超过 2 分钟的消息不可撤回', () {
      final canRecall = MessageUtils.canRecallMessage(
        isMe: true,
        createTime: now - 121000, // 超过 2 分钟
        status: 'sent',
        nowMillis: now,
      );
      expect(canRecall, isFalse);
    });
  });

  group('getMessagePreview 会话摘要', () {
    test('媒体消息的 content 是 URL 时显示中文占位', () {
      const url = 'http://192.168.0.100:8091/file/raw/images/uuid.png';
      expect(MessageUtils.getMessagePreview('image', url), '[图片]');
      expect(MessageUtils.getMessagePreview('video', url), '[视频]');
      expect(MessageUtils.getMessagePreview('voice', url), '[语音]');
      expect(
        MessageUtils.getMessagePreview(
            'file', 'http://192.168.0.100:8091/file/raw/files/a.pdf'),
        '[文件]',
      );
      expect(MessageUtils.getMessagePreview('emoji', '😀'), '[表情]');
      expect(MessageUtils.getMessagePreview('recall', ''), '[撤回消息]');
    });

    test('文本消息超长时截断，短文本原样显示', () {
      expect(MessageUtils.getMessagePreview('text', '你好'), '你好');
      final long = 'a' * 30;
      expect(MessageUtils.getMessagePreview('text', long), '${'a' * 20}...');
    });

    test('self（文件传输助手）按 URL 扩展名反推占位，本地文本原样显示', () {
      expect(
        MessageUtils.getMessagePreview(
            'self', 'http://192.168.0.100:8091/file/raw/images/x.jpg'),
        '[图片]',
      );
      expect(
        MessageUtils.getMessagePreview(
            'self', 'http://192.168.0.100:8091/file/raw/videos/x.mp4'),
        '[视频]',
      );
      expect(
        MessageUtils.getMessagePreview(
            'self', 'http://192.168.0.100:8091/file/raw/voices/x.mp3'),
        '[语音]',
      );
      expect(MessageUtils.getMessagePreview('self', '随手记一段话'), '随手记一段话');
    });
  });
}