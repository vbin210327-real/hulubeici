#!/bin/bash

# 清理并重新构建，明确指定 StoreKit 配置
xcodebuild clean -project "葫芦背词.xcodeproj" -scheme "葫芦背词"

# 构建并运行，使用环境变量指定 StoreKit 配置
xcodebuild build -project "葫芦背词.xcodeproj" -scheme "葫芦背词" \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -configuration Debug

echo "Build complete. Now run the app from Xcode."
