#!/usr/bin/env bash
# Build a signed Release OpenDente.app for this Apple Silicon Mac (macOS 14+).
# The privileged helper only registers when the app is signed with your team.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT=$(pwd)

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "这个脚本要在 macOS 上运行。"
  exit 1
fi

if [[ "$(uname -m)" != "arm64" ]]; then
  echo "当前架构是 $(uname -m)。OpenDente 只支持 Apple Silicon（M1 及更新的芯片）。"
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "找不到 xcodebuild。请安装 Xcode 16。编译机需要 macOS 14.5 或更高版本。"
  exit 1
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "找不到 xcodegen。先运行: brew install xcodegen"
  exit 1
fi

TEAM="${DEVELOPMENT_TEAM:-}"
if [[ -z "$TEAM" && -f Config/Local.xcconfig ]]; then
  TEAM=$(sed -n 's/^DEVELOPMENT_TEAM[[:space:]]*=[[:space:]]*//p' Config/Local.xcconfig | tail -n 1 | tr -d '[:space:]')
fi

if [[ -z "$TEAM" || "$TEAM" == "YOUR_TEAM_ID" ]]; then
  cat <<'EOF'
需要你自己的 Apple Development Team ID，特权辅助工具才能在这台 Mac 上注册。
Config/App.xcconfig 里的团队 ID 是原作者的。那不是你的 Apple ID 时，签名会失败。

1. 打开 Xcode → Settings → Accounts，登录你的 Apple ID
2. 选中账号，查看 Team ID（10 位字符）
3. 复制 Config/Local.xcconfig.example 为 Config/Local.xcconfig，填入 DEVELOPMENT_TEAM
   也可以临时这样运行: DEVELOPMENT_TEAM=你的团队ID ./scripts/build-release.sh

免费 Apple ID 可以签名。描述文件大约 7 天后过期，过期后重新运行本脚本即可。
EOF
  exit 1
fi

echo "使用团队 $TEAM 编译 arm64 Release（部署目标 macOS 14.0）…"
xcodegen generate

DERIVED="$ROOT/build"
rm -rf "$DERIVED"
xcodebuild \
  -project OpenDente.xcodeproj \
  -scheme OpenDente \
  -configuration Release \
  -destination "platform=macOS,arch=arm64" \
  -derivedDataPath "$DERIVED" \
  DEVELOPMENT_TEAM="$TEAM" \
  CODE_SIGN_STYLE=Automatic \
  ONLY_ACTIVE_ARCH=YES \
  build

APP="$DERIVED/Build/Products/Release/OpenDente.app"
HELPER="$APP/Contents/Library/HelperTools/com.opendente.helper"
DAEMON_PLIST="$APP/Contents/Library/LaunchDaemons/com.opendente.helper.plist"
STRINGS="$APP/Contents/Resources/zh-Hans.lproj/Localizable.strings"

for required in "$APP" "$HELPER" "$DAEMON_PLIST" "$STRINGS"; do
  if [[ ! -e "$required" ]]; then
    echo "构建产物缺少: $required"
    exit 1
  fi
done

if ! file "$APP/Contents/MacOS/OpenDente" | grep -q "arm64"; then
  echo "可执行文件不是 arm64:"
  file "$APP/Contents/MacOS/OpenDente"
  exit 1
fi

codesign --verify --deep --strict "$APP"
MIN=$(plutil -extract LSMinimumSystemVersion raw -o - "$APP/Contents/Info.plist")
VERSION=$(plutil -extract CFBundleShortVersionString raw -o - "$APP/Contents/Info.plist")

mkdir -p dist
ZIP="$ROOT/dist/OpenDente-${VERSION}-macos14-arm64.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo
echo "已生成 $ZIP"
echo "最低系统版本: $MIN"
echo "把 OpenDente.app 拷到“应用程序”后打开。"
echo "第一次会要求管理员密码，并在“系统设置 → 通用 → 登录项”里批准辅助工具。"
echo "界面语言跟随系统。简体中文系统会直接显示中文。"
echo "英文系统想用中文：系统设置 → 通用 → 语言与地区 → 应用程序 → OpenDente → 简体中文。"
