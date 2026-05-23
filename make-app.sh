#!/bin/bash
set -e

# Parse arguments
AUTO_INSTALL=""
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -y|--yes) AUTO_INSTALL="yes"; shift ;;
        -n|--no) AUTO_INSTALL="no"; shift ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  -y, --yes    Auto-install to /Applications without prompting"
            echo "  -n, --no     Build only, do not install to /Applications"
            echo "  -h, --help   Show this help message"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Automatically bump version and build numbers before compiling
python3 bump-version.py

APP_NAME="Bookworm"
BUNDLE_ID="com.bookworm.app"
VERSION=$(cat version.txt)
BUILD_VER=$(cat build.txt)
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
    ICONSET=".build/AppIcon.iconset"
    rm -rf "${ICONSET}" && mkdir -p "${ICONSET}"
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
    <key>CFBundleVersion</key>         <string>${BUILD_VER}</string>
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

# Determine whether to install
INSTALL_APP=""
if [[ "${AUTO_INSTALL}" == "yes" ]]; then
    INSTALL_APP="yes"
elif [[ "${AUTO_INSTALL}" == "no" ]]; then
    INSTALL_APP="no"
else
    # Non-interactive check: if stdin is not a TTY, default to "no"
    if [[ ! -t 0 ]]; then
        echo "▶ Non-interactive shell detected. Skipping installation prompt (defaulting to No)."
        INSTALL_APP="no"
    else
        read -rp "Install to /Applications? [y/N] " answer
        if [[ "${answer}" =~ ^[Yy]$ ]]; then
            INSTALL_APP="yes"
        else
            INSTALL_APP="no"
        fi
    fi
fi

if [[ "${INSTALL_APP}" == "yes" ]]; then
    # Check if Bookworm is currently running
    if pgrep -x "Bookworm" >/dev/null; then
        echo "⚠️  Bookworm is currently running."
        if [[ ! -t 0 || "${AUTO_INSTALL}" == "yes" ]]; then
            echo "▶ Non-interactive or auto-install: closing Bookworm gracefully..."
            osascript -e 'quit app "Bookworm"' 2>/dev/null || true
            sleep 1
            # Force kill if still running after 2 seconds
            if pgrep -x "Bookworm" >/dev/null; then
                echo "▶ Bookworm still running. Force killing..."
                pkill -9 -x "Bookworm" 2>/dev/null || true
            fi
        else
            read -rp "Bookworm must be closed to install. Close it now? [Y/n] " close_ans
            if [[ ! "${close_ans}" =~ ^[Nn]$ ]]; then
                echo "▶ Closing Bookworm gracefully..."
                osascript -e 'quit app "Bookworm"' 2>/dev/null || true
                sleep 1
                if pgrep -x "Bookworm" >/dev/null; then
                    echo "▶ Force killing Bookworm..."
                    pkill -9 -x "Bookworm" 2>/dev/null || true
                fi
            else
                echo "❌ Installation cancelled because Bookworm is running."
                exit 1
            fi
        fi
    fi

    echo "▶ Installing to /Applications..."
    rm -rf "/Applications/${APP_BUNDLE}"
    cp -r "${APP_BUNDLE}" "/Applications/"
    echo "✅  Installed to /Applications/${APP_BUNDLE}"
    open "/Applications/${APP_BUNDLE}"
else
    echo "Run it now with:  open ${APP_BUNDLE}"
fi
