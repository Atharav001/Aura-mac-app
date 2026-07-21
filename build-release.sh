#!/bin/bash
set -e

APP_NAME="Aura"
CONFIG="${1:-release}"
BINARY=".build/${CONFIG}/${APP_NAME}"
BUNDLE="/tmp/${APP_NAME}.app"
ENTITLEMENTS="Aura/Aura.entitlements"
DMG_PATH="/tmp/${APP_NAME}-${CONFIG}.dmg"
VOLUME_NAME="${APP_NAME}"

echo "==> Building ${CONFIG}..."
swift build -c "${CONFIG}"

echo "==> Creating .app bundle..."
killall "${APP_NAME}" 2>/dev/null || true
rm -rf "${BUNDLE}"

mkdir -p "${BUNDLE}/Contents/MacOS"
mkdir -p "${BUNDLE}/Contents/Resources/Logos"
cp "${BINARY}" "${BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "Aura/Info.plist" "${BUNDLE}/Contents/"

if [ -d "Aura/Resources/Logos" ]; then
  find Aura/Resources/Logos -maxdepth 1 -type f -exec cp {} "${BUNDLE}/Contents/Resources/Logos/" \;
fi
if [ -f "Aura/Resources/Logos/AppIcon.icns" ]; then
  cp "Aura/Resources/Logos/AppIcon.icns" "${BUNDLE}/Contents/Resources/AppIcon.icns"
fi

SPM_RES=$(find .build -type d -path "*Aura_Aura.bundle*" 2>/dev/null | head -1)
if [ -n "$SPM_RES" ] && [ -d "$SPM_RES" ]; then
  cp -R "$SPM_RES"/. "${BUNDLE}/Contents/Resources/" 2>/dev/null || true
fi
if [ -f "Aura/Resources/Logos/AppIcon.icns" ]; then
  cp "Aura/Resources/Logos/AppIcon.icns" "${BUNDLE}/Contents/Resources/AppIcon.icns"
fi

echo "==> Signing..."
codesign --force --deep --sign - --entitlements "${ENTITLEMENTS}" "${BUNDLE}/Contents/MacOS/${APP_NAME}"
codesign --force --deep --sign - --entitlements "${ENTITLEMENTS}" "${BUNDLE}"

echo "==> Creating .dmg..."
rm -f "${DMG_PATH}"
hdiutil create -volname "${VOLUME_NAME}" -srcfolder "${BUNDLE}" -ov -format UDZO "${DMG_PATH}"

echo ""
echo "✅  .app: ${BUNDLE}"
echo "✅  .dmg: ${DMG_PATH}"
echo ""
echo "Note: codesign uses ad-hoc signing (-). For distribution, replace '-' with your Developer ID."
