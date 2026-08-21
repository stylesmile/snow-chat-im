# 微信风格个人中心 + MinIO 集成 + 头像设置 实施计划

> 执行模式：TDD（测试先行）· 每个小需求一次 commit · 不 push
> Git 作者：`mmm <mm@m.m>`（来自 `.git/config` 解析后的全局配置，本地 config 未显式设置 user 段）
> 参考样板：`co-talk-im-master/co-talk-java-backend/.../storage/`（AWS S3 SDK v2 风格）

---

## 一、当前状态分析（基于 Phase 1 探索）

### 已有基础
| 项 | 状态 |
|---|---|
| 后端 `snow-im-api` | Spring Boot 3.5.14 / Java 17 / Maven 多模块，含 Flyway V1~V6、MyBatis-Plus、mica-mqtt |
| 后端 `ChatUserController` | 已有 `PUT /chat/user/profile`（`@RequestParam`，与前端 JSON body 不匹配 — bug）和 `GET /chat/user/info/{userId}` |
| 后端 `ChatUser` 实体 | 已有 `avatar` 字段（String，存 URL/key） |
| 后端 MinIO 集成 | **完全未集成**（主后端目录零命中） |
| 前端 `profile_tab.dart` | HomeScreen Tab 使用中；头像仅 `Icons.person` 占位，编辑按钮 `onPressed: () {}` 空实现 |
| 前端 `profile_screen.dart` | 与 `profile_tab.dart` 几乎重复的死代码（home_screen 未引用），用户要求同步改造 |
| 前端 `ProfileService` | 已有 `getUserProfile` / `updateProfile`，后者调用方式与后端不匹配；无上传方法 |
| 前端 `AuthProvider` | 已有 `_avatar` 字段 + SharedPreferences 持久化；无主动更新头像方法 |
| 前端 `AvatarWidget` | 已支持 `imageUrl` + `cached_network_image` 加载 |
| 前端依赖 | `image_picker ^1.0.0` 已在 pubspec |
| 测试框架 | 后端 JUnit5 + Mockito；前端 flutter_test + mockito + http_mock_adapter |
| 现有测试 | `profile_service_test.dart`、`ChatUserControllerTest.java` 等已存在 |

### 关键决策
1. **MinIO bucket 私有 + Pre-signed URL**（用户选择）：
   - DB 的 `ChatUser.avatar` 存**对象 key**（如 `avatars/uuid.jpg`），不存 URL
   - 后端 `GET /chat/user/info/{userId}` 返回前用 `FileStorage.generatePresignedUrl(key, 60*24*7)` 转换为 7 天有效的 pre-signed URL
   - 旧数据（非 `avatars/` 前缀的字符串）按原样返回，保证向后兼容
2. **MinIO 部署**：在 `snow-chat-im-backend/` 根目录新增 `docker-compose.yml`，启动 MinIO（9000 API / 9001 Console，默认 `minioadmin/minioadmin`，bucket `snow-chat`）。后端 `application-dev.yml` 加 `minio` 配置块，可通过环境变量覆盖。
3. **重复页面处理**：`profile_screen.dart` 与 `profile_tab.dart` 都同步改造为微信风格（用户要求）。
4. **后端 `updateProfile` 修复**：改为 `@RequestBody UpdateProfileDTO`（与前端现有 JSON 调用对齐），保留字段可选更新语义。
5. **`FileStorage` 端口模式**：移植 co-talk 的 `FileStorage` 接口 + `MinioFileStorage` + `InMemoryFileStorage` 双实现，`minio.enabled=false` 时降级到内存实现（保证测试和未启用 MinIO 的环境可用）。

---

## 二、提交计划（7 次 commit，每次 TDD 先行）

> 每次提交前必跑：后端 `mvn -pl snow-im-api test`，前端 `flutter test` + `flutter analyze`。
> 不执行 `git push`。每次 commit 使用 `git -c user.name=mmm -c user.email=mm@m.m commit` 显式指定（虽然 git config 已解析到此值，但显式更稳）。

