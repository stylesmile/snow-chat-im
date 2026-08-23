import '../core/network/api_client.dart';
import '../models/message_model.dart';

class ChatService {
  final ApiClient apiClient;

  ChatService(this.apiClient);

  /// 获取历史消息（分页）
  Future<List<MessageModel>> getHistory({
    required int userId,
    required int targetId,
    String targetType = 'friend',
    int page = 1,
    int size = 50,
  }) async {
    try {
      final response = await apiClient.dio.get(
        '/chat/message/history',
        queryParameters: {
          'userId': userId,
          'targetId': targetId,
          'targetType': targetType,
          'page': page,
          'size': size,
        },
      );
      final data = response.data['data'] as List?;
      return data?.map((e) => MessageModel.fromJson(e)).toList() ?? [];
    } catch (e) {
      return [];
    }
  }

  /// 获取历史消息（游标分页，用于滚动加载更多）
  Future<List<MessageModel>> getHistoryByCursor({
    required int userId,
    required int targetId,
    String targetType = 'friend',
    int? beforeMessageId,
    int size = 20,
  }) async {
    try {
      final response = await apiClient.dio.get(
        '/chat/message/history/cursor',
        queryParameters: {
          'userId': userId,
          'targetId': targetId,
          'targetType': targetType,
          if (beforeMessageId != null) 'beforeMessageId': beforeMessageId,
          'size': size,
        },
      );
      final data = response.data['data'] as List?;
      return data?.map((e) => MessageModel.fromJson(e)).toList() ?? [];
    } catch (e) {
      return [];
    }
  }

  /// 发送消息（REST fallback）
  Future<bool> sendMessage(MessageModel message) async {
    try {
      await apiClient.dio.post('/chat/message/send', data: message.toJson());
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 发送文件传输助手消息（发送给自己，接收人=自己）
  ///
  /// 文件传输助手本质是"发给自己的消息"，走独立接口 /send/file-helper，
  /// 后端会强制把接收人设为自己、并把消息类型标记为 self，
  /// 从而把消息同步到本人的其他登录端。
  ///
  /// @param message 待发送的消息（含发送人、内容等）
  /// @return 是否发送成功
  Future<bool> sendFileHelper(MessageModel message) async {
    try {
      await apiClient.dio.post(
        '/chat/message/send/file-helper',
        data: message.toJson(),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 撤回消息
  Future<bool> recallMessage(int userId, int messageId) async {
    try {
      await apiClient.dio.post(
        '/chat/message/recall',
        data: {'userId': userId, 'messageId': messageId},
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 标记消息为已读
  Future<bool> markAsRead(int userId, int targetId, String targetType) async {
    try {
      await apiClient.dio.post(
        '/chat/message/read',
        data: {'userId': userId, 'targetId': targetId, 'targetType': targetType},
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 发送消息回执：接收方确认收到消息
  Future<bool> sendReceipt(int messageId, int userId, int targetId, String targetType) async {
    try {
      await apiClient.dio.post(
        '/chat/message/receipt',
        data: {
          'messageId': messageId,
          'userId': userId,
          'targetId': targetId,
          'targetType': targetType,
        },
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 请求服务器推送未推送成功的消息
  /// 返回未送达消息列表，由客户端主动拉取并写入本地 SQLite
  Future<List<MessageModel>> fetchUndelivered(int userId, int targetId, String targetType) async {
    try {
      final response = await apiClient.dio.post(
        '/chat/message/undelivered',
        data: {
          'userId': userId,
          'targetId': targetId,
          'targetType': targetType,
        },
      );
      final data = response.data['data'] as List?;
      return data?.map((e) => MessageModel.fromJson(e)).toList() ?? [];
    } catch (e) {
      return [];
    }
  }

  /// MQTT 重连后请求服务器补推未送达消息
  /// 与 [fetchUndelivered] 区别：本接口由服务器通过 MQTT 主动推送（FETCH_UNDELIVERED_ACK），
  /// 而非返回列表由客户端拉取。适用于 MQTT 重连场景，客户端通知服务器"我回来了，把漏掉的消息推给我"。
  Future<bool> syncUndelivered(int userId, int targetId, String targetType) async {
    try {
      // POST /chat/message/sync：服务器收到后查询未送达消息并通过 MQTT 推送
      await apiClient.dio.post(
        '/chat/message/sync',
        data: {
          'userId': userId,         // 当前用户 ID
          'targetId': targetId,     // 对端用户 ID（私聊）或群组 ID
          'targetType': targetType, // 会话类型：friend=私聊 / group=群聊
        },
      );
      return true; // 请求成功，未送达消息将由 MQTT 推送
    } catch (e) {
      return false; // 请求失败，下次重连会再次尝试
    }
  }

  /// MQTT 重连后批量请求所有会话补推未送达消息
  ///
  /// 遍历当前用户的所有会话，对每个会话调用 [syncUndelivered]。
  /// 适用于 MQTT 自动重连成功后，客户端通知服务器"我回来了，把漏掉的消息推给我"。
  ///
  /// 使用 record 类型 `({int targetId, String targetType})` 解耦服务层与 provider 层，
  /// 避免 ChatService 依赖 chat_provider.dart 的 Conversation 类。
  ///
  /// 单个会话请求失败不影响其他会话（syncUndelivered 内部已吞掉异常）。
  Future<void> syncAllConversations(
    int userId,
    List<({int targetId, String targetType})> conversations,
  ) async {
    // 遍历所有会话，逐个请求服务器补推未送达消息
    for (final conv in conversations) {
      // 对每个会话调用 syncUndelivered，失败时内部返回 false，不影响后续会话
      await syncUndelivered(userId, conv.targetId, conv.targetType);
    }
  }
}
