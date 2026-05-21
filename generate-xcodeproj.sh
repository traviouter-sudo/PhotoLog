#!/bin/bash
# generate-xcodeproj.sh
# 从源文件目录生成 Xcode 项目
# 前提：已安装 Xcode 15+

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_NAME="PhotoLog"

echo "🔧 正在生成 Xcode 项目..."

# 检查 Xcode 是否安装
if ! xcode-select -p 2>/dev/null | grep -q "Xcode.app"; then
    echo "❌ 需要完整的 Xcode（不是 Command Line Tools）"
    echo "   请从 App Store 安装 Xcode 15+"
    echo "   安装后运行: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
    exit 1
fi

# 检查 xcodegen 是否安装
if ! command -v xcodegen &>/dev/null; then
    echo "📦 安装 xcodegen（项目配置工具）..."
    brew install xcodegen 2>/dev/null || {
        echo "❌ 无法安装 xcodegen，请先安装 Homebrew: https://brew.sh"
        exit 1
    }
fi

# 生成项目
cd "$PROJECT_DIR"
xcodegen generate

echo "✅ Xcode 项目已生成: ${PROJECT_NAME}.xcodeproj"
echo "   打开方式: open ${PROJECT_NAME}.xcodeproj"
