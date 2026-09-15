# 聊天系统实现计划

## 一、项目概述

构建一个完整的即时通讯系统，包含三个模块：
- **Flutter 前端** (`snow-chat-flutter`)：跨平台客户端，支持 iOS/Android/Web/Desktop
- **IM 后端** (`snow-im-api`)：基于 TIO WebSocket + gRPC 的实时通讯服务
- **管理后台** (`snow-system`)：已有的 Spring Boot 系统管理模块（用户、角色、部门等）

### 核心功能需求
1. 私聊（点对点消息）
2. 群聊（群组消息）
3. 多媒体消息：文字、图片、视频
4. SQLite 本地消息存储
5. 加好友/好友申请
6. 通讯录管理（通讯录也存在sqlite）
7. 个人中心
8. 多语言支持（i18n），登陆页面，和个人中心支持设置语言切换，默认中文，支持英文、简体中文，繁体中文、日文、韩文
9. 通讯层：TIO WebSocket 实时通讯
10. 业务接口：gRPC app调用api服务，api是个独立启动的服务，proto文件在snow-im-api模块下，app在snow-chat-flutter模块下
---

## 二、当前状态分析

### 已有基础设施
| 组件 | 状态 | 说明 |
|------|------|------|
| 管理后台 (snow-system) | 已有 | Spring Boot 3.5 + MyBatis-Plus + Freemarker |
| 公共模块 (snow-common) | 已有 | Result 包装、BaseEntity、常量、异常处理 |
| 用户体系 | 已有 | SysUser、登录认证(MD5)、Session管理 |
| 部门体系 | 已有 | SysDepart（通讯录基础） |
| Flutter 前端 | 不存在 | 需从零创建 |
| IM 后端 | 不存在 | 需新增模块 |

### 技术栈约束
- Java 17 / Spring Boot 3.5.14
- MySQL 8.x + Flyway 迁移
- MyBatis-Plus 3.5.14
- Maven 多模块项目

---

## 三、实施步骤

### 阶段 1：IM 后端模块搭建

#### Step 1.1：创建 `snow-im-api` Maven 模块

**新建文件：**
- `snow-chat-im-backend/snow-im-api/pom.xml`
- 添加到根 `pom.xml` 的 `<modules>` 中

**依赖：**
```xml
<!-- TIO WebSocket -->
<dependency>
    <groupId>org.t-io</groupId>
    <artifactId>tio-websocket-server</artifactId>
    <version>3.7.4.v20230730</version>
</dependency>
<!-- gRPC -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-grpc</artifactId>
    <version>2.1.0.RELEASE</version>
</dependency>
<!-- Redis (用于在线状态、消息缓存) -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-data-redis</artifactId>
</dependency>
<!-- 已有依赖 -->
<dependency>
    <groupId>com.stylesmile</groupId>
    <artifactId>snow-common</artifactId>
    <version>${snow.common.version}</version>
</dependency>
```

#### Step 1.2：数据库设计 - IM 模块表结构

**新建迁移文件：**
`snow-system/src/main/resources/db/migration/V2__init_im_schema.sql`

**新增表：**

| 表名 | 说明 | 关键字段 |
|------|------|---------|
| `im_group` | 群组 | id, name, avatar, owner_id, max_members, create_time, update_time, del_flag |
| `im_group_member` | 群成员 | id, group_id, user_id, role(admin/member), join_time, mute |
| `im_friend_request` | 好友申请 | id, from_user_id, to_user_id, status(pending/accepted/rejected), remark, create_time |
| `im_friend` | 好友关系 | id, user_id, friend_id, remark, create_time（唯一索引：user_id+friend_id） |
| `im_message` | 消息记录 | id, from_user_id, to_user_id/group_id, type(text/image/video/system), content, local_seq, status(sent/read/failed), create_time |
| `im_message_local` | 本地消息队列 | id, user_id, msg_json, sync_status(0=pending,1=synced), create_time |
| `im_user_profile` | 用户扩展资料 | id, user_id, avatar, signature, phone, email, update_time（扩展 SysUser） |

