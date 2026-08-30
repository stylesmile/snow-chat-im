// 消息已读/送达状态解析工具单元测试
//
// 背景：对标唐道道 IM"旗舰模块"的"已读/未读"展示。发送的消息需在气泡旁
// 展示清晰的投递进度：发送中 → 已发送 → 已送达。
// 本测试覆盖状态机映射：由消息的 status（sending/sent/failed）与
// pushStatus（pending/delivered）组合推导出展示用状态。
import 'package:flutter_test/flutter_test.dart';
import 'package:snow_chat/core/utils/message_delivery_state.dart';

void main() {
  group('MessageDeliveryState', () {
    test('status=sending 永远映射为 sending（发送中）', () {
      expect(resolveDeliveryState(status: 'sending', pushStatus: 'pending'),
          MessageDeliveryState.sending);
      expect(resolveDeliveryState(status: 'sending', pushStatus: 'delivered'),
          MessageDeliveryState.sending);
    });

    test('status=failed 映射为 failed（发送失败）', () {
      expect(resolveDeliveryState(status: 'failed', pushStatus: 'pending'),
          MessageDeliveryState.failed);
      expect(resolveDeliveryState(status: 'failed', pushStatus: 'delivered'),
          MessageDeliveryState.failed);
    });

    test('status=sent + pushStatus=delivered 映射为 delivered（已送达/已读）', () {
      expect(resolveDeliveryState(status: 'sent', pushStatus: 'delivered'),
          MessageDeliveryState.delivered);
    });

    test('status=sent + pushStatus=pending 映射为 sent（已发送未送达）', () {
      expect(resolveDeliveryState(status: 'sent', pushStatus: 'pending'),
          MessageDeliveryState.sent);
    });

    test('未知 status 按 已发送 处理（sent）', () {
      expect(resolveDeliveryState(status: 'unknown', pushStatus: 'pending'),
          MessageDeliveryState.sent);
    });
  });
}