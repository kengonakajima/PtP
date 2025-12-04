#!/bin/bash
set -e

cd "$(dirname "$0")"

APP_NAME="PtP"
APP_DIR="${APP_NAME}.app"

# 既存を削除
rm -rf "$APP_DIR"

# .app バンドル構造を作成
mkdir -p "${APP_DIR}/Contents/MacOS"

# コンパイル
swiftc -o "${APP_DIR}/Contents/MacOS/${APP_NAME}" PtP.swift -framework AppKit

# Info.plist を作成
cat > "${APP_DIR}/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>PtP</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.ptp</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>PtP</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.15</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "Build complete: ${APP_DIR}"
echo "Run with: open ${APP_DIR}"
