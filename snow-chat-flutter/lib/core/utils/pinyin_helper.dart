import 'package:lpinyin/lpinyin.dart' as lpinyin;

class PinyinHelper {
  /// 获取字符串首字母（用于通讯录字母索引）
  static String getFirstLetter(String text) {
    if (text.isEmpty) return '#';
    final firstChar = text[0];
    final code = firstChar.codeUnitAt(0);

    // ASCII 字母 A-Z, a-z
    if ((code >= 65 && code <= 90) || (code >= 97 && code <= 122)) {
      return firstChar.toUpperCase();
    }

    // 数字 0-9 -> 归为 '#'
    if (code >= 48 && code <= 57) {
      return '#';
    }

    // 中文或其他字符，尝试转拼音首字母
    try {
      final pinyin = lpinyin.PinyinHelper.getShortPinyin(firstChar);
      if (pinyin.isNotEmpty) {
        final letter = pinyin[0].toUpperCase();
        if (letter.codeUnitAt(0) >= 65 && letter.codeUnitAt(0) <= 90) {
          return letter;
        }
      }
    } catch (e) {
      // ignore
    }

    return '#';
  }

  /// 按拼音首字母分组排序的辅助比较函数
  static int compareLetter(String a, String b) {
    if (a == '#' && b == '#') return 0;
    if (a == '#') return 1;
    if (b == '#') return -1;
    return a.compareTo(b);
  }
}