#### Step 1.3：IM 模块 Entity 层

**包路径：** `com.stylesmile.modules.im.entity`

| 文件 | 字段映射 |
|------|---------|
| `ImGroup.java` | im_group 表实体 |
| `ImGroupMember.java` | im_group_member 表实体 |
| `ImFriendRequest.java` | im_friend_request 表实体 |
| `ImFriend.java` | im_friend 表实体 |
| `ImMessage.java` | im_message 表实体 |
| `ImUserProfile.java` | im_user_profile 表实体 |

遵循现有模式：手动 getter/setter，Integer 主键，del_flag 软删除。

#### Step 1.4：IM 模块 Mapper 层

**包路径：** `com.stylesmile.modules.im.mapper`

| 文件 | 说明 |
|------|------|
| `ImGroupMapper.java` | + `ImGroupMapper.xml` |
| `ImGroupMemberMapper.java` | + `ImGroupMemberMapper.xml` |
| `ImFriendMapper.java` | + `ImFriendMapper.xml` |
| `ImFriendRequestMapper.java` | + `ImFriendRequestMapper.xml` |
| `ImMessageMapper.java` | + `ImMessageMapper.xml` |
| `ImUserProfileMapper.java` | + `ImUserProfileMapper.xml` |

#### Step 1.5：gRPC 定义与客户端

**新建 proto 文件：**
`snow-im-api/src/main/proto/im_service.proto`

```protobuf
syntax = "proto3";
package imsdk;

service ImUserService {
  // 获取用户信息（从 snow-system 查询）
  rpc GetUser (GetUserRequest) returns (UserInfo);
  // 搜索用户
  rpc SearchUser (SearchUserRequest) returns (UserList);
  // 获取用户列表（通讯录）
  rpc GetUserList (GetUserListRequest) returns (UserList);
}

service ImFriendService {
  // 发送好友申请
  rpc SendFriendRequest (FriendRequestRequest) returns (Result);
  // 处理好友申请
  rpc HandleFriendRequest (HandleFriendRequestRequest) returns (Result);
  // 获取好友列表
  rpc GetFriendList (GetFriendListRequest) returns (FriendList);
}

service ImGroupService {
  // 创建群组
  rpc CreateGroup (CreateGroupRequest) returns (GroupInfo);
  // 获取群组信息
  rpc GetGroupInfo (GetGroupInfoRequest) returns (GroupInfo);
  // 添加群成员
  rpc AddGroupMembers (AddGroupMembersRequest) returns (Result);
  // 移除群成员
  rpc RemoveGroupMembers (RemoveGroupMembersRequest) returns (Result);
}

message GetUserRequest {
  int32 user_id = 1;
}

message UserInfo {
  int32 id = 1;
  string username = 2;
  string nickname = 3;
  string avatar = 4;
  string phone = 5;
  string email = 6;
}

// ... 其他 message 定义
```

**gRPC 客户端实现：**
`snow-im-api/src/main/java/com/stylesmile/modules/im/grpc/ImUserGrpcClient.java`
`snow-im-api/src/main/java/com/stylesmile/modules/im/grpc/ImFriendGrpcClient.java`
`snow-im-api/src/main/java/com/stylesmile/modules/im/grpc/ImGroupGrpcClient.java`

#### Step 1.6：WebSocket 处理器（TIO）

**包路径：** `com.stylesmile.modules.im.websocket`

| 文件 | 说明 |
|------|------|
| `WebSocketServer.java` | TIO WebSocket 服务器启动/停止入口 |
| `WsPacket.java` | 自定义 WebSocket 数据包（继承 `AioPacket<WsPacket>`） |
| `WsHandler.java` | 消息处理器（继承 `IWsMsgHandler<Object>`） |
| `WsConnectListener.java` | 连接监听器（上线/下线事件） |
| `WsOnlineUser.java` | 在线用户管理器（Aio + GroupContext 封装） |

