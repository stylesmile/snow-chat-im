# Snow Chat IM - 消息流转文档

## 消息类型

| 类型 | 说明 | content格式 |
|------|------|-------------|
| text | 文本消息 | 纯文本 |
| image | 图片消息 | 图片URL |
| video | 视频消息 | 视频URL |
| file | 文件消息 | JSON: {"url":"...","name":"...","size":123} |
| self | 文件传输助手 | 任意内容 |
| recall | 撤回消息 | "[消息已撤回]" |

---

## 私聊消息流程

### 发送流程

```
┌─────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│ 发送方   │────>│ Flutter  │────>│ Spring   │────>│ MQTT     │
│ Client  │     │ Provider │     │ Boot     │     │ Broker   │
└─────────┘     └──────────┘     └──────────┘     └─────┬────┘
                                                        │
                                                        v
                                              ┌─────────────────┐
                                              │   接收方 Client │
                                              │   (MQTT订阅)   │
                                              └─────────────────┘
```

**步骤**:
1. 客户端调用 `ChatProvider.sendMessage()`
2. Flutter 通过 MQTT 发送消息到 `chat/user/{toUserId}`
3. 同时调用 REST API `POST /chat/message/send` 备份到数据库
4. 服务端接收请求，持久化消息到 MySQL
5. 服务端通过 MQTT 推送给接收方: `chat/user/{toUserId}`
6. 接收方客户端收到 MQTT 消息，更新本地 SQLite
7. 服务端向发送方推送回执: `MSG_RECEIPT_ACK (2007)`

### 消息状态流转

```
                    ┌──────────────┐
                    │  pending     │ ← 客户端本地状态
                    └──────┬───────┘
                           │
              调用 /send API
                           │
                           v
                    ┌──────────────┐
                    │server_received│ ← 服务端收到
                    └──────┬───────┘
                           │
              MQTT 推送成功
                           │
                           v
                    ┌──────────────┐
                    │ client_ack   │ ← 接收方已确认
                    └──────┬───────┘
                           │
              收到回执
                           │
                           v
                    ┌──────────────┐
                    │ delivered    │ ← 已送达
                    └──────────────┘
```

---

## 群聊消息流程

### 发送流程

```
┌─────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│ 发送方   │────>│ Flutter  │────>│ Spring   │────>│ MQTT     │
│ Client  │     │ Provider │     │ Boot     │     │ Broker   │
└─────────┘     └──────────┘     └──────────┘     └─────┬────┘
                                                        │
                          ┌─────────────────────────────┼─────────────────────────────┐
                          v                             v                             v
                   ┌──────────────┐           ┌──────────────┐           ┌──────────────┐
                   │ 成员A Client │           │ 成员B Client │           │ 成员C Client │
                   └──────────────┘           └──────────────┘           └──────────────┘
```

**步骤**:
1. 客户端发送消息到 `chat/group/{groupId}`
2. 服务端持久化消息
3. 服务端查询群成员列表
4. 服务端向每个在线成员推送消息
5. 为离线成员保存离线消息

---

## 离线消息处理

### 存储机制

```java
// ChatMessageServiceImpl.java
if (!mqttConnectStatusListener.isOnline(clientId(userId))) {
    saveOfflineMessage(userId, topic, cmd, data);
}
```

### 补推机制

**触发时机**:
- MQTT 重连成功
- 客户端进入聊天页面

**处理流程**:
```
客户端重连 ──> 发送 FETCH_UNDELIVERED (1014)
                    │
                    v
              服务端查询未推送消息
                    │
                    v
              推送 FETCH_UNDELIVERED_ACK (2008)
                    │
                    v
              客户端写入 SQLite
```

---

## 消息回执机制

### 客户端 → 服务端

```
接收方收到消息
    │
    v
发送 MSG_RECEIPT (1013) 到服务端
    │
    v
服务端更新 push_status = "delivered"
    │
    v
推送 MSG_RECEIPT_ACK (2007) 给发送方
```

### 状态追踪

| 状态 | 说明 | 触发时机 |
|------|------|----------|
| pending | 待发送 | 客户端本地 |
| server_received | 服务端已收到 | POST /send |
| client_ack | 接收方已确认 | MSG_RECEIPT |
| delivered | 已送达 | 更新DB后 |

---

## 会话管理

### 会话创建

```java
// ChatSessionServiceImpl.java
@Transactional
public ChatSession getOrCreateSession(Long userId, Long targetId, String targetType) {
    // 查询是否存在
    ChatSession session = baseMapper.selectOne(wrapper);
    if (session != null) return session;
    
    // 创建新会话
    session = new ChatSession();
    session.setUserId(userId);
    session.setTargetId(targetId);
    session.setTargetType(targetType);
    session.setUnreadCount(0);
    baseMapper.insert(session);
    return session;
}
```

### 未读数更新

```
收到新消息
    │
    v
查询会话
    │
    v
unread_count += 1
    │
    v
update last_msg, last_msg_time
```

### 清除未读数

```
客户端打开聊天
    │
    v
调用 /session/unread/clear
    │
    v
服务端清零 unread_count
```

---

## 消息撤回

### 流程

```
发送方点击撤回
    │
    v
POST /chat/message/recall
    │
    v
服务端更新消息:
  - content = "[消息已撤回]"
  - type = "recall"
    │
    v
推送撤回通知给所有相关方
  - 私聊: 发送方和接收方
  - 群聊: 所有成员
```

### 通知格式

```json
{
  "cmd": 2006,
  "data": {
    "messageId": 100,
    "fromUserId": 1,
    "toUserId": 2,
    "groupId": null,
    "type": "recall",
    "createTime": "2026-08-24T10:00:00"
  }
}
```
