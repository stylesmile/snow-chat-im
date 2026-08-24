# Snow Chat IM - 安全指南

## 认证与授权

### JWT Token 机制

**生成**:
```java
// JwtUtil.java
public static String createToken(Integer userId, String username) {
    return Jwts.builder()
        .subject(userId.toString())
        .claim("username", username)
        .issuedAt(new Date())
        .expiration(new Date(System.currentTimeMillis() + 7*24*60*60*1000)) // 7天
        .signWith(key)
        .compact();
}
```

**验证**:
```java
// AuthFilter.java
Integer userId = JwtUtil.getUserId(token);
if (userId == null) {
    sendUnauthorized(response); // 401
    return;
}
request.setAttribute("currentUserId", userId);
```

### 白名单接口（无需认证）
- `/chat/user/login` - 登录
- `/chat/user/register` - 注册
- `/chat/user/send/email/code` - 发送验证码
- `/chat/user/verify/code` - 验证验证码
- `/chat/user/reset/password` - 重置密码

---

## 密码安全

### 存储
- 使用 MD5 哈希存储密码
- 注：MD5 不够安全，建议升级为 BCrypt

```java
// 当前实现
String hashedPassword = SecureUtil.md5(password);
```

### 建议改进
```java
// 推荐: BCrypt
String hashedPassword = BCrypt.hashpw(password, BCrypt.gensalt());
boolean matches = BCrypt.checkpw(password, hashedUser.getPassword());
```

---

## 输入验证

### 消息类型白名单
```java
// ChatMessageController.java
private static final Set<String> ALLOWED_MESSAGE_TYPES = Set.of(
    "text", "image", "video", "file", "self", "recall"
);

if (!ALLOWED_MESSAGE_TYPES.contains(body.getType())) {
    return Result.failMessage("非法的消息类型");
}
```

### SQL注入防护
- 使用 MyBatis-Plus 参数化查询
- 禁止拼接 SQL 字符串

```java
// 正确做法
lambdaQuery().eq(ChatUser::getUsername, username)

// 错误做法（禁止）
"SELECT * FROM chat_user WHERE username = '" + username + "'"
```

---

## 敏感数据保护

### 日志脱敏
- 不记录密码、Token、完整邮箱
- 记录操作日志时脱敏处理

### 传输加密
- 生产环境必须使用 HTTPS
- MQTT 考虑启用 TLS

```yaml
# application-prod.yml
mqtt:
  client:
    ssl:
      enabled: true
```

---

## 速率限制

### 验证码发送频率
```java
// ChatVerifyCodeServiceImpl.java
// 建议: 同一邮箱60秒内只能发送一次
```

### 登录失败锁定
- 建议实现: 连续5次失败锁定15分钟

---

## XSS防护

### 输入过滤
```java
// 对用户输入进行HTML转义
String safeContent = StringEscapeUtils.escapeHtml4(userInput);
```

### 输出编码
- 前端渲染时避免直接使用用户输入

---

## 文件上传安全

### 文件类型校验
```java
// FileController.java
private static final Set<String> ALLOWED_TYPES = Set.of(
    "image/jpeg", "image/png", "image/gif",
    "video/mp4", "application/pdf"
);
```

### 文件大小限制
```yaml
spring:
  servlet:
    multipart:
      max-file-size: 10MB
      max-request-size: 10MB
```

### 文件存储
- 使用 MinIO 对象存储
- 不直接存储到文件系统
- 使用 Pre-signed URL 访问

---

## CORS配置

```java
// 建议: 生产环境限制特定域名
@Configuration
public class CorsConfig {
    @Bean
    public CorsFilter corsFilter() {
        CorsConfiguration config = new CorsConfiguration();
        config.setAllowedOrigins(List.of("https://your-domain.com"));
        config.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE"));
        // ...
    }
}
```

---

## 会话管理

### Token 有效期
- 默认7天
- 建议实现刷新Token机制

### 登出处理
```java
// 当前: 客户端本地清除Token
// 建议: 服务端维护Token黑名单
```

---

## 安全清单

部署前检查:
- [ ] 使用 HTTPS
- [ ] 修改默认密码
- [ ] 启用防火墙
- [ ] 限制数据库访问IP
- [ ] 定期更新依赖
- [ ] 审查日志中的敏感信息
- [ ] 实施速率限制
- [ ] 配置CORS白名单