**协议设计：**

所有消息统一格式：
```json
{
  "cmd": 1001,
  "seq": "unique-seq-id",
  "data": { ... }
}
```

命令码分配：

| 范围 | 方向 | 说明 |
|------|------|------|
| 1001-1099 | Client→Server | 客户端请求 |
| 2001-2099 | Server→Client | 服务端推送 |

具体命令：

| 命令码 | 名称 | 说明 |
|--------|------|------|
| 1001 | WS_CMD_LOGIN | 客户端登录 |
| 1002 | WS_MSG_TEXT | 发送文本消息 |
| 1003 | WS_MSG_IMAGE | 发送图片消息 |
| 1004 | WS_MSG_VIDEO | 发送视频消息 |
| 1005 | WS_MSG_SYSTEM | 系统消息 |
| 1006 | WS_FRIEND_ADD_REQ | 加好友请求 |
| 1007 | WS_FRIEND_ADD_RESP | 加好友响应 |
| 1008 | WS_CONTACT_GET | 获取通讯录 |
| 1009 | WS_GROUP_CREATE | 创建群 |
| 1010 | WS_GROUP_JOIN | 加入群 |
| 1011 | WS_MSG_RECALL | 撤回消息 |
| 1012 | WS_READ_ACK | 已读回执 |
| 2001 | WS_MSG_PUSH | 推送消息 |
| 2002 | WS_FRIEND_REQ_NOTIFY | 好友申请通知 |
| 2003 | WS_ONLINE_STATUS | 在线状态变更 |
| 2004 | WS_GROUP_NOTIFY | 群通知 |

#### Step 1.7：IM 模块 Service 层

**包路径：** `com.stylesmile.modules.im.service` + `impl`

| 文件 | 说明 |
|------|------|
| `ImMessageService.java` | 消息发送、接收、历史消息查询 |
| `ImFriendService.java` | 好友管理（申请、通过、删除、列表） |
| `ImGroupService.java` | 群组管理（创建、成员管理、群信息） |
| `ImContactService.java` | 通讯录（好友+部门联系人） |
| `ImUserProfileService.java` | 用户个人资料管理 |

#### Step 1.8：IM 模块 Controller 层（REST API）

**包路径：** `com.stylesmile.modules.im.controller`

| 文件 | 说明 |
|------|------|
| `ImMessageController.java` | 消息历史、分页查询、文件上传回调 |
| `ImFriendController.java` | 好友申请、通过、拒绝、删除 |
| `ImGroupController.java` | 群创建、成员管理、群信息 |
| `ImContactController.java` | 通讯录获取 |
| `ImProfileController.java` | 个人信息更新 |

遵循现有 `.json` 后缀模式，使用 `Result<T>` 包装返回值。

#### Step 1.9：文件存储服务

**包路径：** `com.stylesmile.modules.im.service`

| 文件 | 说明 |
|------|------|
| `ImFileStorageService.java` | 文件上传接口 |
| `LocalFileStorageServiceImpl.java` | 本地文件系统存储实现 |

支持：图片(JPG/PNG/GIF/WebP)、视频(MP4/MOV)、音频。

#### Step 1.10：IM 模块启动配置

**文件：** `snow-im-api/src/main/java/com/stylesmile/im/ImApplication.java`

```java
@MapperScan("com.stylesmile.modules.im.mapper")
@SpringBootApplication
@EnableGrpc  // gRPC 服务端/客户端配置
public class ImApplication {
    public static void main(String[] args) {
        SpringApplication.run(ImApplication.class, args);
    }
}
```

**配置文件：**
- `snow-im-api/src/main/resources/application.yml`
- `snow-im-api/src/main/resources/application-dev.yml`

