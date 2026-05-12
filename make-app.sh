#!/bin/bash
set -e

APP_NAME="Bookworm"
BUNDLE_ID="com.bookworm.app"
VERSION="1.2"
APP_BUNDLE="${APP_NAME}.app"
RESOURCES="${APP_BUNDLE}/Contents/Resources"
ICON_PNG="Sources/Bookworm/Assets/icon.png"

echo "▶ Building release binary..."
swift build -c release

echo "▶ Assembling app bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${RESOURCES}"

# Binary
cp ".build/release/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# Assets (icon.png used at runtime)
cp -r "Sources/Bookworm/Assets" "${RESOURCES}/"

# Convert icon.png → AppIcon.icns
if [ -f "${ICON_PNG}" ]; then
    echo "▶ Generating .icns icon..."
    ICONSET="/tmp/AppIcon.iconset"
    rm -rf "${ICONSET}" && mkdir "${ICONSET}"
    for size in 16 32 128 256 512; do
        sips -z $size $size "${ICON_PNG}" \
            --out "${ICONSET}/icon_${size}x${size}.png"         > /dev/null
        sips -z $((size*2)) $((size*2)) "${ICON_PNG}" \
            --out "${ICONSET}/icon_${size}x${size}@2x.png"      > /dev/null
    done
    iconutil -c icns "${ICONSET}" -o "${RESOURCES}/AppIcon.icns"
    rm -rf "${ICONSET}"
fi

# Info.plist
cat > "${APP_BUNDLE}/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>      <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>      <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>            <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>     <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleShortVersionString</key> <string>${VERSION}</string>
    <key>CFBundleVersion</key>         <string>1</string>
    <key>CFBundleIconFile</key>        <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>  <string>14.0</string>
    <key>NSHighResolutionCapable</key> <true/>
    <key>NSPrincipalClass</key>        <string>NSApplication</string>
    <key>NSHumanReadableCopyright</key><string>© 2025 Bookworm</string>
</dict>
</plist>
PLIST

# Ad-hoc sign (works on your own machine without a Developer account)
echo "▶ Signing (ad-hoc)..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo ""
echo "✅  ${APP_BUNDLE} is ready."
echo ""

read -rp "Install to /Applications? [y/N] " answer
if [[ "${answer}" =~ ^[Yy]$ ]]; then
    rm -rf "/Applications/${APP_BUNDLE}"
    cp -r "${APP_BUNDLE}" "/Applications/"
    echo "✅  Installed to /Applications/${APP_BUNDLE}"
    open "/Applications/${APP_BUNDLE}"
else
    echo "Run it now with:  open ${APP_BUNDLE}"
fi
