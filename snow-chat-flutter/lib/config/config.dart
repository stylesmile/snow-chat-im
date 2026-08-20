/// 应用连接配置：后端地址、MQTT 连接参数
/// App connection configuration: backend URL, MQTT connection settings
class AppConfig {
  // 通过 --dart-define=API_BASE_URL 覆盖
  // Backend base URL (override with --dart-define=API_BASE_URL)
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    // defaultValue: 'http://192.168.0.101:8091',
    defaultValue: 'http://192.168.0.48:8091',
  );

  // MQTT 连接配置
  // MQTT connection settings
  static const String mqttHost = String.fromEnvironment(
    'MQTT_HOST',
    // defaultValue: '192.168.0.101',
    defaultValue: '192.168.0.48',
  );
  static const int mqttPort = int.fromEnvironment('MQTT_PORT', defaultValue: 1883);
  static const String mqttUsername = String.fromEnvironment(
    'MQTT_USERNAME',
    defaultValue: 'mica',
  );
  static const String mqttPassword = String.fromEnvironment(
    'MQTT_PASSWORD',
    defaultValue: '123456',
  );
}