---

### Commit 1：后端 — MinIO 基础设施（TDD）

**目标**：把 MinIO 客户端 Bean、属性类、`FileStorage` 端口与双实现接入 Spring，可在 `minio.enabled=false` 时降级。

**TDD 测试先行**（先写测试，看着失败，再写实现）：
- `snow-im-api/src/test/java/com/stylesmile/chat/storage/MinioPropertiesTest.java`
  - 验证默认 region=`us-east-1`、bucket=`snow-chat`、enabled=false 时的行为
- `snow-im-api/src/test/java/com/stylesmile/chat/storage/InMemoryFileStorageTest.java`
  - upload 返回 key 本身、exists 查内存 Map、delete 移除、generatePresignedUrl 返回 `memory://bucket/key`
- `snow-im-api/src/test/java/com/stylesmile/chat/storage/MinioFileStorageTest.java`
  - 用 Mockito mock `S3Client` + `S3Presigner`，验证：
    - bucket 不存在时调用 `createBucket`
    - `upload` 调用 `putObject` 并返回 key（私有策略下返回 key，不返回 URL）
    - `generatePresignedUrl` 调用 `presignGetObject` 并返回字符串

**实现文件**：
- `snow-im-api/pom.xml` — 添加 `software.amazon.awssdk:s3:2.30.0`（直接版本，与 co-talk 一致，避免引入 BOM 复杂度）
- `snow-im-api/src/main/java/com/stylesmile/chat/storage/FileStorage.java` — 接口（upload/delete/exists/generatePresignedUrl）
- `snow-im-api/src/main/java/com/stylesmile/chat/storage/MinioProperties.java` — `@ConfigurationProperties(prefix="minio")` record
- `snow-im-api/src/main/java/com/stylesmile/chat/storage/MinioConfig.java` — `@ConditionalOnProperty(name="minio.enabled", havingValue="true")` + `S3Client`/`S3Presigner` Bean
- `snow-im-api/src/main/java/com/stylesmile/chat/storage/MinioFileStorage.java` — 实现，启动时 ensureBucketExists（不设公共读策略）
- `snow-im-api/src/main/java/com/stylesmile/chat/storage/InMemoryFileStorage.java` — `@ConditionalOnProperty(name="minio.enabled", havingValue="false", matchIfMissing=true)` 降级实现
- `snow-im-api/src/main/java/com/stylesmile/chat/ImApplication.java` — 加 `@EnableConfigurationProperties(MinioProperties.class)`
- `snow-im-api/src/main/resources/application-dev.yml` — 末尾追加 `minio:` 配置块（enabled/accessKey/secretKey/endpoint/bucket/publicUrl）
- `snow-chat-im-backend/docker-compose.yml` — 新增 MinIO 服务定义（image: minio/minio:latest，ports 9000:9000/9001:9001，command server /data --console-address ":9001"）

**关键设计**：私有策略下，`MinioFileStorage.upload()` 返回对象 key（而非 URL）；URL 通过 `generatePresignedUrl()` 单独获取。这与 co-talk 原版（publicUrl 优先）不同，但符合本次"私有 + Pre-signed"决策。

---

### Commit 2：后端 — 文件上传 API（TDD）

**目标**：暴露 `POST /file/upload` multipart 接口，返回 `{key, url}` 供前端头像上传使用。

**TDD 测试先行**：
- `snow-im-api/src/test/java/com/stylesmile/chat/service/impl/FileStorageServiceImplTest.java`
  - mock `FileStorage`，验证 `uploadAndSign(MultipartFile)` 依次调用 `upload` → `generatePresignedUrl`，返回 `UploadResult(key, url)`
  - 文件名以 `avatars/{uuid}.{ext}` 形式生成
