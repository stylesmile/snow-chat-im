// EmojiTextEditing 工具测试
//
// 覆盖聊天页表情面板的输入框编辑逻辑：
// 1. 插入表情到光标处（含替换选中内容、选区无效时追加到末尾）
// 2. 退格删一个完整显示字符 —— 变体选择符 / 肤色修饰符 / ZWJ 序列都不能被劈成半个
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snow_chat/core/utils/emoji_text_editing.dart';

/// 构造一个「光标在 [cursor] 处」的输入值（[end] 不同则表示有选中内容）
TextEditingValue valueAt(String text, int cursor, {int? end}) {
  return TextEditingValue(
    text: text,
    selection: TextSelection(baseOffset: cursor, extentOffset: end ?? cursor),
  );
}

void main() {
  group('EmojiTextEditing.insertAtCursor', () {
    test('光标为空文本时插入，光标落在表情之后', () {
      final result = EmojiTextEditing.insertAtCursor(valueAt('', 0), '😀');
      expect(result.text, '😀');
      expect(result.selection.baseOffset, '😀'.length);
    });

    test('插入到光标位置而不是末尾', () {
      // 文本 "ab"，光标在中间 → 变成 "a😀b"
      final result = EmojiTextEditing.insertAtCursor(valueAt('ab', 1), '😀');
      expect(result.text, 'a😀b');
      expect(result.selection.baseOffset, 1 + '😀'.length);
    });

    test('有选中内容时替换掉选中部分', () {
      // 选中 "bc" 后输入表情 → "a😀d"
      final result = EmojiTextEditing.insertAtCursor(valueAt('abcd', 1, end: 3), '😀');
      expect(result.text, 'a😀d');
      expect(result.selection.baseOffset, 1 + '😀'.length);
    });

    test('选区无效（未聚焦过）时追加到末尾', () {
      const invalid = TextEditingValue(
        text: '你好',
        selection: TextSelection.collapsed(offset: -1),
      );
      final result = EmojiTextEditing.insertAtCursor(invalid, '😀');
      expect(result.text, '你好😀');
    });

    test('插入会清掉输入法组合态', () {
      const composing = TextEditingValue(
        text: 'nihao',
        selection: TextSelection.collapsed(offset: 5),
        composing: TextRange(start: 0, end: 5),
      );
      final result = EmojiTextEditing.insertAtCursor(composing, '😀');
      expect(result.composing, TextRange.empty);
    });
  });

  group('EmojiTextEditing.deleteBackward', () {
    test('空文本时原样返回', () {
      final value = valueAt('', 0);
      expect(EmojiTextEditing.deleteBackward(value), value);
    });

    test('光标在开头且无选中时原样返回', () {
      final value = valueAt('abc', 0);
      expect(EmojiTextEditing.deleteBackward(value), value);
    });

    test('删除普通字符', () {
      final result = EmojiTextEditing.deleteBackward(valueAt('abc', 3));
      expect(result.text, 'ab');
      expect(result.selection.baseOffset, 2);
    });

    test('删除代理对表情时整块删掉（不残留半个字符）', () {
      // '😀' = U+1F600，UTF-16 占 2 个 code unit
      const text = 'a😀';
      expect(text.length, 3);
      final result = EmojiTextEditing.deleteBackward(valueAt(text, text.length));
      expect(result.text, 'a');
      expect(result.selection.baseOffset, 1);
    });

    test('带变体选择符的 ☹️ 一起删掉', () {
      // '☹️' = U+2639 + U+FE0F，共 2 个 code unit
      const emoji = '☹️';
      const text = 'a$emoji';
      expect(text.length, 3);
      final result = EmojiTextEditing.deleteBackward(valueAt(text, text.length));
      expect(result.text, 'a');
    });

    test('带肤色修饰符的 👍🏽 一起删掉', () {
      // '👍🏽' = U+1F44D + U+1F3FD，共 4 个 code unit
      const emoji = '👍🏽';
      const text = 'hi$emoji';
      expect(text.length, 6);
      final result = EmojiTextEditing.deleteBackward(valueAt(text, text.length));
      expect(result.text, 'hi');
    });

    test('ZWJ 序列（👨‍👩‍👧）整串删掉', () {
      const family = '👨‍👩‍👧';
      const text = '家$family';
      final result = EmojiTextEditing.deleteBackward(valueAt(text, text.length));
      expect(result.text, '家');
    });

    test('有选中内容时先删选中内容', () {
      final result = EmojiTextEditing.deleteBackward(valueAt('abcd', 1, end: 3));
      expect(result.text, 'ad');
      expect(result.selection.baseOffset, 1);
    });

    test('连续退格能逐字删空且不报错', () {
      const text = 'a😀☹️👍🏽';
      var value = valueAt(text, text.length);
      for (var i = 0; i < 4; i++) {
        value = EmojiTextEditing.deleteBackward(value);
      }
      expect(value.text, '');
      expect(value.selection.baseOffset, 0);
      // 再删一次不应抛异常
      expect(EmojiTextEditing.deleteBackward(value).text, '');
    });

    test('选区越界（文本被改短）时不抛异常', () {
      const stale = TextEditingValue(
        text: 'ab',
        selection: TextSelection.collapsed(offset: 99),
      );
      expect(() => EmojiTextEditing.deleteBackward(stale), returnsNormally);
      expect(EmojiTextEditing.deleteBackward(stale).text, 'a');
    });
  });

  group('EmojiTextEditing.prevGraphemeStart', () {
    test('普通 ASCII 往前一格', () {
      expect(EmojiTextEditing.prevGraphemeStart('abc', 3), 2);
    });

    test('索引为 0 时返回 0', () {
      expect(EmojiTextEditing.prevGraphemeStart('abc', 0), 0);
    });

    test('代理对返回起始下标', () {
      expect(EmojiTextEditing.prevGraphemeStart('a😀', 3), 1);
    });

    test('零宽连接符序列返回序列开头', () {
      const family = '👨‍👩‍👧';
      const text = 'x$family';
      expect(EmojiTextEditing.prevGraphemeStart(text, text.length), 1);
    });
  });
}
