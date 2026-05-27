#!/bin/bash
set -e

APP_NAME="Bookworm"
APP_BUNDLE="${APP_NAME}.app"
VERSION=$(cat version.txt)
BUILD_VER=$(cat build.txt)
DIST_DIR="dist"
PKG_PATH="${DIST_DIR}/${APP_NAME}-${VERSION}-build-${BUILD_VER}.pkg"

if [ ! -d "${APP_BUNDLE}" ]; then
    echo "❌ ${APP_BUNDLE} not found. Run ./make-app.sh --no first."
    exit 1
fi

mkdir -p "${DIST_DIR}"
rm -f "${PKG_PATH}"

echo "▶ Building installer package..."
pkgbuild \
    --component "${APP_BUNDLE}" \
    --install-location "/Applications" \
    --identifier "com.bookworm.app" \
    --version "${VERSION}" \
    "${PKG_PATH}"

echo "✅ Installer ready: ${PKG_PATH}"
