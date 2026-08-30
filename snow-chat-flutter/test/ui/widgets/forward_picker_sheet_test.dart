// ForwardPickerSheet（转发目标选择器）widget 测试
//
// 验证：
// 1. 顶部展示"选择转发对象"标题
// 2. 渲染所有转发目标（名称）
// 3. 点击目标通过 onSelect 回调返回对应 ForwardTarget
// 4. 空列表时不崩溃
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snow_chat/l10n/app_localizations.dart';
import 'package:snow_chat/ui/widgets/forward_picker_sheet.dart';

void main() {
  // 构造测试数据：两个好友目标
  final targets = [
    const ForwardTarget(
      targetId: 11,
      targetType: 'friend',
      displayName: '小明',
    ),
    const ForwardTarget(
      targetId: 22,
      targetType: 'friend',
      displayName: '小红',
    ),
  ];

  Widget wrap(Widget child) {
    return MaterialApp(
      theme: ThemeData(brightness: Brightness.dark),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh'), Locale('en')],
      locale: const Locale('zh'),
      home: Scaffold(body: Center(child: child)),
    );
  }

  group('ForwardPickerSheet 转发目标选择器', () {
    testWidgets('展示标题"选择转发对象"', (tester) async {
      await tester.pumpWidget(wrap(
        ForwardPickerSheet(targets: targets),
      ));
      expect(find.text('选择转发对象'), findsOneWidget);
    });

    testWidgets('渲染所有转发目标名称', (tester) async {
      await tester.pumpWidget(wrap(
        ForwardPickerSheet(targets: targets),
      ));
      expect(find.text('小明'), findsOneWidget);
      expect(find.text('小红'), findsOneWidget);
    });

    testWidgets('点击目标通过 onSelect 回调返回对应 ForwardTarget', (tester) async {
      ForwardTarget? selected;
      await tester.pumpWidget(wrap(
        ForwardPickerSheet(
          targets: targets,
          onSelect: (t) => selected = t,
        ),
      ));
      await tester.tap(find.text('小红'));
      expect(selected, isNotNull);
      expect(selected!.targetId, 22);
      expect(selected!.displayName, '小红');
    });

    testWidgets('空目标列表不崩溃且不渲染列表项', (tester) async {
      await tester.pumpWidget(wrap(
        const ForwardPickerSheet(targets: []),
      ));
      // 仍展示标题
      expect(find.text('选择转发对象'), findsOneWidget);
      // 无目标项
      expect(find.byType(ListTile), findsNothing);
    });
  });
}