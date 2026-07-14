import 'dart:convert';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttChatClient {
  MqttServerClient? _client;
  final String host;
  final int port;
  final Function(int cmd, dynamic data)? onMessage;
  final Function()? onConnected;
  final Function()? onDisconnected;

  MqttChatClient({
    required this.host,
    this.port = 1883,
    this.onMessage,
    this.onConnected,
    this.onDisconnected,
  });

  bool get isConnected => _client?.connectionStatus?.state == MqttConnectionState.connected;

  Future<void> connect({required int userId, String? username, String? password}) async {
    final client = MqttServerClient.withPort(host, 'snow-chat-$userId', port);
    client.logging(on: false);
    client.keepAlivePeriod = 30;
    client.autoReconnect = true;
    client.resubscribeOnAutoReconnect = true;
    client.onConnected = onConnected;
    client.onDisconnected = onDisconnected;
    client.onAutoReconnect = () {};
    client.onAutoReconnected = () => _subscribe(userId);
    client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier('snow-chat-$userId')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    _client = client;
    try {
      await client.connect(username, password);
      if (isConnected) {
        _subscribe(userId);
        client.updates?.listen(_handleMessages);
      }
    } catch (_) {
      client.disconnect();
      _client = null;
      onDisconnected?.call();
    }
  }

  void _subscribe(int userId) {
    _client?.subscribe('chat/user/$userId', MqttQos.atLeastOnce);
  }

  void subscribeGroup(int groupId) {
    _client?.subscribe('chat/group/$groupId', MqttQos.atLeastOnce);
  }

  void _handleMessages(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final received in messages) {
      final publish = received.payload as MqttPublishMessage;
      final text = MqttPublishPayload.bytesToStringAsString(publish.payload.message);
      try {
        final packet = jsonDecode(text) as Map<String, dynamic>;
        onMessage?.call(packet['cmd'] as int? ?? 0, packet['data']);
      } on FormatException {
        // Ignore malformed broker payloads.
      }
    }
  }

  void send(Map<String, dynamic> message, {required int targetId, int? groupId}) {
    if (!isConnected) return;
    final topic = groupId == null ? 'chat/user/$targetId' : 'chat/group/$groupId';
    final builder = MqttClientPayloadBuilder()..addString(jsonEncode(message));
    _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }

  void disconnect() {
    _client?.disconnect();
    _client = null;
  }
}