关键配置：
```yaml
server:
  port: 8091

tio:
  websocket:
    port: 8800
    thread-group-count: 4

grpc:
  server:
    port: 50051
  client:
    snow-system:
      address: localhost:9090
      negotiation-type: plaintext
```

---

### 阶段 2：管理后台扩展

#### Step 2.1：扩展 SysUser 实体

**修改文件：** `snow-system/src/main/java/com/stylesmile/modules/system/entity/SysUser.java`

新增字段：
```java
private String avatar;       // 头像URL
private String signature;    // 个性签名
```

#### Step 2.2：新增 gRPC 服务端（在 snow-system 中）

**新建模块或直接在 snow-system 中添加：**

| 文件 | 说明 |
|------|------|
| `ImUserServiceGrpcImpl.java` | gRPC 服务实现 - 提供用户查询 |
| `ImFriendServiceGrpcImpl.java` | gRPC 服务实现 - 提供好友关系查询 |
| `ImGroupServiceGrpcImpl.java` | gRPC 服务实现 - 提供群组信息查询 |

**配置：** `snow-system/src/main/resources/application.yml`
```yaml
grpc:
  server:
    port: 9090
```

#### Step 2.3：Flyway 迁移

**新建文件：** `snow-system/src/main/resources/db/migration/V2__init_im_schema.sql`

包含阶段 1.2 中所有表的 DDL。

---

### 阶段 3：Flutter 前端

#### Step 3.1：初始化 Flutter 项目

**新建目录：** `snow-chat-flutter/`

```bash
flutter create --org com.stylesmile --project-name snow_chat snow-chat-flutter
```

**pubspec.yaml 核心依赖：**
```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  
  # 状态管理
  provider: ^6.1.1
  
  # WebSocket 通信
  web_socket_channel: ^2.4.0
  socket_io_client: ^2.0.3
  
  # 本地存储
  sqflite: ^2.3.0
  sqlite3_flutter_libs: ^0.5.0
  
  # 网络请求
  dio: ^5.4.0
  
  # 多媒体
  image_picker: ^1.0.0
  video_player: ^2.8.0
  cached_network_image: ^3.3.0
  
  # 国际化
  intl: ^0.19.0
  
  # 工具
  uuid: ^4.2.0
  path_provider: ^2.1.0
  permission_handler: ^11.2.0
  
  # 本地消息队列
  shared_preferences: ^2.2.2
  
  # UI
  flutter_slidable: ^3.0.1
  flutter_staggered_grid_view: ^0.7.0
```

#### Step 3.2：项目架构

