import 'package:flutter/widgets.dart';

/// 输入框里的表情文本编辑。
///
/// 从聊天页表情面板里抽出来的纯逻辑：那里要在光标处插入表情、按删除键退格，
/// 都要按「显示字符」（grapheme cluster）而不是 UTF-16 code unit 处理 ——
/// emoji 常常由多个码点组成（`☹️` = 基字符 + 变体选择符，`👍🏽` = 手势 + 肤色修饰符，
/// `👨‍👩‍👧` 中间还夹着零宽连接符 U+200D），按长度退格会把它劈成半个、显示成乱码。
///
/// 抽成静态方法是为了能直接单测（原来埋在 `_State` 私有方法里，只能靠 widget 测试覆盖）。
class EmojiTextEditing {
  const EmojiTextEditing._();

  /// 在光标处插入 [text]（有选中内容时先替换掉选中部分），光标落在插入内容之后
  static TextEditingValue insertAtCursor(TextEditingValue value, String text) {
    final range = _selectionRange(value);
    return value.copyWith(
      text: value.text.replaceRange(range.$1, range.$2, text),
      selection: TextSelection.collapsed(offset: range.$1 + text.length),
      composing: TextRange.empty,
    );
  }

  /// 删除光标前一个显示字符（有选中内容时先删选中内容）
  ///
  /// 光标已在开头且无选中时返回原值。
  static TextEditingValue deleteBackward(TextEditingValue value) {
    final source = value.text;
    if (source.isEmpty) return value;

    var start = _selectionRange(value).$1;
    var end = _selectionRange(value).$2;
    if (start == end) {
      if (start == 0) return value;
      start = prevGraphemeStart(source, start);
    }

    return value.copyWith(
      text: source.replaceRange(start, end, ''),
      selection: TextSelection.collapsed(offset: start),
      composing: TextRange.empty,
    );
  }

  /// 求 [index] 之前一个完整显示字符的起始下标
  ///
  /// 处理三种情况：尾部的修饰码点（变体选择符 / 肤色修饰符 / 键帽 / 零宽连接符）、
  /// 代理对（emoji 基本都在 BMP 之外，UTF-16 占两个 code unit）、
  /// 以及 `零宽连接符 + 码点` 组成的 ZWJ 序列（要一直吞到序列开头）。
  static int prevGraphemeStart(String text, int index) {
    var i = index;
    while (true) {
      // 1) 跳过尾部修饰码点
      while (i > 0) {
        final cp = text.codeUnitAt(i - 1);
        if (cp == 0xFE0F || cp == 0xFE0E || cp == 0x200D || cp == 0x20E3) {
          i--;
        } else if (cp >= 0xDFFB && cp <= 0xDFFF) {
          // 肤色修饰符（U+1F3FB..U+1F3FF）在 UTF-16 里的低位代理
          i -= 2;
        } else {
          break;
        }
      }
      if (i <= 0) return 0;

      // 2) 吃掉一个完整码点
      final cu = text.codeUnitAt(i - 1);
      i -= (cu >= 0xDC00 && cu <= 0xDFFF) ? 2 : 1;
      if (i < 0) return 0;

      // 3) 前方紧跟零宽连接符 → 属于同一个 ZWJ 序列，继续往前吞
      if (i > 0 && text.codeUnitAt(i - 1) == 0x200D) {
        i--;
        continue;
      }
      return i;
    }
  }

  /// 取选区范围；选区无效（如输入框从未聚焦，offset 为 -1）时退化为「文末」
  static (int, int) _selectionRange(TextEditingValue value) {
    final length = value.text.length;
    if (!value.selection.isValid) return (length, length);

    var start = value.selection.start;
    var end = value.selection.end;
    if (start < 0 || end < 0) return (length, length);
    if (start > end) {
      final tmp = start;
      start = end;
      end = tmp;
    }
    // 越界保护：text 被外部改短后旧 selection 可能超出范围
    if (start > length) start = length;
    if (end > length) end = length;
    return (start, end);
  }
}
