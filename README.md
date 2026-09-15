# Snow Chat IM

基于 Spring Boot + Flutter 的实时通讯系统，支持私聊、群聊、好友管理、图片/文件传输、离线消息投递。

```
https://gitee.com/stylesmile/snow-chat-im
https://github.com/stylesmile/snow-chat-im
```

## 目录结构

```
snow-chat-im/
├── snow-chat-im-backend/     # 后端（Java / Spring Boot 3）
│   ├── snow-common/          # 公共模块（工具类、基础实体、JWT）
│   └── snow-im-api/          # IM 核心业务模块（REST API + MQTT + 文件存储）
├── snow-chat-flutter/        # 移动端 / 桌面端客户端（Flutter）
├── docs/                     # 项目文档（架构、数据库、API、部署等）
└── plans/                    # 规划与 Gap 分析文档
```

## 技术栈

| 层 | 技术 |
|---|---|
| 后端 | Java 17、Spring Boot 3.5.14、MyBatis-Plus 3.5.14、MySQL 8.0、Flyway、Druid、JWT (jjwt) |
| 实时通信 | MQTT（mica-mqtt 内置 Broker）、WebSocket |
| 文件存储 | MinIO（S3 协议）/ 阿里云 OSS / 本地磁盘，可配置切换 |
| 前端 | Flutter 3.41+、Dart、BLoC、Dio、GoRouter、GetIt/Injectable |
| 本地缓存 | SQLite |

## 功能

- 用户注册 / 登录 / 邮箱验证码 / 忘记密码
- 好友管理：添加、备注、删除；好友请求（同意 / 拒绝）
- 群聊：创建群、群成员管理、群消息广播
- 实时消息：私聊 / 群聊，文本、图片、视频、文件
- 消息撤回、已读回执
- 离线消息投递（MQTT 离线 + 重新上线补发）
- 会话列表与未读数管理
- 文件上传 / 下载（MinIO / OSS / 本地磁盘三选一）
- 图片查看器、聊天记录搜索、全局搜索
- 多语言（l10n）

## 快速开始

### 环境要求

- JDK 17+（JDK 23+ 下 Lombok 需要 ≥ 1.18.48，本项目已锁定 1.18.48 并在 maven-compiler-plugin 配置了 `-proc:full`，JDK 17 和 JDK 26 均可正常编译）
- Maven 3.6+
- MySQL 8.0+
- Flutter 3.41+（Android / iOS / macOS / Windows / Linux）

### 1. 数据库

```bash
mysql -u root -p
CREATE DATABASE snow_chat_im CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
```

Flyway 会自动执行迁移脚本（`snow-im-api/src/main/resources/db/migration/V1~V5`），无需手动导入 SQL。

### 2. 配置

编辑 `snow-im-api/src/main/resources/application-dev.yml`：

```yaml
server:
  port: 8091

spring:
  datasource:
    url: jdbc:mysql://localhost:3306/snow_chat_im?useUnicode=true&characterEncoding=UTF-8&useSSL=false
    username: root
    password: your_password

mqtt:
  broker-url: tcp://127.0.0.1:1883
```

MQTT Broker 由 mica-mqtt 内置，无需单独部署（默认监听 1883）。

### 3. 构建并启动后端

```bash
cd snow-chat-im-backend
mvn clean install -DskipTests     # 首次编译
mvn package -pl snow-im-api       # 打包
java -jar snow-im-api/target/snow-im-api-*.jar --spring.profiles.active=dev
```

启动后 REST API 监听 `8091`，MQTT 监听 `1883`。

### 4. 运行 Flutter 客户端

```bash
cd snow-chat-flutter
flutter pub get
# 配置后端 / MQTT 地址（通过构建参数或修改 lib/config/config.dart）
flutter run
```

常用平台：

```bash
flutter run -d android
flutter run -d ios
flutter run -d macos
```

## 测试

### 后端（184 个用例）

```bash
cd snow-chat-im-backend/snow-im-api
mvn test
```

### Flutter 客户端

```bash
cd snow-chat-flutter
flutter test
```

## 文档

| 文档 | 说明 |
|---|---|
| [docs/architecture.md](docs/architecture.md) | 系统架构（模块划分、MQTT 组件、实体类） |
| [docs/message-flow.md](docs/message-flow.md) | 消息流转（私聊 / 群聊 / 离线） |
| [docs/database-design.md](docs/database-design.md) | 数据库设计与 ER 图 |
| [docs/api-reference.md](docs/api-reference.md) | REST API 与 MQTT 协议 |
| [docs/deployment-guide.md](docs/deployment-guide.md) | 部署指南（含 MinIO Docker） |
| [docs/docker-mysql.md](docs/docker-mysql.md) | MySQL Docker 快速启动 |
| [docs/security-guide.md](docs/security-guide.md) | 安全指南 |
| [docs/testing-guide.md](docs/testing-guide.md) | 测试指南 |
| [docs/flutter-architecture.md](docs/flutter-architecture.md) | Flutter 端架构 |
| [plans/tangdaodao-gap-analysis.md](plans/tangdaodao-gap-analysis.md) | 功能 Gap 分析 |

## 相关项目

- [with-chat](https://gitee.com/stylesmile/with-chat) — Flutter 聊天客户端（BLoC 架构）

## License

MIT
