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

  Future<void> connect({required int userId, String? username, String? password}) async {
    final clientId = 'user_$userId';
    final client = MqttServerClient.withPort(host, clientId, port);
    client.logging(on: false);
    client.keepAlivePeriod = 30;
    client.autoReconnect = true;
    client.resubscribeOnAutoReconnect = true;
    client.onConnected = onConnected;
    client.onDisconnected = onDisconnected;
    client.onAutoReconnect = () {};
    client.onAutoReconnected = () => _subscribeAll(userId);
    client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    _client = client;
    try {
      await client.connect(username, password);
      if (isConnected) {
        _subscribeAll(userId);
        client.updates?.listen(_handleMessages);
      }
    } catch (_) {
      client.disconnect();
      _client = null;
      onDisconnected?.call();
    }
  }

  /// 订阅所有主题（用户 + 已加入的群）
  void _subscribeAll(int userId) {
    _client?.subscribe('chat/user/$userId', MqttQos.atLeastOnce);
    // 群主题由 subscribeGroup 单独管理
  }

  /// 订阅群主题
  void subscribeGroup(int groupId) {
    _client?.subscribe('chat/group/$groupId', MqttQos.atLeastOnce);
  }

  /// 取消订阅群主题
  void unsubscribeGroup(int groupId) {
    _client?.unsubscribe('chat/group/$groupId');
  }

  void _handleMessages(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final received in messages) {
      final publish = received.payload as MqttPublishMessage;
      final text = MqttPublishPayload.bytesToStringAsString(publish.payload.message);
      try {
        final packet = jsonDecode(text) as Map<String, dynamic>;
        final cmd = packet['cmd'] as int? ?? 0;
        final data = packet['data'];
        onMessage?.call(cmd, data);
      } on FormatException {
        // Ignore malformed broker payloads.
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

  void disconnect() {
    _client?.disconnect();
    _client = null;
  }
}
