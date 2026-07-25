import 'package:flutter_test/flutter_test.dart';
import 'package:snow_chat/core/constants/ws_cmd.dart';

/// ws_cmd.dart 与后端 WsCmd.java 对齐校验测试
///
/// 此测试是前后端 MQTT 命令码的"契约守卫"：
/// - 将后端 WsCmd.java 中的常量值硬编码为期望值（canonical contract）
/// - 断言 Flutter 端 ws_cmd.dart 的每个常量与后端一致
/// - 任一端修改命令码而不同步另一端时，此测试会失败
///
/// 维护规则：
/// 1. 后端 WsCmd.java 新增/修改常量时，必须同步更新 ws_cmd.dart 和此测试
/// 2. 此测试中的 expected 值是后端 WsCmd.java 的"真实值"，不是随意数字
void main() {
  group('WsCmd 前后端对齐校验', () {
    // ==================================================================
    // Client → Server (1001-1099)：客户端发往服务端的命令码
    // 与后端 WsCmd.java 的 Client → Server 区段一一对应
    // ==================================================================
    group('Client → Server (1001-1099)', () {
      test('login 应与后端 LOGIN=1001 一致', () {
        expect(WsCmd.login, equals(1001));
      });

      test('msgText 应与后端 MSG_TEXT=1002 一致', () {
        expect(WsCmd.msgText, equals(1002));
      });

      test('msgImage 应与后端 MSG_IMAGE=1003 一致', () {
        expect(WsCmd.msgImage, equals(1003));
      });

      test('msgVideo 应与后端 MSG_VIDEO=1004 一致', () {
        expect(WsCmd.msgVideo, equals(1004));
      });

      test('friendAddReq 应与后端 FRIEND_ADD_REQ=1006 一致', () {
        expect(WsCmd.friendAddReq, equals(1006));
      });

      test('groupCreate 应与后端 GROUP_CREATE=1009 一致', () {
        expect(WsCmd.groupCreate, equals(1009));
      });

      test('readAck 应与后端 READ_ACK=1012 一致', () {
        expect(WsCmd.readAck, equals(1012));
      });

      test('msgReceipt 应与后端 MSG_RECEIPT=1013 一致', () {
        // 接收方确认收到消息（Client→Server）
        expect(WsCmd.msgReceipt, equals(1013));
      });

      test('fetchUndelivered 应与后端 FETCH_UNDELIVERED=1014 一致', () {
        // 进入聊天页面时请求未推送消息（Client→Server）
        expect(WsCmd.fetchUndelivered, equals(1014));
      });
    });

    // ==================================================================
    // Server → Client (2001-2099)：服务端发往客户端的命令码
    // 与后端 WsCmd.java 的 Server → Client 区段一一对应
    // ==================================================================
    group('Server → Client (2001-2099)', () {
      test('msgPush 应与后端 MSG_PUSH=2001 一致', () {
        expect(WsCmd.msgPush, equals(2001));
      });

      test('friendReqNotify 应与后端 FRIEND_REQ_NOTIFY=2002 一致', () {
        expect(WsCmd.friendReqNotify, equals(2002));
      });

      test('onlineStatus 应与后端 ONLINE_STATUS=2003 一致', () {
        expect(WsCmd.onlineStatus, equals(2003));
      });

      test('groupNotify 应与后端 GROUP_NOTIFY=2004 一致', () {
        expect(WsCmd.groupNotify, equals(2004));
      });

      test('msgAck 应与后端 MSG_ACK=2005 一致', () {
        expect(WsCmd.msgAck, equals(2005));
      });

      test('friendAccepted 应与后端 FRIEND_ACCEPTED=2006 一致', () {
        expect(WsCmd.friendAccepted, equals(2006));
      });

      test('msgReceiptAck 应与后端 MSG_RECEIPT_ACK=2007 一致', () {
        // 服务器回执给发送方确认已收到并推送（Server→Client）
        expect(WsCmd.msgReceiptAck, equals(2007));
      });

      test('fetchUndeliveredAck 应与后端 FETCH_UNDELIVERED_ACK=2008 一致', () {
        // 服务器推送未推送成功的消息列表（Server→Client）
        expect(WsCmd.fetchUndeliveredAck, equals(2008));
      });
    });

    // ==================================================================
    // 完整性校验：确保两端命令码集合无遗漏
    // 后端 WsCmd.java 当前共 17 个常量（9 个 C→S + 8 个 S→C）
    // 如果后端新增常量，需在此测试和 ws_cmd.dart 中同步添加
    // ==================================================================
    test('命令码范围校验：C→S 在 1001-1099，S→C 在 2001-2099', () {
      // Client → Server 命令码应全部落在 1001-1099 范围内
      const clientCmds = [
        WsCmd.login,
        WsCmd.msgText,
        WsCmd.msgImage,
        WsCmd.msgVideo,
        WsCmd.friendAddReq,
        WsCmd.groupCreate,
        WsCmd.readAck,
        WsCmd.msgReceipt,
        WsCmd.fetchUndelivered,
      ];
      for (final cmd in clientCmds) {
        expect(cmd, greaterThanOrEqualTo(1001), reason: 'C→S 命令码应 >= 1001');
        expect(cmd, lessThanOrEqualTo(1099), reason: 'C→S 命令码应 <= 1099');
      }

      // Server → Client 命令码应全部落在 2001-2099 范围内
      const serverCmds = [
        WsCmd.msgPush,
        WsCmd.friendReqNotify,
        WsCmd.onlineStatus,
        WsCmd.groupNotify,
        WsCmd.msgAck,
        WsCmd.friendAccepted,
        WsCmd.msgReceiptAck,
        WsCmd.fetchUndeliveredAck,
      ];
      for (final cmd in serverCmds) {
        expect(cmd, greaterThanOrEqualTo(2001), reason: 'S→C 命令码应 >= 2001');
        expect(cmd, lessThanOrEqualTo(2099), reason: 'S→C 命令码应 <= 2099');
      }
    });

    test('命令码唯一性校验：所有命令码互不重复', () {
      // 收集所有命令码，确保无重复（重复会导致 MQTT 消息路由歧义）
      const allCmds = [
        // Client → Server
        WsCmd.login,
        WsCmd.msgText,
        WsCmd.msgImage,
        WsCmd.msgVideo,
        WsCmd.friendAddReq,
        WsCmd.groupCreate,
        WsCmd.readAck,
        WsCmd.msgReceipt,
        WsCmd.fetchUndelivered,
        // Server → Client
        WsCmd.msgPush,
        WsCmd.friendReqNotify,
        WsCmd.onlineStatus,
        WsCmd.groupNotify,
        WsCmd.msgAck,
        WsCmd.friendAccepted,
        WsCmd.msgReceiptAck,
        WsCmd.fetchUndeliveredAck,
      ];
      // 转为 Set 后长度应与原列表一致，说明无重复
      expect(allCmds.toSet().length, equals(allCmds.length),
          reason: '所有命令码必须唯一');
    });
  });
}
