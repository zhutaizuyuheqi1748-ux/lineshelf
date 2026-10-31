#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
CONFIG="${1:-release}"
# Use an installed SDK compatible with the local toolchain.
if [ -z "${SDKROOT:-}" ] && [ -d /Library/Developer/CommandLineTools/SDKs/MacOSX26.2.sdk ]; then
  export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.2.sdk
fi
swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)/Tendedero"
APP="build/晾架.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/LineShelf"
for dir in Sources/Tendedero/Resources/*.lproj; do cp -R "$dir" "$APP/Contents/Resources/"; done
cp LICENSE "$APP/Contents/Resources/LICENSE.txt"
WORK="$(mktemp -d)"
swift scripts/make-lineshelf-icon.swift "$WORK/icon.png"
mkdir -p "$WORK/LineShelf.iconset"
for s in 16 32 128 256 512; do
  sips -z "$s" "$s" "$WORK/icon.png" --out "$WORK/LineShelf.iconset/icon_${s}x${s}.png" >/dev/null
  sips -z "$((s*2))" "$((s*2))" "$WORK/icon.png" --out "$WORK/LineShelf.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$WORK/LineShelf.iconset" -o "$APP/Contents/Resources/LineShelf.icns"
rm -rf "$WORK"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>晾架</string>
<key>CFBundleDisplayName</key><string>晾架</string>
<key>CFBundleIdentifier</key><string>local.lineshelf.app</string>
<key>CFBundleExecutable</key><string>LineShelf</string>
<key>CFBundleIconFile</key><string>LineShelf</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleLocalizations</key><array><string>en</string><string>zh-Hans</string></array>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSDesktopFolderUsageDescription</key><string>晾架读取新截图，将它们挂在屏幕顶部。</string>
<key>NSDocumentsFolderUsageDescription</key><string>晾架读取您选择的截图目录和拖入的文件。</string>
<key>NSDownloadsFolderUsageDescription</key><string>晾架监听下载目录，把新下载和 AirDrop 收到的文件挂上晾绳。</string>
</dict></plist>
PLIST
codesign --force --deep --sign - "$APP"
echo "Built $APP"
