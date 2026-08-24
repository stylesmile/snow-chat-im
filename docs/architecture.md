# Snow Chat IM - 系统架构文档

## 项目概述

Snow Chat IM 是一个基于 Spring Boot + Flutter 的实时通讯系统，支持私聊、群聊、好友关系管理等功能。

**技术栈：**
- 后端：Java 17, Spring Boot 3.5.14, MyBatis-Plus 3.5.14, MySQL 8.0
- 通信：MQTT (mica-mqtt), WebSocket
- 前端：Flutter 3.41+, Dart 3.2+
- 存储：MinIO (文件), SQLite (本地缓存)

---

## 后端架构

### 模块结构

```
snow-chat-im-backend/
├── snow-common/          # 公共模块 (工具类、基础实体、配置)
├── snow-system/          # 系统管理模块 (用户、角色、菜单、权限)
└── snow-im-api/          # IM 核心业务模块
    └── src/main/java/com/stylesmile/chat/
        ├── controller/   # REST API 控制器 (7个)
        ├── service/      # 业务服务接口 (9个)
        ├── service/impl/ # 服务实现 (9个)
        ├── mapper/       # 数据访问层 (9个)
        ├── entity/       # 实体类 (9个)
        ├── dto/          # 数据传输对象
        ├── vo/           # 视图对象
        ├── mqtt/         # MQTT 集成 (5个类)
        ├── filter/       # 认证过滤器
        ├── storage/      # 文件存储 (MinIO/InMemory)
        └── util/         # 工具类
```

### 核心组件

#### Controller 层 (7个)

| 控制器 | 路径前缀 | 职责 |
|--------|----------|------|
| ChatUserController | /chat/user | 用户认证、注册、资料管理 |
| ChatMessageController | /chat/message | 消息发送、历史、撤回、已读 |
| ChatFriendController | /chat/friend | 好友关系、好友请求 |
| ChatGroupController | /chat/group | 群组管理、成员操作 |
| ChatSessionController | /chat/session | 会话列表、未读数清除 |
| FileController | /chat/file | 文件上传下载 |
| GlobalExceptionHandler | - | 全局异常处理 |

#### Service 层 (9个核心服务)

| 服务 | 实现类 | 职责 |
|------|--------|------|
| ChatUserService | ChatUserServiceImpl | 用户登录、注册、搜索 |
| ChatMessageService | ChatMessageServiceImpl | 消息发送、推送、撤回、已读 |
| ChatFriendService | ChatFriendServiceImpl | 好友增删查 |
| ChatFriendRequestService | ChatFriendRequestServiceImpl | 好友请求发送、处理 |
| ChatGroupService | ChatGroupServiceImpl | 群组创建、查询 |
| ChatGroupMemberService | ChatGroupMemberServiceImpl | 群成员管理 |
| ChatSessionService | ChatSessionServiceImpl | 会话管理、未读数 |
| ChatVerifyCodeService | ChatVerifyCodeServiceImpl | 邮箱验证码 |
| FileStorageService | FileStorageServiceImpl | 文件存储(MinIO) |

### MQTT 组件

| 类 | 职责 |
|----|------|
| MqttPushService | 消息推送服务 |
| MqttTopics | Topic 常量 (chat/user/{id}, chat/group/{id}) |
| WsCmd | 命令常量 (1001-1099客户端→服务端, 2001-2099服务端→客户端) |
| MqttConnectStatusListener | 在线状态监听 |
| MqttOfflineMessageDeliver | 离线消息投递 |

### 实体类 (Entity)

| 实体 | 表名 | 主要字段 |
|------|------|----------|
| ChatUser | chat_user | id, username, password, nickname, email, avatar, status |
| ChatMessage | chat_message | id, fromUserId, toUserId, groupId, type, content, status, pushStatus |
| ChatFriend | chat_friend | id, userId, friendId, remark |
| ChatFriendRequest | chat_friend_request | id, fromUserId, toUserId, status, remark |
| ChatGroup | chat_group | id, name, avatar, ownerId, maxMembers |
| ChatGroupMember | chat_group_member | id, groupId, userId, role, mute |
| ChatSession | chat_session | id, userId, targetId, targetType, lastMsg, unreadCount |
| ChatOfflineMessage | chat_offline_message | id, toUserId, topic, cmd, payload |
| ChatVerifyCode | chat_verify_code | id, email, code, type, expireTime, used |

### 配置

- 数据库: MySQL 8.0, utf8mb4
- 连接池: Druid (max-active=20)
- ORM: MyBatis-Plus 3.5.14
- 迁移: Flyway (7个版本)
- JWT: jjwt 0.12.6
- 缓存: Spring Cache

### 依赖注入

- 使用 @Resource 和 @Autowired
- 允许循环依赖 (allow-circular-references: true)
