#!/bin/bash
# EarthLord 快速运行脚本

echo "🚀 启动 EarthLord..."
echo ""

# 编译并运行
xcodebuild -project EarthLord.xcodeproj \
  -scheme EarthLord \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ 编译成功！"
    echo "📱 正在启动模拟器..."

    # 启动模拟器中的App
    xcrun simctl boot "iPhone 17 Pro" 2>/dev/null || true
    open -a Simulator

    # 安装并运行App
    APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/EarthLord-*/Build/Products/Debug-iphonesimulator -name "EarthLord.app" | head -n 1)

    if [ -n "$APP_PATH" ]; then
        xcrun simctl install booted "$APP_PATH"
        xcrun simctl launch booted com.ethan.EarthLord
        echo "✅ App已启动！"
    fi
else
    echo "❌ 编译失败"
    exit 1
fi
