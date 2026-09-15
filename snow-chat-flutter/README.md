# chat Flutter

chat 是一个实时消息应用。使用 Flutter 开发，基于使用 BLoC 模式的清洁架构。

## 主要功能

- 实时消息 (WebSocket/STOMP)
- 用户认证与授权
- 好友管理
- 聊天室管理
- 聊天图片保存到相册（全屏·长按菜单）
- 消息内 URL 检测·预览（域名模式·规范化支持）
- 推送通知 (FCM·桌面 WebSocket, 应用图标反映)
- 多平台支持 (iOS, Android, macOS, Windows)

## 技术栈

- **框架**: Flutter 3.41.1+
- **状态管理**: BLoC (flutter_bloc)
- **网络**: Dio
- **WebSocket**: STOMP (stomp_dart_client)
- **本地存储**: flutter_secure_storage, shared_preferences
- **依赖注入**: GetIt, Injectable
- **路由**: GoRouter
- **UI**: Material Design

## 项目结构

```
lib/
├── app.dart                 # 应用入口
├── main.dart               # 主函数
├── core/                   # 核心功能
│   ├── constants/         # 常量
│   ├── errors/            # 错误处理
│   ├── network/           # 网络配置
│   ├── router/            # 路由配置
│   ├── theme/             # 主题配置
│   └── utils/             # 工具
├── data/                   # 数据层
│   ├── datasources/       # 数据源
│   ├── models/            # 数据模型
│   └── repositories/      # 仓库实现
├── domain/                 # 领域层
│   ├── entities/          # 实体
│   ├── repositories/      # 仓库接口
│   └── usecases/          # 用例
├── presentation/           # 展示层
│   ├── blocs/             # BLoC 状态管理
│   ├── pages/             # 页面
│   └── widgets/           # 组件
└── di/                     # 依赖注入配置
```

## 开始使用

### 前提条件

- Flutter SDK 3.8.1+
- Dart SDK
- iOS 开发: Xcode (macOS)
- Android 开发: Android Studio
- macOS 开发: Xcode
- Windows 开发: Visual Studio

### 安装

1. 克隆仓库:
```bash
git clone https://xxx.git
```

2. 安装依赖:
```bash
flutter pub get
```

3. 代码生成（依赖注入及 JSON 序列化）:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 运行

- iOS:
```bash
flutter run -d ios
```

- Android:
```bash
flutter run -d android
```

- macOS:
```bash
flutter run -d macos
```

- Windows:
```bash
flutter run -d windows
```

- linux:
```bash
flutter run -d linux
```

- web:
```bash
flutter run --web-port 8080 
flutter run -d chrome
```

### 通知(推送)图标 (iOS / macOS / Windows)

iOS、macOS、Windows 中通知使用 **应用图标**。要显示 chat 图标：

1. 确认 `assets/icons/app_icon.png` 是 chat 应用图标图片。
2. 使用以下命令重新生成所有平台的应用图标：
```bash
dart run flutter_launcher_icons
```
3. 重新构建并运行应用。

Android 在通知设置中使用 `@mipmap/ic_launcher`，因此通过上述命令生成的启动器图标也会应用于通知。

## 测试

```bash
# 运行所有测试
flutter test

# 带覆盖率的测试
flutter test --coverage
```

## 构建

### Android APK
```bash

/Users/mmm/software-program/flutter3.41.9/bin/flutter pub get
/Users/mmm/software-program/flutter3.41.9/bin/flutter build apk --release
flutter build apk --release
```

### iOS
```bash
flutter build ios --release
```

### macOS
```bash
flutter build macos --release
```

### Windows
```bash
flutter build windows --release
```


### linux
```bash
flutter build linux --release
```
## 开发指南

### 架构

本项目遵循 Clean Architecture 原则：

- **Presentation Layer**: UI 和状态管理 (BLoC)
- **Domain Layer**: 业务逻辑和实体
- **Data Layer**: 数据源和仓库实现

### 代码风格

项目使用 `flutter_lints` 来保持代码风格。

### 依赖注入

使用 `get_it` 和 `injectable` 管理依赖注入。添加新依赖后运行以下命令：

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## 文档

- **[CHANGELOG.md](./CHANGELOG.md)** — 版本变更历史 (Added / Changed / Fixed 等)
- **[docs/DEV_LOG.md](./docs/DEV_LOG.md)** — 开发者博客形式整理 (背景·实现·决定摘要)

## 许可证

本项目属于 with-chat 组织所有。

## 贡献

欢迎贡献！请提交 issue 或 Pull Request。