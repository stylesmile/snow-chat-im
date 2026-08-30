// FavoriteModel（收藏数据模型）单元测试
//
// 覆盖：模型 JSON 序列化/反序列化，确保收藏数据在本地持久化时可正确读写。
// 背景：收藏模块是本仓库对标唐道道 IM"收藏模块"的 Feature，文本/图片消息可收藏，
// 收藏数据保存在本地 SQLite（favorites_{userId} 表），模型是持久化的基础。
import 'package:flutter_test/flutter_test.dart';
import 'package:snow_chat/models/favorite_model.dart';

void main() {
  group('FavoriteModel', () {
    test('fromJson 正确解析全部字段', () {
      // 准备 - 构造与后端/本地存储一致的 JSON
      final json = {
        'id': 1,
        'messageId': 99,
        'type': 'text',
        'content': '这是一条收藏的文本',
        'fromUserId': 123,
        'fromNickname': '小明',
        'createTime': 1700000000123,
      };

      // 执行 - 反序列化
      final model = FavoriteModel.fromJson(json);

      // 验证 - 各字段逐项断言
      expect(model.id, 1);
      expect(model.messageId, 99);
      expect(model.type, 'text');
      expect(model.content, '这是一条收藏的文本');
      expect(model.fromUserId, 123);
      expect(model.fromNickname, '小明');
      expect(model.createTime, 1700000000123);
    });

    test('fromJson 空 map 使用默认值兜底', () {
      // 执行 - 空对象反序列化
      final model = FavoriteModel.fromJson(const {});

      // 验证 - 无需反射即安全兜底
      expect(model.id, 0);
      expect(model.messageId, 0);
      expect(model.type, 'text');
      expect(model.content, '');
      expect(model.fromNickname, '');
    });

    test('toJson 生成与 fromJson 一致的结构', () {
      // 准备
      final model = FavoriteModel(
        id: 5,
        messageId: 88,
        type: 'image',
        content: 'https://example.com/a.png',
        fromUserId: 456,
        fromNickname: '小红',
        createTime: 1700000100,
      );

      // 执行
      final json = model.toJson();

      // 验证 - 关键字段往返一致
      expect(json['messageId'], 88);
      expect(json['type'], 'image');
      expect(json['content'], 'https://example.com/a.png');
      expect(json['fromUserId'], 456);
      expect(json['fromNickname'], '小红');
    });
  });
}