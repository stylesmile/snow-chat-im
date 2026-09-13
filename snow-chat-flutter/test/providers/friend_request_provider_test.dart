// 好友申请未读红点的 Provider 单元测试
//
// 背景：通讯录底部导航的"好友申请小红点"此前存在两个问题：
// 1. 未读数 = 全部 pending 请求数，进过「新的朋友」页 markAsRead 清零后，
//    下一次轮询（30s）又把同样的旧请求算成未读 → 红点复活，永远消不掉；
// 2. 已读水位没有按用户持久化，重启 App 后旧申请又全部变成"未读"。
//
// 修复契约（本测试锁定）：
// - 未读数 = id 大于「已读水位 lastSeenMaxId」的请求数（按请求 id 判新，而非全量计数）
// - markAsRead() 把水位推进到当前最大请求 id 并持久化到 SharedPreferences
// - markAsRead() 之后再次 refresh()，旧请求不再计入未读（红点不复活）
// - 只有新到达的请求（id > 水位）才重新点亮红点
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snow_chat/providers/friend_request_provider.dart';
import 'package:snow_chat/services/contact_service.dart';

import '../helpers/mock_api_client.dart';

void main() {
  late MockApiClient apiClient;
  late DioAdapter adapter;
  late FriendRequestProvider provider;

  /// pending 接口的标准响应包装（后端统一 {code, data} 结构）
  Map<String, dynamic> pendingResponse(List<Map<String, dynamic>> requests) =>
      {'code': '200', 'data': requests};

  /// 构造一条 pending 好友请求的 JSON（字段名与后端 DTO 驼峰一致）
  Map<String, dynamic> requestJson(int id, {int fromUserId = 1002}) => {
        'id': id,
        'fromUserId': fromUserId,
        'toUserId': 1001,
        'status': 'pending',
        'remark': '加个好友',
        'fromNickname': '张三',
        'fromAvatar': '',
      };

  /// 注册 pending 接口的 mock 响应（每次调用可注入不同列表）
  void mockPending(List<Map<String, dynamic>> requests) {
    adapter.onGet(
      '/chat/friend/pending',
      (server) => server.reply(200, pendingResponse(requests)),
      queryParameters: {'toUserId': 1001},
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    apiClient = MockApiClient();
    adapter = apiClient.adapter;
    provider = FriendRequestProvider(apiClient);
  });

  group('好友申请未读数（按已读水位判新）', () {
    test('refresh 后未读数等于水位之上的请求数', () async {
      // 两条 pending 请求，水位为 0（从未读过）→ 全部算未读
      mockPending([requestJson(11), requestJson(12)]);
      await provider.bindUser(1001);
      await provider.refresh();

      expect(provider.unreadCount, 2, reason: '从未读过时两条申请都应计入未读');
    });

    test('markAsRead 清零后再次 refresh，旧请求不再复活', () async {
      mockPending([requestJson(11), requestJson(12)]);
      await provider.bindUser(1001);
      await provider.refresh();
      expect(provider.unreadCount, 2);

      // 进过「新的朋友」页 → 红点清零
      provider.markAsRead();
      expect(provider.unreadCount, 0);

      // 关键回归点：轮询再次拉到同样两条旧请求（id 11/12 ≤ 水位 12），
      // 红点必须保持熄灭，而不是像旧实现那样把全量 pending 又算成未读
      await provider.refresh();
      expect(provider.unreadCount, 0, reason: '已读过的请求不应在下次轮询时复活红点');
    });

    test('新请求（id 大于水位）到达后红点重新点亮', () async {
      mockPending([requestJson(11), requestJson(12)]);
      await provider.bindUser(1001);
      await provider.refresh();
      provider.markAsRead();

      // 对方又发来一条新申请，id=15 > 水位 12 → 只有它算未读
      mockPending([requestJson(11), requestJson(12), requestJson(15)]);
      await provider.refresh();

      expect(provider.unreadCount, 1, reason: '只有水位之上的新请求才计入未读');
    });

    test('已读水位按用户持久化到 SharedPreferences，重启后不复活', () async {
      mockPending([requestJson(11), requestJson(12)]);
      await provider.bindUser(1001);
      await provider.refresh();
      provider.markAsRead();

      // 模拟"重启 App"：新建 provider 实例（内存水位丢失），只靠持久化恢复
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('friend_req_seen_max_id_1001'), 12,
          reason: 'markAsRead 应把水位持久化到按用户区分的 key');

      final restarted = FriendRequestProvider(apiClient);
      mockPending([requestJson(11), requestJson(12)]);
      await restarted.bindUser(1001);
      await restarted.refresh();

      expect(restarted.unreadCount, 0, reason: '重启后旧请求不应重新点亮红点');
    });
  });
}
