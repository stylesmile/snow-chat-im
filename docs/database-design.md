# Snow Chat IM - 数据库设计文档

## 数据库概览

- **数据库名**: snow_chat_im
- **字符集**: utf8mb4
- **排序规则**: utf8mb4_general_ci
- **引擎**: InnoDB

---

## ER 关系图

```
┌─────────────┐     ┌──────────────────┐     ┌─────────────┐
│  chat_user  │────<│chat_friend_request│>────│ chat_user   │
└──────┬──────┘     └──────────────────┘     └──────┬──────┘
       │                                              │
       │     ┌─────────────┐     ┌─────────────┐      │
       └────>│ chat_friend │     │chat_session │<─────┘
             └─────────────┘     └─────────────┘
                   │                   │
                   │         ┌─────────┴─────────┐
                   │         │                   │
             ┌─────┴─────┐ ┌┴──────┐      ┌────┴────┐
             │chat_message│ │group │      │ message│
             └───────────┘ └───┬───┘      └─────────┘
                                 │
                          ┌──────┴──────┐
                          │chat_group   │
                          └──────┬──────┘
                                 │
                          ┌──────┴──────┐
                          │chat_group_  │
                          │   member    │
                          └─────────────┘
```

---

## 表结构详情

### 1. chat_user (用户表)

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | bigint | PK, AI | 主键 |
| username | varchar(64) | NOT NULL, UK | 用户名 |
| password | varchar(64) | NOT NULL | 密码(MD5) |
| nickname | varchar(64) | NOT NULL | 昵称 |
| email | varchar(128) | DEFAULT '' | 邮箱 |
| avatar | varchar(255) | DEFAULT '' | 头像 |
| signature | varchar(255) | DEFAULT '' | 签名 |
| status | varchar(20) | DEFAULT 'offline' | online/offline/busy |
| del_flag | int | DEFAULT 0 | 删除标志 |
| create_time | datetime | DEFAULT NOW | 创建时间 |
| update_time | datetime | DEFAULT NOW | 更新时间 |

**索引**: uk_username, idx_username, idx_email

---

### 2. chat_message (消息表)

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | bigint | PK, AI | 主键 |
| from_user_id | bigint | NOT NULL | 发送方ID |
| to_user_id | bigint | NULL | 接收方ID(私聊) |
| group_id | bigint | NULL | 群组ID(群聊) |
| type | varchar(20) | NOT NULL | text/image/video/file/self/recall |
| content | text | NOT NULL | 消息内容 |
| local_seq | int | DEFAULT 0 | 本地序列号 |
| status | varchar(20) | DEFAULT 'sent' | sent/reading/read/failed |
| push_status | varchar(20) | DEFAULT 'server_received' | pending/server_received/client_ack/delivered |
| create_time | datetime | DEFAULT NOW | 创建时间 |

**索引**: 无显式索引，按业务查询

---

### 3. chat_friend (好友关系表)

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | bigint | PK, AI | 主键 |
| user_id | bigint | NOT NULL | 用户ID |
| friend_id | bigint | NOT NULL | 好友ID |
| remark | varchar(100) | DEFAULT '' | 备注 |
| create_time | datetime | DEFAULT NOW | 创建时间 |

**索引**: uk_user_friend(user_id, friend_id)

---

### 4. chat_friend_request (好友请求表)

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | bigint | PK, AI | 主键 |
| from_user_id | bigint | NOT NULL | 发送方ID |
| to_user_id | bigint | NOT NULL | 接收方ID |
| status | varchar(20) | DEFAULT 'pending' | pending/accepted/rejected |
| remark | varchar(255) | DEFAULT '' | 备注 |
| create_time | datetime | DEFAULT NOW | 创建时间 |

**索引**: uk_from_to(from_user_id, to_user_id)

---

### 5. chat_group (群组表)

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | bigint | PK, AI | 主键 |
| name | varchar(128) | NOT NULL | 群名称 |
| avatar | varchar(255) | DEFAULT '' | 头像 |
| owner_id | int | NOT NULL | 群主ID |
| max_members | int | DEFAULT 500 | 最大成员数 |
| create_time | datetime | DEFAULT NOW | 创建时间 |
| update_time | datetime | DEFAULT NOW | 更新时间 |
| del_flag | int | DEFAULT 0 | 删除标志 |

---

### 6. chat_group_member (群成员表)

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | bigint | PK, AI | 主键 |
| group_id | bigint | NOT NULL | 群组ID |
| user_id | bigint | NOT NULL | 用户ID |
| role | varchar(20) | DEFAULT 'member' | admin/member |
| join_time | datetime | DEFAULT NOW | 加入时间 |
| mute | int | DEFAULT 0 | 是否禁言 |

**索引**: uk_group_user(group_id, user_id)

---

### 7. chat_session (会话表)

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | bigint | PK, AI | 主键 |
| user_id | bigint | NOT NULL | 用户ID |
| target_id | bigint | NOT NULL | 目标ID(好友ID或群ID) |
| target_type | varchar(20) | NOT NULL | friend/group/file_helper |
| last_msg | text | NULL | 最后消息内容 |
| last_msg_time | datetime | NULL | 最后消息时间 |
| unread_count | int | DEFAULT 0 | 未读数 |
| is_muted | int | DEFAULT 0 | 免打扰 |
| create_time | datetime | DEFAULT NOW | 创建时间 |
| update_time | datetime | DEFAULT NOW | 更新时间 |

**索引**: uk_user_target(user_id, target_id, target_type)

---

### 8. chat_offline_message (离线消息表)

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | bigint | PK, AI | 主键 |
| to_user_id | bigint | NOT NULL | 接收用户ID |
| topic | varchar(255) | NOT NULL | MQTT主题 |
| cmd | int | NOT NULL | 命令码 |
| payload | text | NOT NULL | 消息内容(JSON) |
| create_time | datetime | DEFAULT NOW | 创建时间 |

---

### 9. chat_verify_code (验证码表)

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | bigint | PK, AI | 主键 |
| email | varchar(128) | NOT NULL | 邮箱 |
| code | varchar(10) | NOT NULL | 验证码 |
| type | varchar(20) | DEFAULT 'register' | register/reset_password |
| expire_time | datetime | NOT NULL | 过期时间 |
| used | tinyint | DEFAULT 0 | 0=未使用 1=已使用 |
| create_time | datetime | DEFAULT NOW | 创建时间 |

**索引**: idx_email_type_used(email, type, used)

---

### 10. sys_* 系列表 (系统管理)

| 表名 | 说明 |
|------|------|
| sys_user | 系统用户 |
| sys_role | 角色 |
| sys_menu | 菜单 |
| sys_depart | 部门 |
| sys_dict | 字典 |
| log_login | 登录日志 |

---

## Flyway 迁移历史

| 版本 | 文件 | 说明 |
|------|------|------|
| V1 | init_snow_schema.sql | 系统管理表初始化 |
| V2 | init_chat_schema.sql | IM核心表初始化 |
| V3 | add_offline_message.sql | 添加离线消息表 |
| V4 | fix_local_seq_field_type.sql | 修复local_seq字段类型 |
| V5 | add_create_time_to_chat_session.sql | 会话表添加创建时间 |
| V6 | add_push_status_to_chat_message.sql | 消息表添加推送状态 |
| V7 | add_verify_code_table.sql | 添加验证码表 |
