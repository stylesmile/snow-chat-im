// 消息送达状态图标组件测试
//
// 背景：对标唐道道 IM"旗舰模块"的"已读/未读"展示。
// 我是个可复用的图标组件，根据 MessageDeliveryState 渲染对应的状态图标
// （发送中转圈 / 失败感叹号 / 已发送单勾 / 已送达双勾），
// 并支持 Flutter 主题下的语义 color 覆盖。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snow_chat/core/utils/message_delivery_state.dart';
import 'package:snow_chat/ui/widgets/message_delivery_status.dart';

void main() {
  Widget wrap(MessageDeliveryState state) {
    return MaterialApp(home: Scaffold(body: Center(child: MessageDeliveryStatus(state: state))));
  }

  testWidgets('sending：渲染加载转圈图标', (tester) async {
    await tester.pumpWidget(wrap(MessageDeliveryState.sending));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('failed：渲染错误感叹号图标', (tester) async {
    await tester.pumpWidget(wrap(MessageDeliveryState.failed));
    expect(find.byIcon(Icons.error_rounded), findsOneWidget);
  });

  testWidgets('sent：渲染单勾图标（已发送）', (tester) async {
    await tester.pumpWidget(wrap(MessageDeliveryState.sent));
    expect(find.byIcon(Icons.done), findsOneWidget);
  });

  testWidgets('delivered：渲染双勾图标（已送达/已读）', (tester) async {
    await tester.pumpWidget(wrap(MessageDeliveryState.delivered));
    expect(find.byIcon(Icons.done_all), findsOneWidget);
  });
}