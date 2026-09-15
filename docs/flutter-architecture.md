# Snow Chat IM - Flutter 前端架构文档

## 项目概览

- **框架**: Flutter 3.41+
- **语言**: Dart 3.2+
- **状态管理**: Provider
- **本地存储**: SQLite (sqflite)
- **网络**: Dio
- **实时通信**: MQTT (mqtt_client)
- **包数量**: ~20个依赖

---

## 目录结构

```
snow-chat-flutter/
├── lib/
│   ├── main.dart                 # 应用入口
│   ├── app.dart                  # 应用配置
│   ├── config/
│   │   └── config.dart           # 应用配置（API地址、MQTT参数）
│   ├── core/
│   │   ├── network/
│   │   │   ├── api_client.dart   # HTTP客户端（Dio封装）
│   │   │   └── mqtt_client.dart  # MQTT客户端
│   │   ├── database/
│   │   │   ├── database_helper.dart # SQLite数据库管理
│   │   │   └── tables.dart       # 表结构定义
│   │   ├── cache/
│   │   │   └── message_cache_manager.dart # 消息缓存
│   │   ├── constants/
│   │   │   ├── ws_cmd.dart       # WebSocket命令常量
│   │   │   └── api_constants.dart # API常量
│   │   ├── utils/
│   │   │   ├── message_utils.dart
│   │   │   ├── message_status_parser.dart
│   │   │   ├── date_utils.dart
│   │   │   ├── pinyin_helper.dart
│   │   │   └── ...
│   │   ├── theme/
│   │   │   └── app_theme.dart    # 主题配置
│   │   └── router/
│   │       └── app_router.dart   # 路由配置
│   ├── models/
│   │   ├── user_model.dart       # 用户模型
│   │   ├── message_model.dart    # 消息模型
│   │   ├── session_model.dart    # 会话模型
│   │   ├── friend_model.dart     # 好友模型
│   │   ├── group_model.dart      # 群组模型
│   │   └── upload_result.dart    # 上传结果
│   ├── services/
│   │   ├── auth_service.dart     # 认证服务
│   │   ├── chat_service.dart     # 聊天服务（消息、历史）
│   │   ├── contact_service.dart  # 通讯录服务
│   │   ├── conversation_service.dart # 会话服务
│   │   ├── group_service.dart    # 群组服务
│   │   └── profile_service.dart  # 个人资料服务
│   ├── providers/
│   │   ├── auth_provider.dart    # 认证状态管理
│   │   ├── chat_provider.dart    # 聊天状态管理
│   │   ├── settings_provider.dart # 设置状态管理
│   │   └── friend_request_provider.dart # 好友请求状态
│   ├── ui/
│   │   ├── screens/              # 页面（16个）
│   │   │   ├── home_screen.dart
│   │   │   ├── login_screen.dart
│   │   │   ├── register_screen.dart
│   │   │   ├── chat_detail_screen.dart
│   │   │   ├── chat_list_screen.dart
│   │   │   ├── chat_list_tab.dart
│   │   │   ├── contact_tab.dart
│   │   │   ├── profile_tab.dart
│   │   │   ├── profile_screen.dart
│   │   │   ├── group_screen.dart
│   │   │   ├── group_detail_screen.dart
│   │   │   ├── add_friend_screen.dart
│   │   │   ├── friend_request_screen.dart
│   │   │   ├── create_group_screen.dart
│   │   │   ├── forget_password_screen.dart
│   │   │   └── settings_screen.dart
│   │   └── widgets/              # 组件（5个）
│   │       ├── chat_bubble.dart
│   │       ├── message_bubble.dart
│   │       ├── avatar_widget.dart
│   │       ├── loading_widget.dart
│   │       └── empty_state_widget.dart
│   └── l10n/                     # 国际化
│       ├── zh.arb
│       ├── en.arb
│       ├── zh_TW.arb
│       ├── ja.arb
│       └── ko.arb
├── test/                         # 测试（2869行）
│   ├── services/
│   ├── providers/
│   ├── ui/
│   └── core/
└── assets/                       # 资源文件
    ├── images/
    ├── icons/
    └── svg/
```

---

## 核心模块

### 1. API 客户端 (ApiClient)

```dart
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient(String baseUrl) => _instance..init(baseUrl);
  
  late Dio _dio;
  String? _token;
  
  // 自动添加 Authorization header
  _dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      if (_token != null) {
        options.headers['Authorization'] = 'Bearer $_token';
      }
      return handler.next(options);
    },
  ));
}
```

### 2. MQTT 客户端 (MqttChatClient)

```dart
class MqttChatClient {
  MqttServerClient? _client;
  final MessageCallback? onMessage;
  final VoidCallback? onConnected;
  final VoidCallback? onDisconnected;
  final VoidCallback? onReconnected;
  
  // 自动重连机制
  client.autoReconnect = true;
  client.resubscribeOnAutoReconnect = true;
  
  // Topic 订阅
  void _subscribeAll(int userId) {
    _client?.subscribe('chat/user/$userId', MqttQos.atLeastOnce);
  }
}
```

### 3. 数据库 (DatabaseHelper)

```dart
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  
  // SQLite 数据库，3个表版本
  // local_messages, conversations, friends, groups, group_members, sessions
}
```

### 4. 状态管理 (Provider)

| Provider | 职责 |
|----------|------|
| AuthProvider | 登录状态、用户信息、Token管理 |
| ChatProvider | 消息列表、发送状态、未读数 |
| SettingsProvider | 应用设置（主题、通知） |
| FriendRequestProvider | 好友请求列表、发送状态 |

### 5. 服务层 (Services)

| 服务 | 职责 |
|------|------|
| AuthService | 登录、注册、登出 |
| ChatService | 消息发送、历史查询、撤回、已读 |
| ContactService | 通讯录管理、好友搜索 |
| ConversationService | 会话管理、未读数 |
| GroupService | 群组创建、成员管理 |
| ProfileService | 头像上传、资料更新 |

---

## 主要界面

### 认证流程
1. login_screen.dart - 登录页
2. register_screen.dart - 注册页
3. forget_password_screen.dart - 忘记密码

### 主界面
1. home_screen.dart - 主页（底部导航）
2. chat_list_tab.dart - 聊天列表
3. contact_tab.dart - 通讯录
4. profile_tab.dart - 个人中心

### 聊天功能
1. chat_detail_screen.dart - 聊天详情（核心界面）
2. chat_list_screen.dart - 会话列表

### 社交功能
1. add_friend_screen.dart - 添加好友
2. friend_request_screen.dart - 好友请求
3. group_screen.dart - 群组列表
4. group_detail_screen.dart - 群组详情
5. create_group_screen.dart - 创建群组

### 设置
1. profile_screen.dart - 个人资料
2. settings_screen.dart - 设置

---

## 国际化支持

支持语言：
- zh (简体中文)
- en (英语)
- zh_TW (繁体中文)
- ja (日语)
- ko (韩语)

---

## 本地存储策略

### SQLite 表结构

| 表名 | 用途 |
|------|------|
| local_messages | 本地消息缓存 |
| conversations | 会话信息 |
| local_friends | 好友列表 |
| local_groups | 群组信息 |
| group_members | 群成员 |
| sessions | 会话索引 |

### 消息状态机

```
sent → reading → read
             ↓
           failed
```

### 推送状态机

```
pending → server_received → client_ack → delivered
```
