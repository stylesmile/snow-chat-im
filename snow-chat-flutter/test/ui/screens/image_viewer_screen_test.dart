import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snow_chat/ui/screens/image_viewer_screen.dart';

void main() {
  // 一个 1x1 透明 PNG 的 base64，用于构造合法的 data-URI 图片
  const kBase64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';
  final kExpectedBytes = base64Decode(kBase64);
  final kDataUri = 'data:image/png;base64,$kBase64';

  group('ImageViewerScreen 渲染', () {
    testWidgets('base64 图片可正常渲染（不触发网络）', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: ImageViewerScreen(content: kDataUri)),
      );
      await tester.pump();

      // 应有保存按钮与支持缩放的图片查看器
      expect(find.byIcon(Icons.download_outlined), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
    });
  });

  group('ImageViewerScreen 保存到相册', () {
    testWidgets('保存成功时调用保存函数并提示"已保存到相册"', (tester) async {
      // 记录保存函数收到的字节，便于验证解码正确性
      final saved = <Uint8List>[];
      Future<bool> fakeSaver(Uint8List bytes) async {
        saved.add(bytes);
        return true;
      }

      await tester.pumpWidget(
        MaterialApp(home: ImageViewerScreen(content: kDataUri, saver: fakeSaver)),
      );
      await tester.pump();

      // 点击保存按钮
      await tester.tap(find.byIcon(Icons.download_outlined));
      await tester.pumpAndSettle();

      // 保存函数收到与图片一致的字节，并弹出成功提示
      expect(saved.length, 1);
      expect(saved.first, kExpectedBytes);
      expect(find.text('已保存到相册'), findsOneWidget);
    });

    testWidgets('保存失败时提示"保存失败"', (tester) async {
      // 保存函数返回 false，应展示失败提示
      Future<bool> failingSaver(Uint8List bytes) async => false;

      await tester.pumpWidget(
        MaterialApp(home: ImageViewerScreen(content: kDataUri, saver: failingSaver)),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.download_outlined));
      await tester.pumpAndSettle();

      expect(find.text('保存失败'), findsOneWidget);
    });
  });
}