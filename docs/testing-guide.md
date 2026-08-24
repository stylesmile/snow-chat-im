# Snow Chat IM - 测试指南

## 测试覆盖现状

### 后端测试
- 测试文件数: 31个
- 测试覆盖率: ~60%
- 主要覆盖: Service层、Controller层、MQTT、存储

### 前端测试
- 测试代码行数: 2869行
- 主要覆盖: Services、Providers、UI组件

---

## 运行测试

### 后端 (Maven)

```bash
# 运行所有测试
cd snow-chat-im-backend
mvn test

# 运行特定模块测试
mvn test -pl snow-im-api

# 运行特定类
mvn test -Dtest=ChatMessageServiceImplTest

# 跳过测试编译
mvn test -DskipTests=false
```

### 前端 (Flutter)

```bash
cd snow-chat-flutter

# 运行所有测试
flutter test

# 运行特定目录
flutter test test/services/

# 运行特定文件
flutter test test/services/chat_service_test.dart

# 查看覆盖率
flutter test --coverage
lcov --summary coverage/lcov.info
```

---

## 测试策略

### 后端测试层级

#### 1. 单元测试 (Unit Test)
```java
@Test
public void should_save_message_when_valid() {
    // Given
    ChatMessage message = new ChatMessage();
    message.setFromUserId(1L);
    message.setToUserId(2L);
    message.setType("text");
    message.setContent("Hello");
    
    // When
    chatMessageService.sendMessage(message);
    
    // Then
    verify(chatMessageMapper).insert(message);
}
```

#### 2. 集成测试 (Integration Test)
```java
@SpringBootTest
class ChatMessageControllerTest {
    @Autowired
    private ChatMessageService chatMessageService;
    
    @Test
    void should_return_messages_when_valid_params() {
        // 测试完整请求链路
    }
}
```

#### 3. Mock测试
```java
@ExtendWith(MockitoExtension.class)
class ChatFriendServiceImplTest {
    @Mock
    private ChatFriendMapper chatFriendMapper;
    
    @InjectMocks
    private ChatFriendServiceImpl chatFriendService;
    
    @Test
    void should_remove_friend_when_exists() {
        // 测试逻辑，不依赖数据库
    }
}
```

---

## 测试文件位置

### 后端
```
snow-im-api/src/test/java/com/stylesmile/chat/
├── controller/
│   ├── ChatFriendControllerTest.java
│   ├── ChatGroupControllerTest.java
│   ├── ChatMessageControllerTest.java
│   ├── ChatSessionControllerTest.java
│   ├── ChatUserControllerTest.java
│   └── FileControllerTest.java
├── service/impl/
│   ├── ChatFriendRequestServiceImplTest.java
│   ├── ChatFriendServiceImplTest.java
│   ├── ChatGroupMemberServiceImplTest.java
│   ├── ChatGroupServiceImplTest.java
│   ├── ChatSessionServiceImplTest.java
│   ├── ChatUserServiceImplTest.java
│   ├── FileStorageServiceImplTest.java
│   └── ChatMessageServiceImplTest.java
├── mqtt/
│   ├── MqttPushServiceTest.java
│   └── MqttTopicsTest.java
├── storage/
│   ├── InMemoryFileStorageTest.java
│   ├── MinioFileStorageTest.java
│   └── MinioPropertiesTest.java
└── entity/
    └── ChatSessionTest.java
```

### 前端
```
test/
├── services/
│   ├── auth_service_test.dart
│   ├── chat_service_test.dart
│   ├── contact_service_test.dart
│   ├── conversation_service_test.dart
│   ├── group_service_test.dart
│   └── profile_service_test.dart
├── providers/
│   └── auth_provider_test.dart
├── ui/
│   ├── screens/
│   │   ├── auth_screens_dark_test.dart
│   │   ├── main_tabs_dark_test.dart
│   │   └── profile_tab_test.dart
│   └── widgets/
│       └── chat_bubble_test.dart
└── core/
    ├── cache/
    │   └── message_cache_manager_test.dart
    ├── constants/
    │   └── ws_cmd_test.dart
    ├── theme/
    │   └── app_theme_test.dart
    └── utils/
        └── message_status_parser_test.dart
```

---

## TDD工作流

### 步骤1: 写失败测试 (RED)
```java
@Test
public void should_delete_friend_when_exists() {
    when(chatFriendMapper.selectOne(any())).thenReturn(existingFriend);
    
    chatFriendService.removeFriend(1L, 2L);
    
    verify(chatFriendMapper).deleteById(1L);
}
```

### 步骤2: 写最少实现 (GREEN)
```java
@Override
public void removeFriend(Long userId, Long friendId) {
    ChatFriend friend = chatFriendMapper.selectOne(
        new LambdaQueryWrapper<ChatFriend>()
            .eq(ChatFriend::getUserId, userId)
            .eq(ChatFriend::getFriendId, friendId)
    );
    if (friend != null) {
        chatFriendMapper.deleteById(friend.getId());
    }
}
```

### 步骤3: 重构 (REFACTOR)
- 提取公共逻辑
- 优化性能
- 保持测试通过

---

## 测试最佳实践

### 命名规范
```java
@Test
public void should_[expected_behavior]_when_[condition]() {
    // Given: 准备数据
    // When: 执行操作
    // Then: 验证结果
}
```

### 断言规范
```java
// 使用 Hamcrest 匹配器
assertThat(result, is(notNullValue()));
assertThat(result.size(), greaterThan(0));
assertThat(message.getContent(), equalTo("Hello"));
```

### 边界测试
```java
@Test
public void should_throw_exception_when_user_not_found() {
    when(chatUserMapper.selectById(999L)).thenReturn(null);
    
    assertThrows(RuntimeException.class, () -> {
        chatUserService.getUserById(999L);
    });
}
```

---

## 覆盖率目标

| 组件 | 最低 | 目标 |
|------|------|------|
| Service层 | 80% | 90% |
| Mapper层 | 70% | 85% |
| Entity | 90% | 95% |
| Utils | 95% | 100% |
| UI组件 | 70% | 80% |
| 整体 | 80% | 90% |
