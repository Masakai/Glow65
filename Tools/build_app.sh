#!/bin/bash
# Glow65.app を dist/ に作る。署名は ad-hoc(開発者 ID なし)。配布用の公証はしない。
# 使い方: Tools/build_app.sh      (swift と、BASIC を載せるなら cc65 が必要)
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${GLOW65_VERSION:-0.1.0}"
APP="dist/Glow65.app"

# ROM がなければ作る(BASIC は cc65 がある場合だけ)
[ -f ROM/monitor.bin ] || Tools/build_monitor.sh
if [ ! -f ROM/basic/build/basic.bin ]; then
    if command -v ca65 >/dev/null 2>&1; then
        Tools/build_basic.sh
    else
        echo "警告: cc65 がないので BASIC を載せない(モニタだけで動く)" >&2
    fi
fi

swift build -c release --product Glow65App
BIN="$(swift build -c release --show-bin-path)/Glow65App"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/ROM/basic/build"
cp "$BIN" "$APP/Contents/MacOS/Glow65App"
cp ROM/monitor.bin "$APP/Contents/Resources/ROM/"
[ -f ROM/basic/build/basic.bin ] && cp ROM/basic/build/basic.bin "$APP/Contents/Resources/ROM/basic/build/"
cp Tools/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# サンプルプログラムと、そのソースを同梱する(File → Load Program… で選べる)
mkdir -p "$APP/Contents/Resources/tutorial"
cp tutorial/*.bin tutorial/*.s "$APP/Contents/Resources/tutorial/" 2>/dev/null || true
cp LICENSE NOTICE.md "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Glow65</string>
    <key>CFBundleDisplayName</key><string>Glow65</string>
    <key>CFBundleIdentifier</key><string>io.github.masakai.glow65</string>
    <key>CFBundleExecutable</key><string>Glow65App</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.education</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSHumanReadableCopyright</key><string>MIT License</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"
echo "作成: $APP"
du -sh "$APP"
