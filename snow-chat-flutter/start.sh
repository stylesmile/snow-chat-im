#!/usr/bin/env bash
# App 启动脚本：列出所有设备，等待用户选择一个并启动
#
# 用法：
#   ./start.sh                 # 交互式：列出设备 → 输入序号或设备ID → 启动
#   ./start.sh <设备ID>        # 直接指定设备启动，例如 ./start.sh macos
#   ./start.sh --dart-define=X  # 追加额外 --dart-define 参数
#
# 说明：
#   - 必须在 snow-chat-flutter 目录下运行（脚本会自行切到所在目录，不依赖 cwd）
#   - 默认使用 lib/config/config.dart 里配置的后端地址，
#     如需覆盖可通过 --dart-define=API_BASE_URL=http://<ip>:8091 传入

# 切到脚本所在目录，确保相对路径（pubspec.yaml 等）正确
cd "$(dirname "$0")"
echo ">>> 工作目录: $(pwd)"

# 检查当前目录是否是 Flutter 项目根目录
if [ ! -f "pubspec.yaml" ]; then
  echo "错误: 当前目录不是 Flutter 项目根目录（未找到 pubspec.yaml）"
  exit 1
fi

# 收集启动时需追加到 flutter run 的额外参数（所有 --xxx 透传）
EXTRA_ARGS=()
for arg in "$@"; do
  # 形如 --dart-define=… 或 --release 等由 flutter 自己消费的参数
  EXTRA_ARGS+=("$arg")
done

# 扫描当前已连接的设备（无设备时提示帮助）
DEVICES=$(flutter devices --device-timeout 10 2>/dev/null)

# 若未检测到设备，给出排查建议
if ! echo "$DEVICES" | grep -q "•"; then
  echo "未检测到可用设备。请："
  echo "  1. 启动 Android 模拟器或连接真机 (adb devices)"
  echo "  2. 或运行 flutter emulators --launch <名称>"
  echo "  3. 或用 flutter doctor 排查环境"
  exit 1
fi

# 从 flutter devices 输出中提取「设备ID」与「展示名」
# 每一行格式形如：  名称 (类型) • 设备ID • 平台 • 描述
# 用 • 作分隔符：第1段是名称，第2段是设备ID
DEVIDS=()    # 设备ID数组（用于 flutter run -d）
DEVLABELS=() # 展示名数组（用于提示用户）
LINE_NO=0

while IFS= read -r line; do
  # 只处理包含分隔符 • 的设备行，跳过标题与空行
  if echo "$line" | grep -q "•"; then
    LINE_NO=$((LINE_NO + 1))
    # 提取设备ID：取第2段后 trim 首尾空白
    dev_id=$(echo "$line" | awk -F'•' '{print $2}' | xargs)
    DEVIDS+=("$dev_id")
    DEVLABELS+=("$line")
  fi
done <<< "$DEVICES"

# 展示所有设备并让用户选择
echo ""
echo ">>> 可用设备如下（输入序号或直接输入设备ID）："
for idx in "${!DEVIDS[@]}"; do
  printf '  [%d] %s\n' "$((idx + 1))" "${DEVLABELS[$idx]}"
done
echo ""

# 若启动命令里已指定设备（第一个参数不是 -- 开头，则视为设备ID），直接使用
TARGET_ID=""
if [ -n "$1" ] && [[ "$1" != --* ]]; then
  TARGET_ID="$1"
  echo ">>> 使用参数指定的设备: $TARGET_ID"
else
  # 交互等待用户输入：支持序号或设备ID两种形式
  printf "请求启动的设备 (1-%d 或设备ID): " "${#DEVIDS[@]}"
  read -r USER_INPUT

  # 输入为纯数字时，映射到设备ID；否则当作设备ID直接使用
  if [[ "$USER_INPUT" =~ ^[0-9]+$ ]]; then
    SEL=$((USER_INPUT - 1))
    if [ "$SEL" -ge 0 ] && [ "$SEL" -lt "${#DEVIDS[@]}" ]; then
      TARGET_ID="${DEVIDS[$SEL]}"
    else
      echo "错误: 序号越界（合法范围 1-${#DEVIDS[@]}）"
      exit 1
    fi
  else
    TARGET_ID="$USER_INPUT"
  fi
fi

# 最终校验设备ID非空
if [ -z "$TARGET_ID" ]; then
  echo "错误: 未提供有效的设备ID"
  exit 1
fi

echo ">>> 即将启动: flutter run -d $TARGET_ID ${EXTRA_ARGS[*]}"
echo "    （按 q 退出应用；按 r 热重启；按 R 完全重启）"

# 前台启动应用，保持运行直到用户手动退出
exec flutter run -d "$TARGET_ID" "${EXTRA_ARGS[@]}"