```
snow-chat-flutter/lib/
├── main.dart                          # 入口
├── app.dart                           # MaterialApp 配置
├── core/
│   ├── constants/
│   │   ├── app_constants.dart         # API地址、命令码等
│   │   └── storage_keys.dart          # SharedPreferences keys
│   ├── network/
│   │   ├── api_client.dart            # Dio REST 客户端
│   │   └── websocket_client.dart      # WebSocket 客户端
│   ├── database/
│   │   ├── database_helper.dart       # SQLite 辅助类
│   │   └── tables.dart                # 表定义
│   ├── utils/
│   │   ├── message_utils.dart         # 消息格式化
│   │   └── date_utils.dart            # 日期格式化
│   └── router/
│       └── app_router.dart            # 路由管理
├── models/
│   ├── user.model.dart                # 用户模型
│   ├── message.model.dart             # 消息模型
│   ├── group.model.dart               # 群组模型
│   ├── friend.model.dart              # 好友模型
│   └── contact.model.dart             # 通讯录模型
├── services/
│   ├── auth.service.dart              # 认证服务
│   ├── chat.service.dart              # 聊天服务
│   ├── contact.service.dart           # 通讯录服务
│   ├── file.service.dart              # 文件上传服务
│   └── profile.service.dart           # 个人设置服务
├── l10n/
│   ├── app_en.arb                     # 英文
│   ├── app_zh.arb                     # 中文
│   └── app_ja.arb                     # 日文（可选）
├── ui/
│   ├── screens/
│   │   ├── login/
│   │   │   └── login_screen.dart      # 登录页
│   │   ├── chat/
│   │   │   ├── chat_list_screen.dart  # 会话列表
│   │   │   ├── chat_detail_screen.dart # 聊天详情页
│   │   │   └── widgets/
│   │   │       ├── text_messageBubble.dart
│   │   │       ├── image_message_bubble.dart
│   │   │       └── video_message_bubble.dart
│   │   ├── contact/
│   │   │   ├── contact_list_screen.dart   # 通讯录
│   │   │   ├── friend_request_screen.dart # 好友申请
│   │   │   └── add_friend_screen.dart     # 添加好友
│   │   ├── group/
│   │   │   ├── group_list_screen.dart     # 群列表
│   │   │   ├── group_detail_screen.dart   # 群详情
│   │   │   └── create_group_screen.dart   # 创建群
│   │   └── profile/
│   │       └── profile_screen.dart        # 个人中心
│   └── widgets/
│       ├── avatar_widget.dart
│       ├── empty_state_widget.dart
│       └── loading_widget.dart
└── providers/
    ├── auth.provider.dart           # 认证状态
    ├── chat.provider.dart           # 聊天状态
    ├── contact.provider.dart        # 通讯录状态
    └── settings.provider.dart       # 设置（语言等）
```

#### Step 3.3：SQLite 本地消息存储

**文件：** `lib/core/database/database_helper.dart`

```sql
-- 消息表
CREATE TABLE local_messages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    msg_id INTEGER,           -- 服务端消息ID
    from_user_id INTEGER,
    to_user_id INTEGER,
    group_id INTEGER,         -- 群聊时不为空
    msg_type TEXT,            -- text/image/video/system
    content TEXT,             -- 消息内容(JSON)
    local_seq INTEGER,        -- 本地序列号
    status TEXT,              -- sent/reading/sent/read/failed
    create_time INTEGER,
    update_time INTEGER
);

-- 会话表
CREATE TABLE conversations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    target_id INTEGER,        -- 好友ID或群ID
    target_type TEXT,         -- friend/group
    last_msg TEXT,            -- 最后一条消息摘要
    last_msg_time INTEGER,
    unread_count INTEGER DEFAULT 0,
    is_muted INTEGER DEFAULT 0,
    update_time INTEGER
);

-- 好友表（本地缓存）
CREATE TABLE local_friends (
    user_id INTEGER PRIMARY KEY,
    nickname TEXT,
    avatar TEXT,
    remark TEXT,
    update_time INTEGER
);
```

#### Step 3.4：WebSocket 消息处理

**文件：** `lib/core/network/websocket_client.dart`

- 连接管理（自动重连、心跳保活）
- 消息编解码（JSON → WsPacket）
- 命令码分发路由
- 消息确认机制（ack）
- 离线消息同步

#### Step 3.5：多语言支持

**文件：** `lib/l10n/app_en.arb` / `app_zh.arb`

```json
// app_zh.arb
{
  "@@locale": "zh",
  "appTitle": "SnowChat",
  "login": "登录",
  "logout": "退出登录",
  "contacts": "通讯录",
  "chat": "聊天",
  "profile": "个人中心",
  "addFriend": "添加好友",
  "sendFriendRequest": "发送好友请求",
  "accept": "接受",
  "reject": "拒绝",
  "groupName": "群名称",
  "createGroup": "创建群组",
  "textMessage": "文本消息",
  "imageMessage": "图片消息",
  "videoMessage": "视频消息",
  "recallMessage": "撤回消息",
  "@textMessage": {"description": "消息类型：文本"},
  "@imageMessage": {"description": "消息类型：图片"}
}
```

#### Step 3.6：核心页面实现

