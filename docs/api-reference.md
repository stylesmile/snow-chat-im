# Snow Chat IM - API 接口文档

## 认证机制

所有接口（除白名单外）需要 JWT Token 认证：
```
Authorization: Bearer {token}
```

白名单接口（无需认证）：
- POST /chat/user/login
- POST /chat/user/register
- POST /chat/user/send/email/code
- POST /chat/user/verify/code
- POST /chat/user/reset/password

---

## 用户接口 (/chat/user)

### 登录
```
POST /chat/user/login
Content-Type: application/json

{
  "username": "string",
  "password": "string"
}

Response:
{
  "code": "200",
  "data": {
    "token": "string",
    "user": { "id": 1, "username": "...", ... }
  }
}
```

### 注册
```
POST /chat/user/register
Content-Type: application/json

{
  "username": "string",
  "password": "string",
  "nickname": "string",
  "email": "string",
  "code": "string"
}

Response: { "code": "200", "data": { "token": "...", "user": {...} } }
```

### 获取当前用户信息
```
GET /chat/user/info
Authorization: Bearer {token}

Response: { "code": "200", "data": { user object } }
```

### 更新资料
```
PUT /chat/user/update
Authorization: Bearer {token}
Content-Type: application/json

{
  "nickname": "string",
  "avatar": "string",
  "signature": "string"
}
```

### 上传头像
```
POST /chat/user/avatar/upload
Authorization: Bearer {token}
Content-Type: multipart/form-data

Form: file (图片文件)

Response: { "code": "200", "data": { "key": "avatars/uuid.jpg", "url": "..." } }
```

### 搜索用户
```
GET /chat/user/search?keyword=xxx
Authorization: Bearer {token}

Response: { "code": "200", "data": [ { user objects } ] }
```

### 发送验证码
```
GET /chat/user/send/email/code?email=xxx&type=register
Authorization: Bearer {token}
```

### 验证验证码
```
POST /chat/user/verify/code
Content-Type: application/json

{
  "email": "string",
  "code": "string",
  "type": "register|reset_password"
}
```

### 重置密码
```
POST /chat/user/reset/password
Content-Type: application/json

{
  "email": "string",
  "code": "string",
  "newPassword": "string"
}
```

---

## 消息接口 (/chat/message)

### 发送消息
```
POST /chat/message/send
Authorization: Bearer {token}
Content-Type: application/json

{
  "fromUserId": 1,
  "toUserId": 2,
  "groupId": null,
  "type": "text",
  "content": "Hello",
  "localSeq": 123
}

type 可选值: text, image, video, file, self, recall
```

### 发送文件传输助手消息
```
POST /chat/message/send/file-helper
Authorization: Bearer {token}
Content-Type: application/json

{
  "fromUserId": 1,
  "content": "Hello",
  "localSeq": 123
}
```

### 获取历史消息（分页）
```
GET /chat/message/history?userId=1&targetId=2&type=friend&page=1&size=20
Authorization: Bearer {token}
```

### 获取历史消息（游标分页）
```
GET /chat/message/history/cursor?userId=1&targetId=2&type=friend&beforeMessageId=100&size=20
Authorization: Bearer {token}
```

### 撤回消息
```
POST /chat/message/recall
Authorization: Bearer {token}
Content-Type: application/json

{
  "userId": 1,
  "messageId": 100
}
```

### 标记已读
```
POST /chat/message/read
Authorization: Bearer {token}
Content-Type: application/json

{
  "userId": 1,
  "targetId": 2,
  "targetType": "friend"
}
```

### 发送消息回执
```
POST /chat/message/receipt
Authorization: Bearer {token}
Content-Type: application/json

{
  "messageId": 100,
  "userId": 2
}
```

### 获取未推送消息
```
POST /chat/message/undelivered
Authorization: Bearer {token}
Content-Type: application/json

{
  "userId": 1,
  "targetId": 2,
  "targetType": "friend"
}

Response: [ { message objects } ]
```

### 同步未推送消息（MQTT重连）
```
POST /chat/message/sync
Authorization: Bearer {token}
Content-Type: application/json

{
  "userId": 1,
  "targetId": 2,
  "targetType": "friend"
}
```

---

## 好友接口 (/chat/friend)

### 获取好友列表
```
GET /chat/friend/list?userId=1
Authorization: Bearer {token}

Response: [ { id, userId, friendId, remark, nickname, avatar, status } ]
```

