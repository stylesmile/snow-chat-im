# Snow Chat IM - Agent开发规范

## 项目概述

这是一个 **Snow Chat IM** 实时通讯系统，技术栈包括：
- **后端**: Java SpringBoot 2, MyBatis-Plus, MySQL
- **前端**: Flutter (Dart)
- **通信协议**: WebSocket, MQTT

## Agent角色

作为项目的AI开发助手，你的职责是：

1. **保持高质量代码** - 通过严格的TDD实践
2. **编写自文档化代码** - 提供全面的内联注释
3. **确保安全性** - 在所有通信和数据处理中
4. **保持向后兼容性** - 修改现有功能时

---

## 测试驱动开发（TDD）要求

### 强制性TDD工作流程

所有代码更改必须遵循这个严格的工作流程：

```
1. 🔴 RED    - 先写失败的测试
2. 🟢 GREEN  - 写最少的代码让测试通过
3. 🔵 REFACTOR - 重构代码，保持测试通过
```

### TDD规则

- **没有测试就不写实现** - 每个功能、bug修复、重构都必须先写测试
- **测试每个公共方法** - 公共API 100%覆盖率
- **测试边界情况** - 空值输入、空值、边界条件、错误场景
- **测试集成点** - 数据库操作、API调用、MQTT连接
- **提交前运行测试** - 所有测试必须通过才能提交代码
- **立即修复失败的测试** - 如果测试失败，立即停止所有工作并修复

### 测试框架

**后端（Java）：**
```java
// 示例：测试消息仓库
@Test
public void should_save_message_when_valid_message_provided() {
    // 准备 - 准备测试数据
    Message message = new Message();
    message.setContent("Hello World");
    message.setSenderId(1L);
    message.setReceiverId(2L);

    // 执行 - 运行被测试的方法
    Message savedMessage = messageRepository.save(message);

    // 验证 - 检查结果
    assertNotNull(savedMessage);
    assertEquals("Hello World", savedMessage.getContent());
    assertNotNull(savedMessage.getCreatedAt());
}
```

**前端（Dart/Flutter）：**
```dart
// 示例：测试消息模型
test('should create message from JSON correctly', () {
  // 准备 - 准备测试数据
  final json = {
    'id': 1,
    'content': 'Hello',
    'senderId': 100,
    'timestamp': DateTime.now().toIso8601String()
  };

  // 执行 - 运行被测试的方法
  final message = Message.fromJson(json);

  // 验证 - 检查结果
  expect(message.id, equals(1));
  expect(message.content, equals('Hello'));
  expect(message.senderId, equals(100));
});
```

### 测试覆盖率要求

| 组件 | 最低覆盖率 | 目标覆盖率 |
|------|----------|----------|
| 服务层 | 80% | 90% |
| 仓库层 | 70% | 85% |
| 模型/实体 | 90% | 95% |
| 工具函数 | 95% | 100% |
| UI组件 | 70% | 80% |
| 项目整体 | 80% | 90% |

---

## 代码注释要求

### 核心理念

> **"代码的阅读频率远高于编写频率"**

每一行代码都必须能脱离外部文档独立理解。

### 注释规则

1. **为每行代码添加注释** - 特别是复杂逻辑、算法和业务规则
2. **注释WHY，而不仅仅是WHAT** - 解释实现选择背后的原因
3. **保持注释更新** - 过时的注释比没有注释更糟糕
4. **使用清晰简单的语言** - 尽量避免技术术语
5. **在代码块前注释** - 使用块注释描述后续内容

### 注释格式

**Java后端：**
```java
// 将新消息持久化到数据库的方法
// 验证消息内容，添加元数据，并保存到仓库
// 如果消息为null或空，抛出IllegalArgumentException
public Message saveMessage(Message message) {
    // 在处理前验证消息不为null
    if (message == null) {
        // 抛出异常以防止下游出现空指针问题
        throw new IllegalArgumentException("消息不能为null");
    }

    // 设置创建时间为当前时间
    // 这确保了系统中时间跟踪的一致性
    message.setCreatedAt(LocalDateTime.now());

    // 默认设置消息状态为PENDING
    // 状态将在消息发送给接收者后变为DELIVERED
    message.setStatus(MessageStatus.PENDING);

    // 使用仓库层将消息持久化到数据库
    // 仓库处理所有数据库特定的操作
    return messageRepository.save(message);
}
```

**Dart/Flutter前端：**
```dart
/// 通过MQTT代理向接收者发送新消息
///
/// 此方法执行以下步骤：
/// 1. 验证消息内容不为空
/// 2. 将消息序列化为JSON格式
/// 3. 发布到特定接收者的MQTT主题
/// 4. 更新本地消息状态为DELIVERED
///
/// 如果消息无法发送，抛出[MessageException]
///
/// @param message 要发送的消息
/// @param receiverId 接收者的唯一标识符
/// @return 完成时返回Future
Future<void> sendMessage(Message message, String receiverId) async {
    // 步骤1：在尝试发送前验证消息内容
    // 空消息不应在系统中传输
    if (message.content.isEmpty) {
        // 抛出带有清晰错误信息的异常，便于调试
        throw MessageException('消息内容不能为空');
    }

    // 步骤2：将消息对象转换为JSON格式
    // JSON是MQTT消息传输的标准格式
    final jsonPayload = message.toJson();

    // 步骤3：基于接收者ID定义MQTT主题
    // 主题格式：/user/{receiverId}/messages
    // 这允许针对特定用户的消息投递
    final topic = '/user/$receiverId/messages';

    // 步骤4：将消息发布到MQTT代理
    // 代理将处理路由到正确的接收者
    await mqttClient.publish(topic, jsonPayload);

    // 步骤5：更新本地消息状态以反映成功传输
    // 此状态将在下一个同步周期与数据库同步
    message.status = MessageStatus.DELIVERED;
}
```

