// DateUtils 单元测试
// 覆盖三种显示格式：今天（仅时分）、同年不同日、跨年；
// 相对时间：刚刚、分钟前、小时前；昨天/更早
import 'package:flutter_test/flutter_test.dart';
import 'package:snow_chat/core/utils/date_utils.dart';

void main() {
  /// 把当前墙钟时间挪到 [offsetMinutes] 分钟前，返回对应的毫秒时间戳
  int stampOffsetMinutes(int offsetMinutes) {
    return DateTime.now()
        .subtract(Duration(minutes: offsetMinutes))
        .millisecondsSinceEpoch;
  }

  group('DateUtils.formatTime', () {
    test('null 输入返回空字符串', () {
      expect(DateUtils.formatTime(null), equals(''));
    });

    test('当天时间只显示时分', () {
      final stamp = stampOffsetMinutes(5);
      final result = DateUtils.formatTime(stamp);
      // 结果形如 "HH:mm"，应匹配两位小时+冒号+两位分钟
      expect(result, matches(r'^\d{2}:\d{2}$'));
    });

    test('当年但不同日期会显示月日时分', () {
      // 一年前的今天，月份/日期均不同
      final stamp = DateTime.now()
          .subtract(const Duration(days: 365))
          .millisecondsSinceEpoch;
      final result = DateUtils.formatTime(stamp);
      expect(result, matches(r'^\d{2}-\d{2} \d{2}:\d{2}$'));
    });

    test('跨年显示年-月-日 时分', () {
      // 故意构造一个明年日期（靠偏移）
      final stamp = DateTime.now()
          .add(const Duration(days: 365))
          .millisecondsSinceEpoch;
      final result = DateUtils.formatTime(stamp);
      expect(result, matches(r'^\d{2}-\d{2}-\d{2} \d{2}:\d{2}$'));
    });
  });

  group('DateUtils.formatDate', () {
    test('null 输入返回空字符串', () {
      expect(DateUtils.formatDate(null), equals(''));
    });

    test('今天显示“今天”', () {
      expect(DateUtils.formatDate(stampOffsetMinutes(30)), equals('今天'));
    });

    test('昨天显示“昨天”', () {
      expect(DateUtils.formatDate(stampOffsetMinutes(60 * 24 - 1)), equals('昨天'));
    });

    test('更早日期显示完整日期', () {
      final stamp = DateTime.now()
          .subtract(const Duration(days: 2))
          .millisecondsSinceEpoch;
      expect(DateUtils.formatDate(stamp), matches(r'^\d{4}-\d{2}-\d{2}$'));
    });
  });

  group('DateUtils.formatRelative', () {
    test('null 输入返回空字符串', () {
      expect(DateUtils.formatRelative(null), equals(''));
    });

    test('1 分钟内显示“刚刚”', () {
      expect(DateUtils.formatRelative(stampOffsetMinutes(0)), equals('刚刚'));
      expect(DateUtils.formatRelative(stampOffsetMinutes(59)), equals('刚刚'));
    });

    test('X 分钟前在 1~59 分钟区间内显示正确分钟数', () {
      const minutes = 7;
      expect(DateUtils.formatRelative(stampOffsetMinutes(minutes)),
          equals('$minutes分钟前'));
    });

    test('X 小时前在 1~23 小时区间内显示正确小时数', () {
      const hours = 3;
      expect(DateUtils.formatRelative(stampOffsetMinutes(hours * 60)),
          equals('$hours小时前'));
    });

    test('超过 24 小时走 formatDate 逻辑', () {
      final stamp = DateTime.now()
          .subtract(const Duration(days: 5))
          .millisecondsSinceEpoch;
      expect(DateUtils.formatRelative(stamp),
          equals(DateUtils.formatDate(stamp)));
    });
  });
}
