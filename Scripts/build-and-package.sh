#!/bin/bash
# PhotoLog 构建与打包脚本
# 用法: ./build-and-package.sh [scheme] [identity]
# 示例: ./build-and-package.sh PhotoLog "Developer ID Application: Your Name (TEAMID)"

set -euo pipefail

# 配置
SCHEME="${1:-PhotoLog}"
IDENTITY="${2:-}"
CONFIGURATION="Release"
ARCHIVE_PATH="./build/PhotoLog.xcarchive"
EXPORT_PATH="./build/export"
DMG_NAME="PhotoLog"
APP_NAME="PhotoLog.app"
BUILD_DIR="./build"

echo "🔧 PhotoLog 构建与打包"
echo "========================"
echo "Scheme: $SCHEME"
echo "Configuration: $CONFIGURATION"
echo "Identity: ${IDENTITY:-未指定（将使用自动签名）}"
echo ""

# 步骤 1: 清理旧构建
echo "🧹 清理旧构建..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# 步骤 2: 生成 Xcode 项目（如果使用 XcodeGen）
if command -v xcodegen &> /dev/null; then
    echo "📦 使用 XcodeGen 生成项目..."
    xcodegen generate
fi

# 步骤 3: 构建 Archive
echo "🏗️  构建 Archive..."
xcodebuild archive \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -archivePath "$ARCHIVE_PATH" \
    -destination "platform=macOS,arch=arm64" \
    CODE_SIGN_IDENTITY="${IDENTITY:--}" \
    CODE_SIGN_STYLE="${IDENTITY:+Manual}" \
    DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-}" \
    | tail -20

if [ ! -d "$ARCHIVE_PATH" ]; then
    echo "❌ Archive 构建失败"
    exit 1
fi
echo "✅ Archive 构建成功"

# 步骤 4: 导出 App
echo "📤 导出应用..."
mkdir -p "$EXPORT_PATH"
cp -R "$ARCHIVE_PATH/Products/Applications/$APP_NAME" "$EXPORT_PATH/"

# 步骤 5: 代码签名（如果指定了身份）
if [ -n "$IDENTITY" ]; then
    echo "🔑 代码签名..."
    codesign --force --deep --sign "$IDENTITY" \
        --options runtime \
        --entitlements "./PhotoLog/PhotoLog.entitlements" \
        "$EXPORT_PATH/$APP_NAME"
    
    # 验证签名
    echo "🔍 验证签名..."
    codesign --verify --deep --strict --verbose=2 "$EXPORT_PATH/$APP_NAME" 2>&1 | tail -5
    echo "✅ 签名验证通过"
    
    # 步骤 6: 公证
    echo "📝 提交公证..."
    # 创建 zip 用于公证
    ditto -c -k --keepParent "$EXPORT_PATH/$APP_NAME" "$BUILD_DIR/PhotoLog.zip"
    
    NOTARY_OUTPUT=$(xcrun notarytool submit "$BUILD_DIR/PhotoLog.zip" \
        --apple-id "${NOTARYTOOL_APPLE_ID:-}" \
        --team-id "${NOTARYTOOL_TEAM_ID:-}" \
        --password "${NOTARYTOOL_PASSWORD:-}" \
        --wait 2>&1 || true)
    
    if echo "$NOTARY_OUTPUT" | grep -q "Accepted"; then
        echo "✅ 公证通过"
        
        # Staple
        echo "📌 Staple 公证票据..."
        xcrun stapler staple "$EXPORT_PATH/$APP_NAME"
        echo "✅ Staple 完成"
    else
        echo "⚠️ 公证结果:"
        echo "$NOTARY_OUTPUT"
        echo "可以继续打包 DMG，但用户首次打开时需要手动确认"
    fi
else
    echo "⚠️ 未指定签名身份，跳过代码签名和公证"
    echo "   使用方法: $0 PhotoLog \"Developer ID Application: Your Name (TEAMID)\""
fi

# 步骤 7: 创建 DMG
echo "💿 创建 DMG..."
DMG_PATH="$BUILD_DIR/$DMG_NAME.dmg"
hdiutil create -volname "$DMG_NAME" \
    -srcfolder "$EXPORT_PATH" \
    -ov -format UDZO \
    "$DMG_PATH"

if [ -f "$DMG_PATH" ]; then
    DMG_SIZE=$(du -sh "$DMG_PATH" | cut -f1)
    echo "✅ DMG 创建成功: $DMG_PATH ($DMG_SIZE)"
else
    echo "❌ DMG 创建失败"
    exit 1
fi

echo ""
echo "🎉 构建完成！"
echo "   Archive: $ARCHIVE_PATH"
echo "   App: $EXPORT_PATH/$APP_NAME"
echo "   DMG: $DMG_PATH"