| 页面 | 功能 |
|------|------|
| 登录页 | 账号密码登录，调用后端 `/login.json` |
| 会话列表 | 显示所有会话（私聊+群聊），未读数，最后消息预览 |
| 聊天详情 | 消息气泡展示，支持文字/图片/视频，消息状态，已读回执 |
| 通讯录 | 好友列表 + 部门联系人（gRPC 获取） |
| 添加好友 | 搜索用户，发送好友申请 |
| 好友申请 | 查看待处理申请，接受/拒绝 |
| 群组列表 | 我加入的群 |
| 创建群 | 选择成员创建群组 |
| 群详情 | 群信息编辑、成员管理、群公告 |
| 个人中心 | 头像、昵称、签名修改，语言切换 |

---

### 阶段 4：集成与联调

#### Step 4.1：服务注册与发现

- Eureka 注册 snow-im-api 服务
- snow-system 作为 gRPC 服务端
- snow-im-api 作为 gRPC 客户端调用 snow-system

#### Step 4.2：统一认证

- Flutter 登录后获取 token/session
- WebSocket 连接时携带认证信息
- TIO 握手阶段验证用户身份

#### Step 4.3：消息流完整链路

```
客户端 A → WebSocket → TIO Server → 业务处理 → MySQL 持久化
                                ↓
                          gRPC → snow-system (查用户信息)
                                ↓
客户端 B ← WebSocket ← TIO Server ← 推送消息
```

---

## 四、关键技术决策

| 决策项 | 选择 | 理由 |
|--------|------|------|
| WebSocket 框架 | TIO (tio-websocket-server) | 用户明确要求，高性能 Netty 封装 |
| 服务间通信 | gRPC | 高性能、强类型契约、跨语言 |
| 本地存储 | SQLite (sqflite) | Flutter 官方推荐，轻量可靠 |
| 状态管理 | Provider | 简洁、Flutter 官方推荐 |
| 文件存储 | 本地文件系统 | 简单实现，生产环境可替换为 OSS |
| 认证方式 | Session + Cookie | 与现有 snow-system 保持一致 |

---

## 五、文件清单

### 后端新增/修改文件

#### snow-im-api 模块（新建）
```
snow-chat-im-backend/snow-im-api/
├── pom.xml
└── src/main/
    ├── java/com/stylesmile/modules/im/
    │   ├── controller/
    │   │   ├── ImMessageController.java
    │   │   ├── ImFriendController.java
    │   │   ├── ImGroupController.java
    │   │   ├── ImContactController.java
    │   │   └── ImProfileController.java
    │   ├── entity/
    │   │   ├── ImGroup.java
    │   │   ├── ImGroupMember.java
    │   │   ├── ImFriendRequest.java
    │   │   ├── ImFriend.java
    │   │   ├── ImMessage.java
    │   │   └── ImUserProfile.java
    │   ├── mapper/
    │   │   ├── ImGroupMapper.java + .xml
    │   │   ├── ImGroupMemberMapper.java + .xml
    │   │   ├── ImFriendMapper.java + .xml
    │   │   ├── ImFriendRequestMapper.java + .xml
    │   │   ├── ImMessageMapper.java + .xml
    │   │   └── ImUserProfileMapper.java + .xml
    │   ├── service/
    │   │   ├── ImMessageService.java + impl
    │   │   ├── ImFriendService.java + impl
    │   │   ├── ImGroupService.java + impl
    │   │   ├── ImContactService.java + impl
    │   │   ├── ImUserProfileService.java + impl
    │   │   └── ImFileStorageService.java + impl
    │   ├── websocket/
    │   │   ├── WebSocketServer.java
    │   │   ├── WsPacket.java
    │   │   ├── WsHandler.java
    │   │   ├── WsConnectListener.java
    │   │   └── WsOnlineUser.java
    │   ├── grpc/
    │   │   ├── ImUserGrpcClient.java
    │   │   ├── ImFriendGrpcClient.java
    │   │   └── ImGroupGrpcClient.java
    │   └── vo/
    │       ├── ImMessageVO.java
    │       ├── FriendRequestVO.java
    │       └── GroupInfoVO.java
    ├── resources/
    │   ├── application.yml
    │   ├── application-dev.yml
    │   └── proto/
    │       └── im_service.proto
    └── resources/mapper/im/
        ├── ImGroupMapper.xml
        ├── ImGroupMemberMapper.xml
        ├── ImFriendMapper.xml
        ├── ImFriendRequestMapper.xml
        ├── ImMessageMapper.xml
        └── ImUserProfileMapper.xml
```

