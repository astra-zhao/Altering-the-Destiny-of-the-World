#!/bin/sh
# 在已安装 Godot 4.6.3 导出模板的机器上打出未签名的 Apple Silicon .app。
# 编辑器路径：Project → Export → macOS。约两分钟，见 README。
set -eu
cd "$(dirname "$0")"
GODOT="${GODOT:-godot}"
mkdir -p build/macos
"$GODOT" --headless --path . --export-release "macOS" "build/macos/改命天下.app"
echo "exported build/macos/改命天下.app"