- `snow-im-api/src/test/java/com/stylesmile/chat/controller/FileControllerTest.java`
  - mock `FileStorageService`，用 `MockMultipartFile` 调 `upload`，断言响应 `code=200`、`data.key` 与 `data.url` 非空
  - 空文件返回错误码

**实现文件**：
- `snow-im-api/src/main/java/com/stylesmile/chat/service/FileStorageService.java` — 接口
- `snow-im-api/src/main/java/com/stylesmile/chat/service/impl/FileStorageServiceImpl.java` — 实现：UUID 生成 key、调 `FileStorage.upload` + `generatePresignedUrl(7天)`
- `snow-im-api/src/main/java/com/stylesmile/chat/controller/FileController.java` — `@RestController @RequestMapping("/file")`，`POST /upload` 接 `@RequestParam("file") MultipartFile`
- `snow-im-api/src/main/java/com/stylesmile/chat/dto/UploadResult.java` — `{String key, String url}` record

---

### Commit 3：后端 — `updateProfile` 修复 + `info` 端点头像 URL 转换（TDD）

**目标**：修复 `updateProfile` 与前端 JSON body 不匹配的 bug；让 `info` 返回的 `avatar` 字段是 pre-signed URL，DB 里仍存 key。

**TDD 测试先行**（修改 `ChatUserControllerTest.java`）：
- 现有 `updatesOnlyProvidedProfileFields` 改用 `UpdateProfileDTO` 入参
- 新增 `convertsAvatarKeyToPresignedUrl` 测试：mock `FileStorage.generatePresignedUrl("avatars/x.jpg", 7*24*60)` 返回 `"https://presigned..."`，断言 `info(4)` 返回的 `avatar` 字段为该 URL
- 新增 `passesThroughLegacyAvatar` 测试：avatar 为非 `avatars/` 前缀的旧字符串时原样返回

**实现文件**：
- `snow-im-api/src/main/java/com/stylesmile/chat/controller/ChatUserController.java`
  - 新增内部静态类 `UpdateProfileDTO { Integer userId; String nickname; String avatar; String signature; }`
  - `updateProfile` 改为 `@PutMapping("/profile") public Result<Void> updateProfile(@RequestBody UpdateProfileDTO dto)`
  - `info` 端点注入 `FileStorage`：返回前若 `avatar` 以 `avatars/` 开头，调 `generatePresignedUrl` 转换
- `snow-im-api/src/test/java/com/stylesmile/chat/controller/ChatUserControllerTest.java` — 同步更新

---

### Commit 4：前端 — `ProfileService` 扩展上传能力（TDD）

**目标**：前端 Service 层支持头像上传，并对齐后端 `@RequestBody` 调用方式。

**TDD 测试先行**（修改 `test/services/profile_service_test.dart`）：
- `ProfileService.updateProfile` 旧测试断言 PUT 请求体为 JSON（与后端新 DTO 对齐）
- 新增 `uploadAvatar` 测试组：
  - 成功时返回 `UploadResult(key, url)` 对象
  - 网络异常时返回 null
  - 验证请求 `Content-Type` 为 `multipart/form-data`，字段名 `file`
- 新增 `refreshProfile(userId)` 测试（包装 `getUserProfile`）

**实现文件**：
- `snow-chat-flutter/lib/services/profile_service.dart`
  - `updateProfile` 改为发送 JSON body（`data: {'userId':..., 'nickname':..., 'avatar':..., 'signature':...}`）
  - 新增 `Future<UploadResult?> uploadAvatar(File imageFile)`：用 `FormData.from` + `MultipartFile.fromBytes` 上传到 `POST /file/upload`，解析返回 `{key, url}`
  - 新增 `Future<Map<String,dynamic>?> refreshProfile(int userId)` ≡ `getUserProfile`
- `snow-chat-flutter/lib/models/upload_result.dart` — 新增简单数据类 `{String key, String url}`（带 `fromJson`）

---

### Commit 5：前端 — `AuthProvider` 头像更新方法（TDD）

