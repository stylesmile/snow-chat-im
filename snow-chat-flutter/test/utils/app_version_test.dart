import 'package:flutter_test/flutter_test.dart';
import 'package:snow_chat/utils/app_version.dart';

/// compareVersions 与 AppVersion 模型的单元测试。
void main() {
  group('compareVersions 版本字符串比较', () {
    test('基础小版本：2.0.9 < 2.1.0', () {
      expect(compareVersions('2.0.9', '2.1.0'), lessThan(0));
    });

    test('主版本：1.x < 2.x', () {
      expect(compareVersions('1.9.9', '2.0.0'), lessThan(0));
    });

    test('跨位数值：2.10 > 2.9（避免字符串坑）', () {
      expect(compareVersions('2.10', '2.9'), greaterThan(0));
      expect(compareVersions('2.9', '2.10'), lessThan(0));
    });

    test('相同版本返回 0', () {
      expect(compareVersions('2.1.0', '2.1.0'), 0);
    });

    test('支持 v 前缀与首字母空格', () {
      expect(compareVersions('v2.1.0', '2.1.0'), 0);
      expect(compareVersions(' 2.2.0 ', 'v2.1.0'), greaterThan(0));
    });

    test('缺失段按 0 补齐，段数不同视为相等当补齐后相同', () {
      expect(compareVersions('2.1', '2.1.0'), 0);
    });

    test('忽略预发布后缀 -beta', () {
      expect(compareVersions('2.1.0-beta', '2.1.0'), 0);
    });

    test('无法解析的段按 0 处理，不抛异常', () {
      expect(compareVersions('abc', '2.0.0'), lessThan(0));
      expect(compareVersions('2.0.a', '2.0.9'), lessThan(0));
    });
  });

  group('AppVersion.fromJson 解析', () {
    test('正常字段解析', () {
      final v = AppVersion.fromJson({
        'version': '2.1.0',
        'downloadUrl': 'https://ex.com/app.apk',
        'updateMessage': '修复若干问题',
        'isNotify': 1,
      });
      expect(v.version, '2.1.0');
      expect(v.downloadUrl, 'https://ex.com/app.apk');
      expect(v.updateMessage, '修复若干问题');
      expect(v.isNotify, isTrue);
      expect(v.shouldNotify, isTrue);
    });

    test('isNotify=0 时 shouldNotify 为 false', () {
      final v = AppVersion.fromJson({
        'version': '2.0.9',
        'downloadUrl': 'https://ex.com/app.apk',
        'isNotify': 0,
      });
      expect(v.isNotify, isFalse);
      expect(v.shouldNotify, isFalse);
    });

    test('downloadUrl 为空时不应提示更新', () {
      final v = AppVersion.fromJson({'version': '2.1.0', 'isNotify': 1});
      expect(v.shouldNotify, isFalse);
    });

    test('缺省字段用空值兜底，不抛异常', () {
      final v = AppVersion.fromJson({});
      expect(v.version, '');
      expect(v.downloadUrl, '');
      expect(v.isNotify, isFalse);
    });
  });

  group('shouldShowUpdate 是否该弹更新提示', () {
    // 构造一个开启了提示且有下载地址的版本
    AppVersion latest(String version) => AppVersion.fromJson({
          'version': version,
          'downloadUrl': 'https://dl.test/app.apk',
          'updateMessage': 'x',
          'isNotify': 1,
        });

    test('服务端版本更新且开启提示时返回 true', () {
      expect(shouldShowUpdate(latest('2.1.0'), '2.0.9'), isTrue);
    });

    test('服务端版本与当前相同则不提示', () {
      expect(shouldShowUpdate(latest('2.0.9'), '2.0.9'), isFalse);
    });

    test('服务端版本低于当前则不提示', () {
      expect(shouldShowUpdate(latest('2.0.8'), '2.0.9'), isFalse);
    });

    test('服务端记录为 null（无更新/请求失败）不提示', () {
      expect(shouldShowUpdate(null, '2.0.9'), isFalse);
    });

    test('未开启提示（isNotify=0）时即使版本更新也不提示', () {
      final off = AppVersion.fromJson({
        'version': '2.1.0',
        'downloadUrl': 'https://dl.test/app.apk',
        'isNotify': 0,
      });
      expect(shouldShowUpdate(off, '2.0.9'), isFalse);
    });

    test('下载地址为空时不提示', () {
      final noUrl = AppVersion.fromJson({'version': '2.1.0', 'isNotify': 1});
      expect(shouldShowUpdate(noUrl, '2.0.9'), isFalse);
    });

    test('当前版本无法解析（空串）时按需更新处理，不崩溃', () {
      // 空串归一化后按 0 处理，2.1.0 比它大 → 判定为需要更新（防御性兜底，正常不会出现）
      expect(shouldShowUpdate(latest('2.1.0'), ''), isTrue);
    });
  });
}