### 注释位置

**必须注释的地方：**
- ✅ 类声明及其用途
- ✅ 公共方法声明、参数和返回值
- ✅ 复杂算法或业务逻辑
- ✅ 数据库查询及其预期结果
- ✅ API端点及其请求/响应格式
- ✅ 具有复杂条件的条件逻辑和循环
- ✅ 错误处理和回退场景
- ✅ 配置值及其含义
- ✅ 数据转换和映射
- ✅ 安全敏感操作（认证、加密）

**不需要注释的地方：**
- ❌ 明显的代码（例如：`int count = 0;` 或 `i++`）
- ❌ 没有上下文的变量声明
- ❌ 简单的getter/setter方法
- ❌ 通过清晰命名就能自解释的代码

---

## 安全指南

### 关键安全实践

1. **不暴露敏感数据** - 不记录密码、令牌或PII
2. **验证所有输入** - 将所有用户输入视为不可信
3. **使用参数化查询** - 防止SQL注入攻击
4. **加密敏感数据** - 对密码和令牌使用适当的加密
5. **实施速率限制** - 防止滥用和DoS攻击
6. **清理用户生成的内容** - 防止XSS攻击
7. **使用HTTPS/TLS** - 加密所有通信
8. **遵循最小权限原则** - 仅授予必要的最低权限

---

## 代码组织

### 目录结构

```
snow-chat-im-backend/
├── src/main/java/com/stylesmile/chat/
│   ├── config/          # 配置类
│   ├── controller/      # REST API端点
│   ├── service/         # 业务逻辑层
│   ├── repository/      # 数据访问层
│   ├── model/           # 数据模型和实体
│   ├── dto/             # 数据传输对象
│   ├── security/        # 安全配置
│   ├── mqtt/            # MQTT集成
│   ├── websocket/       # WebSocket处理
│   └── util/            # 工具函数
└── src/test/java/       # 测试文件（镜像main结构）

snow-chat-flutter/
├── lib/
│   ├── core/            # 核心工具和基类
│   ├── models/          # 数据模型
│   ├── services/        # 业务逻辑服务
│   ├── repositories/    # 数据仓库
│   ├── screens/         # UI屏幕
│   ├── widgets/         # 可复用UI组件
│   ├── providers/       # 状态管理
│   └── utils/           # 工具函数
└── test/                # 测试文件（镜像lib结构）
```

---

## Git工作流程

### 提交信息格式

```
<类型>(<范围>): <主题>

<可选正文>

<可选脚注>
```

**类型：**
- `feat`: 新功能
- `fix`: Bug修复
- `refactor`: 代码重构（无功能变更）
- `test`: 添加或更新测试
- `docs`: 文档变更
- `style`: 格式化（无代码变更）
- `perf`: 性能改进
- `chore`: 维护任务

**示例：**
```
feat(message): 通过MQTT添加实时消息投递

- 实现MQTT客户端进行消息发布
- 添加消息序列化/反序列化
- 包含连接失败的错误处理

Closes #123
```

```
fix(chat): 解决消息重复问题

- 在保存消息前添加去重检查
- 更新仓库以处理重复消息ID
- 添加测试验证去重逻辑

Fixes #456
```

---

## 代码审查清单

提交代码审查前，请验证：

- [ ] 所有测试通过
- [ ] 测试覆盖率达到最低要求（80%）
- [ ] 代码有适当的注释（复杂逻辑的每一行）
- [ ] 无硬编码值（使用常量或配置）
- [ ] 无安全漏洞
- [ ] 错误处理全面
- [ ] 代码遵循命名规范
- [ ] 无代码重复
- [ ] 无未使用的导入或变量
- [ ] 文档已更新

---

## 性能指南

1. **数据库查询** - 使用索引，避免N+1查询，实施分页
2. **缓存** - 使用Spring Cache缓存频繁访问的数据
3. **消息处理** - 对非关键操作使用异步处理
4. **内存管理** - 避免内存泄漏，正确关闭资源
5. **连接池** - 为数据库和MQTT连接使用连接池

---

## 文档标准

### 内联文档

- **每个类**必须有注释说明其用途
- **每个公共方法**必须有注释说明其功能、参数和返回值
- **复杂算法**必须有逐步说明
- **业务规则**必须有示例文档

### 外部文档

- 保持README.md更新，包含设置说明
- 用请求/响应示例文档化API端点
- 维护架构图
- 保持部署指南最新

---

## 紧急程序

### 测试失败时

1. **立即停止**所有其他工作
2. 确定什么变更导致了失败
3. 修复测试或代码（取决于哪个是正确的）
4. 运行所有测试确保没有破坏其他功能
5. 只有在此之后才能继续其他任务

### 发现安全问题时

1. **立即停止**并记录问题
2. 评估严重性和影响
3. 立即修复问题
4. 审查整个代码库以查找类似问题
5. 更新安全文档

---

## 总结

**核心原则：**
1. TDD不是可选的 - 它是强制性的
2. 每一行代码都必须有文档
3. 安全性是首要考虑
4. 测试必须通过才能提交代码
5. 代码必须清洁、可读、可维护

**记住：** 目标是创建一个健壮、安全、可维护的消息系统，能够随时间扩展和演进。

---

*最后更新：2026-07-20*
*版本：1.0.0*
