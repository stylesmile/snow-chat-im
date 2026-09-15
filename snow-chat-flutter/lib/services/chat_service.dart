import 'dart:io';
import 'package:dio/dio.dart';
import '../core/network/api_client.dart';
import '../models/message_model.dart';
import '../models/upload_result.dart';

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

  /// 上传媒体/附件文件到对象存储（images/、videos/、files/、voices/ 子目录）
  ///
  /// 对应后端 `POST /file/media/{type}` 端点：
  /// - [type] 必须是 "image" / "video" / "file" / "voice" 之一，与后端白名单一致；
  /// - 返回上传后的 URL（pre-signed URL 或 base64 data URL），可直接用于消息 content；
  /// - 调用方负责用返回的 URL 作为 [MessageModel.content]，type 字段设为对应值。
  ///
  /// @param file 本地媒体文件（图片/视频/文档/音频）
  /// @param type 媒体类型，映射到后端目录前缀：
  ///   image→images/、video→videos/、file→files/、voice→voices/
  /// @return 上传成功返回 UploadResult（含 key 与 url）；失败返回 null
  Future<UploadResult?> uploadMedia(File file, String type) async {
    try {
      // 读取文件字节并构造 multipart 表单
      final bytes = await file.readAsBytes();
      // 文件名取原始路径末段，便于后端保留扩展名生成对象 key
      final fileName = file.path.split('/').last;
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: fileName),
      });
      // 发送到独立媒体上传端点；必须显式设置 contentType 覆盖全局 application/json
      final response = await apiClient.dio.post(
        '/file/media/$type',
        data: formData,
        options: Options(contentType: Headers.multipartFormDataContentType),
      );
      // 解析响应：{code: '200', data: {key, url}}
      final data = response.data['data'] as Map<String, dynamic>?;
      if (data == null) {
        return null;
      }
      return UploadResult.fromJson(data);
    } catch (e) {
      // 输出详细错误信息，便于排查上传失败原因
      print('[ChatService] uploadMedia failed: $e');
      return null;
    }
  }
}
