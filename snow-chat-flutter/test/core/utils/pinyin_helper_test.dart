// PinyinHelper 单元测试
// 覆盖 ASCII 字母、数字、中文首字母、空串等边界情况
import 'package:flutter_test/flutter_test.dart';
import 'package:snow_chat/core/utils/pinyin_helper.dart';

void main() {
  group('PinyinHelper', () {
    test('大写英文返回大写', () {
      expect(PinyinHelper.getFirstLetter('ABC'), equals('A'));
    });

    test('小写英文返回大写', () {
      expect(PinyinHelper.getFirstLetter('abc'), equals('A'));
    });

    test('空串返回 #', () {
      expect(PinyinHelper.getFirstLetter(''), equals('#'));
    });

    test('数字归入 # 组', () {
      expect(PinyinHelper.getFirstLetter('123'), equals('#'));
    });

    test('中文姓名取拼音首字母', () {
      // pinyin 库对常见汉字应返回首字母大写的拼音片段
      final letter = PinyinHelper.getFirstLetter('张三');
      expect(letter, equals('Z'));
    });

    test('compareLetter 对中文按字母序排序', () {
      expect(PinyinHelper.compareLetter('A', 'B'), lessThan(0));
      expect(PinyinHelper.compareLetter('B', 'A'), greaterThan(0));
      expect(PinyinHelper.compareLetter('A', 'A'), equals(0));
    });

    test('compareLetter 将 # 排在最后', () {
      expect(PinyinHelper.compareLetter('#', 'A'), greaterThan(0));
      expect(PinyinHelper.compareLetter('A', '#'), lessThan(0));
      expect(PinyinHelper.compareLetter('#', '#'), equals(0));
    });
  });
}