**目标**：暴露公开方法让 UI 层在头像上传成功后更新本地状态。

**TDD 测试先行**（新增 `test/providers/auth_provider_test.dart`）：
- `updateAvatar` 调用后，`auth.avatar` 立即返回新值
- `updateAvatar` 触发 `notifyListeners`（用 listener 计数验证）
- `updateAvatar` 后 `SharedPreferences` 中 `avatar` 键被更新（用 `SharedPreferences.setMockInitialValues({})`）
- `updateNickname` 同样测试

**实现文件**：
- `snow-chat-flutter/lib/providers/auth_provider.dart`
  - 新增 `Future<void> updateAvatar(String newAvatarUrl)`：设 `_avatar` → `_saveAuthState()` → `notifyListeners()`
  - 新增 `Future<void> updateNickname(String newNickname)`：同上
  - （可选）`init()` 末尾若 `isLoggedIn` 且 `_userId != null`，异步调 `ProfileService.refreshProfile` 刷新头像（不强求，可留到后续）

---

### Commit 6：前端 — 微信风格个人中心页面（双文件同步改造）

**目标**：把占位的 profile 页改造成微信"我"页样式，编辑按钮先留占位（Commit 7 接入逻辑）。

**实现文件**：
- `snow-chat-flutter/lib/ui/screens/profile_tab.dart`
  - 顶部 `Container`（深色背景或 `colorScheme.primaryContainer`）：行内左侧 64x64 `AvatarWidget(imageUrl: auth.avatar, initials: nickname首字母)`、中间 Column(nickname, "@username")、右侧 `Icon(Icons.qr_code_2)` + `Icon(Icons.chevron_right)`
  - 点击整行 → 占位 `onTap: () {}`（Commit 7 接入头像选择）
  - 分组菜单 `Card`：
    - `ListTile(leading: Icon(Icons.alternate_email), title: "微信号", subtitle: username)`
    - `ListTile(leading: Icon(Icons.edit_note), title: "签名", subtitle: signature ?? "未设置", onTap: 占位)`
  - 保留现有：`ExpansionTile` 语言切换、隐私 ListTile、关于 v1.0.0 ListTile、退出登录
  - 头像展示从 `Icons.person` 占位 → `AvatarWidget` 真实加载
- `snow-chat-flutter/lib/ui/screens/profile_screen.dart` — 同步应用相同结构（保留其 `bottomNavigationBar`）

**测试**：
- `snow-chat-flutter/test/ui/screens/profile_tab_test.dart`（新增 widget test）
  - 注入 mock AuthProvider（avatar='https://x', nickname='Alice'）
  - pump ProfileTab，断言找到 `AvatarWidget`、文本 'Alice'、'@username'
  - 断言退出登录按钮存在

---

### Commit 7：前端 — 头像选择与上传交互

**目标**：点击头像行触发选图 → 上传 → 更新 AuthProvider → UI 刷新闭环。

**实现文件**：
- `snow-chat-flutter/lib/ui/screens/profile_tab.dart`
  - 头像行 `onTap` → `showModalBottomSheet`：选项"拍照 / 从相册选择 / 取消"
  - 调用 `ImagePicker.pickImage(source: camera/gallery, maxWidth: 512, imageQuality: 80)`
  - 上传中：头像上叠加 `CircularProgressIndicator`（用 `Stack`）
  - 调用 `ProfileService.uploadAvatar(file)` → 拿到 `url`
  - 调用 `ProfileService.updateProfile(userId, avatar: result.key)` 让后端把 key 存 DB
  - 调用 `AuthProvider.updateAvatar(result.url)` 让本地立即显示新 URL
  - 失败：`ScaffoldMessenger.showSnackBar` 显示错误
- `snow-chat-flutter/lib/ui/screens/profile_screen.dart` — 同步同样的交互逻辑