### 发送好友请求
```
POST /chat/friend/request
Authorization: Bearer {token}
Content-Type: application/json

{
  "fromUserId": 1,
  "toUserId": 2,
  "remark": "你好"
}
```

### 处理好友请求
```
POST /chat/friend/handle
Authorization: Bearer {token}
Content-Type: application/json

{
  "fromUserId": 1,
  "toUserId": 2,
  "accept": true
}
```

### 获取待处理请求
```
GET /chat/friend/pending?toUserId=2
Authorization: Bearer {token}
```

### 获取已发送请求
```
GET /chat/friend/sent?fromUserId=1
Authorization: Bearer {token}
```

### 删除好友
```
DELETE /chat/friend/{userId}/{friendId}
Authorization: Bearer {token}
```

---

## 群组接口 (/chat/group)

### 创建群组
```
POST /chat/group/create
Authorization: Bearer {token}
Content-Type: application/json

{
  "ownerId": 1,
  "name": "群组名称",
  "avatar": "string",
  "maxMembers": 500,
  "memberIds": "2,3,4"
}

Response: { "code": "200", "data": 100 }
```

### 获取群组信息
```
GET /chat/group/{groupId}
Authorization: Bearer {token}
```

### 获取用户所在群组
```
GET /chat/group/list?userId=1
Authorization: Bearer {token}
```

### 获取群成员
```
GET /chat/group/members/{groupId}
Authorization: Bearer {token}
```

### 添加群成员
```
POST /chat/group/members/add
Authorization: Bearer {token}
Content-Type: application/json

{
  "groupId": 100,
  "userIds": [2, 3]
}
```

### 移除群成员
```
POST /chat/group/members/remove
Authorization: Bearer {token}
Content-Type: application/json

{
  "groupId": 100,
  "userIds": [2]
}
```

---

## 会话接口 (/chat/session)

### 获取会话列表
```
GET /chat/session/list?userId=1
Authorization: Bearer {token}
```

### 清除未读数
```
POST /chat/session/unread/clear
Authorization: Bearer {token}
Content-Type: application/json

{
  "userId": 1,
  "targetId": 2
}
```

---

## 文件接口 (/chat/file)

### 上传文件
```
POST /chat/file/upload
Authorization: Bearer {token}
Content-Type: multipart/form-data

Form: file (文件)

Response: { "code": "200", "data": { "url": "..." } }
```

### 下载文件
```
GET /chat/file/{fileName}
Authorization: Bearer {token}
```

---

## MQTT 协议

### Topic 格式
- 私聊: `chat/user/{userId}`
- 群聊: `chat/group/{groupId}`

### 命令码

**客户端 → 服务端 (1001-1099)**
| 命令 | 值 | 说明 |
|------|-----|------|
| LOGIN | 1001 | 登录 |
| MSG_TEXT | 1002 | 文本消息 |
| MSG_IMAGE | 1003 | 图片消息 |
| MSG_VIDEO | 1004 | 视频消息 |
| FRIEND_ADD_REQ | 1006 | 好友请求 |
| GROUP_CREATE | 1009 | 创建群组 |
| READ_ACK | 1012 | 已读回执 |
| MSG_RECEIPT | 1013 | 消息回执 |
| FETCH_UNDELIVERED | 1014 | 请求未推送消息 |

**服务端 → 客户端 (2001-2099)**
| 命令 | 值 | 说明 |
|------|-----|------|
| MSG_PUSH | 2001 | 消息推送 |
| FRIEND_REQ_NOTIFY | 2002 | 好友请求通知 |
| ONLINE_STATUS | 2003 | 在线状态 |
| GROUP_NOTIFY | 2004 | 群组通知 |
| MSG_ACK | 2005 | 消息确认 |
| FRIEND_ACCEPTED | 2006 | 好友已接受 |
| MSG_RECEIPT_ACK | 2007 | 回执确认 |
| FETCH_UNDELIVERED_ACK | 2008 | 未推送消息补推 |

### 消息格式
```json
{
  "cmd": 2001,
  "seq": "snowflake_id",
  "data": {
    "id": 100,
    "fromUserId": 1,
    "toUserId": 2,
    "groupId": null,
    "type": "text",
    "content": "Hello",
    "localSeq": 123,
    "createTime": "2026-08-24T10:00:00"
  }
}
```
