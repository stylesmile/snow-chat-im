import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// AndroidManifest 媒体权限声明测试。
///
/// 背景：安卓发送视频时 wechat_assets_picker（photo_manager）弹出
/// 「无法访问所有资源」拦截页，根因是 Manifest 缺少视频读取权限与
/// Android 14 部分访问权限声明。本测试锁定 Manifest 必须包含：
/// - READ_MEDIA_IMAGES：Android 13+ 读取图片；
/// - READ_MEDIA_VIDEO：Android 13+ 读取视频（缺失时选视频被系统拦截）；
/// - READ_MEDIA_VISUAL_USER_SELECTED：Android 14+「仅允许部分资源」
///   场景下再次申请追加访问的权限，缺失时 photo_manager 无法引导
///   用户升级授权，只能弹「前往系统设置」拦截页。
void main() {
  // Manifest 文件相对项目根目录的固定路径
  const manifestPath = 'android/app/src/main/AndroidManifest.xml';

  // 读取 Manifest 内容，供各用例断言
  late String manifest;

  setUpAll(() {
    // 测试在包根目录（snow-chat-flutter）下运行，直接读相对路径
    final file = File(manifestPath);
    // Manifest 必须存在，否则说明工程结构被破坏
    expect(file.existsSync(), isTrue,
        reason: '未找到 $manifestPath，无法校验权限声明');
    manifest = file.readAsStringSync();
  });

  test('应声明 READ_MEDIA_IMAGES 以支持 Android 13+ 读取图片', () {
    // 图片选择是既有功能，防止回归
    expect(manifest, contains('android.permission.READ_MEDIA_IMAGES'));
  });

  test('应声明 READ_MEDIA_VIDEO 以支持 Android 13+ 读取视频', () {
    // 缺失该权限时，选择视频会被系统/photo_manager 拦截，
    // 表现为「无法访问所有资源」页面，视频无法发送
    expect(manifest, contains('android.permission.READ_MEDIA_VIDEO'));
  });

  test('应声明 READ_MEDIA_VISUAL_USER_SELECTED 以支持 Android 14 部分访问', () {
    // 用户选择「仅允许部分资源」后，photo_manager 需要该权限
    // 才能在应用内引导追加授权，而不是弹系统设置拦截页
    expect(manifest,
        contains('android.permission.READ_MEDIA_VISUAL_USER_SELECTED'));
  });

  test('旧版存储权限应限制 maxSdkVersion 32 以内', () {
    // READ_EXTERNAL_STORAGE 在 Android 13+ 已被细分权限取代，
    // 必须带 maxSdkVersion="32"，避免在高版本申请废弃权限
    final legacy = RegExp(
        r'android\.permission\.READ_EXTERNAL_STORAGE[^>]*android:maxSdkVersion="32"');
    expect(legacy.hasMatch(manifest), isTrue,
        reason: 'READ_EXTERNAL_STORAGE 必须限制 maxSdkVersion=32');
  });
}