#### snow-system 修改
```
snow-chat-im-backend/snow-system/
├── src/main/java/com/stylesmile/modules/system/entity/SysUser.java  # 修改：加 avatar, signature
├── src/main/java/com/stylesmile/modules/im/grpc/  # 新增：gRPC 服务端实现
│   ├── ImUserServiceGrpcImpl.java
│   ├── ImFriendServiceGrpcImpl.java
│   └── ImGroupServiceGrpcImpl.java
└── src/main/resources/db/migration/
    └── V2__init_im_schema.sql  # 新增：IM 模块数据库表
```

#### 根 pom.xml 修改
```
pom.xml  # 新增 snow-im-api module
```

### Flutter 前端文件

```
snow-chat-flutter/
├── pubspec.yaml
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── core/
│   │   ├── constants/app_constants.dart
│   │   ├── constants/storage_keys.dart
│   │   ├── network/api_client.dart
│   │   ├── network/websocket_client.dart
│   │   ├── database/database_helper.dart
│   │   ├── database/tables.dart
│   │   ├── utils/message_utils.dart
│   │   ├── utils/date_utils.dart
│   │   └── router/app_router.dart
│   ├── models/
│   │   ├── user.model.dart
│   │   ├── message.model.dart
│   │   ├── group.model.dart
│   │   ├── friend.model.dart
│   │   └── contact.model.dart
│   ├── services/
│   │   ├── auth.service.dart
│   │   ├── chat.service.dart
│   │   ├── contact.service.dart
│   │   ├── file.service.dart
│   │   └── profile.service.dart
│   ├── l10n/
│   │   ├── app_en.arb
│   │   └── app_zh.arb
│   ├── ui/screens/
│   │   ├── login/login_screen.dart
│   │   ├── chat/
│   │   │   ├── chat_list_screen.dart
│   │   │   ├── chat_detail_screen.dart
│   │   │   └── widgets/
│   │   ├── contact/
│   │   │   ├── contact_list_screen.dart
│   │   │   ├── friend_request_screen.dart
│   │   │   └── add_friend_screen.dart
│   │   ├── group/
│   │   │   ├── group_list_screen.dart
│   │   │   ├── group_detail_screen.dart
│   │   │   └── create_group_screen.dart
│   │   └── profile/profile_screen.dart
│   └── providers/
│       ├── auth.provider.dart
│       ├── chat.provider.dart
│       ├── contact.provider.dart
│       └── settings.provider.dart
```

---

## 六、实施顺序总结

1. **IM 后端数据库设计** → V2 迁移脚本
2. **IM 后端 Entity/Mapper** → 数据访问层
3. **IM 后端 gRPC Proto** → 服务契约
4. **IM 后端 Service** → 业务逻辑
5. **IM 后端 WebSocket/TIO** → 实时通讯
6. **IM 后端 Controller** → REST API
7. **IM 后端启动类** → 整合运行
8. **管理后台扩展** → 用户字段 + gRPC 服务端
9. **Flutter 项目初始化** → 架构搭建
10. **Flutter 本地数据库** → SQLite 存储
11. **Flutter WebSocket 客户端** → 通讯层
12. **Flutter 核心页面** → UI 实现
13. **Flutter 多语言** → i18n 配置
14. **全链路联调** → 端到端测试
