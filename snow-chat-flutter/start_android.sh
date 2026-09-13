# ===== 环境 =====
ADB=/Users/mmm/Library/Android/sdk/platform-tools/adb
DEV="adb-AN5UUT6205009233-p3P3ux._adb-tls-connect._tcp"   # 真机的无线调试设备名

# ===== 1. 确认真机在线（必须有 device 状态）=====
$ADB devices -l

# ===== 2. 构建 debug APK =====
cd /Users/mmm/code/im/snow-chat-im-gitee.com/snow-chat-flutter
/Users/mmm/software-program/flutter3.41.9/bin/flutter build apk --debug

# ===== 3. 安装到真机 =====
$ADB -s "$DEV" install -r -t build/app/outputs/flutter-apk/app-debug.apk

# ===== 4. 启动 =====
$ADB -s "$DEV" shell am start -W -n com.snow.chat.im/.MainActivity

# ===== 5. 验证真的进了 App（返回 0 就是成功）=====
$ADB -s "$DEV" shell "dumpsys window windows | grep -c 'Splash Screen com.snow.chat.im'"