**测试**：
- `snow-chat-flutter/test/ui/screens/profile_tab_test.dart` 扩展
  - mock `ImagePicker`（用 `ImagePickerPlatform` fake）+ mock `ProfileService`
  - tap 头像行 → tap "从相册选择" → 验证 `ProfileService.uploadAvatar` 被调用、`AuthProvider.updateAvatar` 被调用、avatar 显示更新

---

## 三、Assumptions & Decisions（假设与决策）

| # | 假设 | 影响 |
|---|---|---|
| 1 | 用户对 MinIO 部署选了"Other"未明确 — 计划同时提供 `docker-compose.yml` 与代码集成 | 用户可执行时跳过 docker-compose 文件创建 |
| 2 | `ChatUser.avatar` 字段存对象 key（`avatars/uuid.jpg`），不存 URL | 需在后端 `info` 端点动态转换；旧数据原样返回 |
| 3 | Pre-signed URL 默认有效期 7 天（60*24*7 分钟） | 与 co-talk 默认一致；用户可改 |
| 4 | `image_picker` 已在 pubspec，无需新增依赖 | iOS Info.plist 已有相机/相册权限（执行时若缺会补） |
| 5 | 后端 AWS S3 SDK v2 直接版本 `2.30.0`，不引入 BOM | 与 co-talk 风格一致，简单 |
| 6 | `FileStorage` 双实现：`MinioFileStorage`（enabled=true）+ `InMemoryFileStorage`（enabled=false/missing） | 测试和未启用 MinIO 的环境可降级运行 |
| 7 | Git 作者 `mmm <mm@m.m>` 来自 `git config user.name/user.email`（本地 .git/config 无 user 段，回落全局） | 用 `git -c user.name=... -c user.email=... commit` 显式指定 |
| 8 | 每次提交前跑 `mvn test` / `flutter test` / `flutter analyze` | TDD 红→绿→重构节奏 |

---

## 四、Verification（验证步骤）

### 后端验证
```bash
cd snow-chat-im-backend
mvn -pl snow-im-api -am test        # 所有后端单测通过
mvn -pl snow-im-api -am package -DskipTests   # 编译打包通过
docker compose up -d minio          # 启动 MinIO（如选用 docker-compose）
# 启动后端后用 curl 验证：
curl -F "file=@test.jpg" http://localhost:8091/file/upload
curl http://localhost:8091/chat/user/info/1  # 返回的 avatar 应为 pre-signed URL
```

### 前端验证
```bash
cd snow-chat-flutter
flutter analyze                     # 无错误
flutter test                        # 所有测试通过
flutter run --dart-define=API_BASE_URL=http://localhost:8091 \
            --dart-define=MQTT_HOST=localhost
# 手动验证：登录 → 切到"我"Tab → 看到微信风格页面 → 点击头像 → 选图 → 上传成功 → 头像刷新
```

### Git 验证
```bash
git log --oneline -7                # 应看到 7 个新 commit
git log -1 --format='%an <%ae>'     # 应为 mmm <mm@m.m>
git status                          # 工作区干净（已全部提交）
git log origin/master..HEAD --oneline  # 7 个 commit 待 push（确认未推送）
```

---

## 五、执行注意事项

1. **TDD 节奏**：每个 commit 内严格按"先写测试看失败 → 写实现看通过 → 重构"循环。
2. **小步提交**：7 个 commit 各自独立可编译可测，不要把多个 commit 的代码堆在一起。
3. **不推送**：所有 commit 完成后，最后只汇报结果，不执行 `git push`。
4. **代码注释**：每行关键代码加中文注释（遵循用户偏好）。
5. **遇到 image_picker iOS 权限缺失**：若 `ios/Runner/Info.plist` 缺 `NSCameraUsageDescription` / `NSPhotoLibraryUsageDescription`，在 Commit 7 一并补上并说明。
6. **遇到 Flyway 冲突**：本计划不新增 SQL 迁移（avatar 字段已存在），无需新 V7 脚本。
