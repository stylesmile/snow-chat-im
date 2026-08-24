# Snow Chat IM - 部署指南

## 环境要求

### 后端
- JDK 17+
- Maven 3.6+
- MySQL 8.0+
- MinIO (可选，用于文件存储)
- MQTT Broker (mica-mqtt 内置)

### 前端
- Flutter 3.41+
- Dart 3.2+
- Android SDK / iOS Xcode

---

## 后端部署

### 1. 数据库初始化

```bash
# 创建数据库
mysql -u root -p
CREATE DATABASE snow_chat_im CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
EXIT;

# Flyway 会自动执行迁移脚本
# 位置: snow-im-api/src/main/resources/db/migration/
```

### 2. 配置文件

编辑 `snow-im-api/src/main/resources/application-test.yml`:

```yaml
server:
  port: 8091

spring:
  datasource:
    url: jdbc:mysql://localhost:3306/snow_chat_im?useUnicode=true&characterEncoding=utf8&useSSL=false
    username: root
    password: your_password

mqtt:
  client:
    enabled: true
    ip: 127.0.0.1
    port: 1883
```

### 3. MinIO 部署（可选）

```bash
# 使用 Docker Compose
cd snow-chat-im-backend
docker-compose up -d minio

# 访问控制台: http://localhost:9001
# 账号: minioadmin / minioadmin
```

### 4. 编译运行

```bash
# 编译
cd snow-chat-im-backend
mvn clean install -DskipTests

# 运行
java -jar snow-im-api/target/snow-im-api-*.jar
# 或
mvn spring-boot:run -pl snow-im-api
```

### 5. 验证

```bash
# 检查服务
curl http://localhost:8091/chat/user/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test","password":"test"}'
```

---

## 前端部署

### 1. 安装依赖

```bash
cd snow-chat-flutter
flutter pub get
```

### 2. 配置 API 地址

编辑 `lib/config/config.dart`:

```dart
static const String baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://YOUR_SERVER_IP:8091',
);

static const String mqttHost = String.fromEnvironment(
  'MQTT_HOST',
  defaultValue: 'YOUR_SERVER_IP',
);
```

### 3. 运行开发版

```bash
# Android
flutter run -d android

# iOS
flutter run -d ios

# Web
flutter run -d chrome
```

### 4. 构建发布版

```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS
flutter build ios --release

# Web
flutter build web --release
```

---

## 环境变量

### 后端 (application.yml)
| 变量 | 默认值 | 说明 |
|------|--------|------|
| server.port | 8091 | HTTP端口 |
| mqtt.client.ip | 127.0.0.1 | MQTT服务器地址 |
| mqtt.client.port | 1883 | MQTT端口 |
| mqtt.client.username | mica | MQTT用户名 |
| mqtt.client.password | 123456 | MQTT密码 |

### 前端 (flutter run)
```bash
flutter run \
  --dart-define=API_BASE_URL=http://192.168.0.101:8091 \
  --dart-define=MQTT_HOST=192.168.0.101 \
  --dart-define=MQTT_PORT=1883
```

---

## Docker 部署（推荐）

### docker-compose.yml

```yaml
version: '3.8'

services:
  mysql:
    image: mysql:8.0
    container_name: snow-chat-mysql
    environment:
      MYSQL_ROOT_PASSWORD: 12345678
      MYSQL_DATABASE: snow_chat_im
    ports:
      - "3306:3306"
    volumes:
      - mysql-data:/var/lib/mysql
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql

  minio:
    image: minio/minio:latest
    container_name: snow-chat-minio
    ports:
      - "9000:9000"
      - "9001:9001"
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin
    command: server /data --console-address ":9001"
    volumes:
      - minio-data:/data

  backend:
    build: ./snow-chat-im-backend
    container_name: snow-chat-backend
    ports:
      - "8091:8091"
    environment:
      SPRING_DATASOURCE_URL: jdbc:mysql://mysql:3306/snow_chat_im
      SPRING_DATASOURCE_USERNAME: root
      SPRING_DATASOURCE_PASSWORD: 12345678
      MQTT_BROKER_URL: tcp://localhost:1883
    depends_on:
      - mysql
      - minio

volumes:
  mysql-data:
  minio-data:
```

### 启动

```bash
docker-compose up -d
```

---

## 测试

### 后端测试

```bash
cd snow-chat-im-backend
mvn test
```

### 前端测试

```bash
cd snow-chat-flutter
flutter test
```

---

## 监控

### 健康检查
```bash
# 后端健康
curl http://localhost:8091/actuator/health

# MQTT连接
# 查看日志: snow-im-api/logs/
```

### 日志位置
- 后端: `snow-im-api/logs/`
- Flutter: 控制台输出（debugPrint）

---

## 常见问题

### 1. 数据库连接失败
- 检查 MySQL 服务是否启动
- 确认数据库已创建
- 检查用户名密码

### 2. MQTT连接失败
- 确认 mica-mqtt 已启用
- 检查端口 1883 是否开放

### 3. 文件上传失败
- 检查 MinIO 服务
- 确认 bucket 已创建

### 4. iOS 构建失败
- 运行 `pod install`
- 检查 Certificates & Identifiers
