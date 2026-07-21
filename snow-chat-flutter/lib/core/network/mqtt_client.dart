import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

/// MQTT 消息回调签名
typedef MessageCallback = void Function(int cmd, dynamic data);

/// MQTT 聊天客户端
class MqttChatClient {
  MqttServerClient? _client;
  final String host;
  final int port;
  final MessageCallback? onMessage;
  final VoidCallback? onConnected;
  final VoidCallback? onDisconnected;

  MqttChatClient({
    required this.host,
    this.port = 1883,
    this.onMessage,
    this.onConnected,
    this.onDisconnected,
  });

  bool get isConnected => _client?.connectionStatus?.state == MqttConnectionState.connected;

  Future<void> connect({
    required int userId,
    String? username,
    String? password,
    String? clientId,
  }) async {
    final effectiveClientId = clientId ?? 'user_$userId';
    final client = MqttServerClient.withPort(host, effectiveClientId, port);
    client.logging(on: false);
    client.keepAlivePeriod = 30;
    client.autoReconnect = true;
    client.resubscribeOnAutoReconnect = true;
    client.onConnected = onConnected;
    client.onDisconnected = onDisconnected;
    client.onAutoReconnect = () {};
    client.onAutoReconnected = () => _subscribeAll(userId);
    client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(effectiveClientId)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    _client = client;
    try {
      await client.connect(username, password);
      if (isConnected) {
        // 连接成功日志：输出 host、port、clientId，便于排查连接问题
        debugPrint('[MQTT] connected to $host:$port as $effectiveClientId');
        // 订阅当前用户的私聊主题
        _subscribeAll(userId);
        // 监听消息流；updates 可能为 null（连接异常时），需明确检测
        final updates = client.updates;
        if (updates == null) {
          // 关键错误：updates 为 null 表示消息流未建立，消息将无法收到
          debugPrint('[MQTT] WARNING: client.updates is null, messages will NOT be received!');
        } else {
          updates.listen(_handleMessages);
          debugPrint('[MQTT] listening for messages on updates stream');
        }
      } else {
        // 连接返回但状态非 connected，输出实际状态用于诊断
        debugPrint('[MQTT] connect returned but state=${client.connectionStatus?.state}');
      }
    } catch (e, st) {
      // 连接异常：输出错误和堆栈
      debugPrint('[MQTT] connect failed: $e\n$st');
      client.disconnect();
      _client = null;
      onDisconnected?.call();
    }
  }

  /// 订阅所有主题（用户 + 已加入的群）
  void _subscribeAll(int userId) {
    _client?.subscribe('chat/user/$userId', MqttQos.atLeastOnce);
    debugPrint('[MQTT] subscribed chat/user/$userId');
    // 群主题由 subscribeGroup 单独管理
  }

  /// 订阅群主题
  void subscribeGroup(int groupId) {
    if (!isConnected) {
      debugPrint('[MQTT] subscribeGroup($groupId) SKIPPED: state=${_client?.connectionStatus?.state}');
      return;
    }
    _client?.subscribe('chat/group/$groupId', MqttQos.atLeastOnce);
    debugPrint('[MQTT] subscribeGroup($groupId) OK');
  }

  /// 取消订阅群主题
  void unsubscribeGroup(int groupId) {
    _client?.unsubscribe('chat/group/$groupId');
  }

  void _handleMessages(List<MqttReceivedMessage<MqttMessage>> messages) {
    // 收到 broker 推送的消息列表，逐条处理
    for (final received in messages) {
      // 将 payload 转为 MqttPublishMessage 并用 UTF-8 解码（修复中文乱码）
      // bytesToStringAsString 默认用 latin1 解码，中文会乱码
      final publish = received.payload as MqttPublishMessage;
      final text = utf8.decode(publish.payload.message);
      // 接收日志：打印主题和消息内容前 200 字符，便于追踪消息流向
      final preview = text.length > 200 ? '${text.substring(0, 200)}...' : text;
      debugPrint('[MQTT] received on ${received.topic}: $preview');
      try {
        // 解析 JSON 数据包，提取 cmd 和 data 字段
        final packet = jsonDecode(text) as Map<String, dynamic>;
        // cmd 安全解析：后端通常发送 int，但兼容 String 情况
        final dynamic cmdRaw = packet['cmd'];
        final int cmd;
        if (cmdRaw is int) {
          cmd = cmdRaw;
        } else if (cmdRaw is num) {
          cmd = cmdRaw.toInt();
        } else if (cmdRaw is String) {
          cmd = int.tryParse(cmdRaw) ?? 0;
        } else {
          cmd = 0;
        }
        final data = packet['data'];
        // 调用上层回调处理消息
        onMessage?.call(cmd, data);
      } on FormatException {
        // 忽略格式错误的 payload
        debugPrint('[MQTT] malformed payload on ${received.topic}: $preview');
      }
    }
  }

  /// 发布消息到指定主题
  void publish(Map<String, dynamic> message, {required String topic}) {
    if (!isConnected) return;
    final builder = MqttClientPayloadBuilder()..addString(jsonEncode(message));
    _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }

  /// 发送私聊消息（通过MQTT）
  void sendPrivateMessage(Map<String, dynamic> message, int targetUserId) {
    publish(message, topic: 'chat/user/$targetUserId');
  }

  /// 发送群消息（通过MQTT）
  void sendGroupMessage(Map<String, dynamic> message, int groupId) {
    publish(message, topic: 'chat/group/$groupId');
  }

  /// 向服务端发送消息（用于回执、请求未推送消息等控制命令）
  /// 通过 REST API 发送，更可靠
  void sendToServer(Map<String, dynamic> message) {
    // 控制命令通过 REST API 发送，不走 MQTT
    // 此方法保留接口兼容性，实际由 ChatService 发送
  }

  void disconnect() {
    _client?.disconnect();
    _client = null;
  }
}
