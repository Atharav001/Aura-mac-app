#!/bin/bash
set -e

APP_NAME="Aura"
BUNDLE="/tmp/${APP_NAME}.app"
BINARY=".build/debug/${APP_NAME}"
ENTITLEMENTS="Aura/Aura.entitlements"

swift build

killall "${APP_NAME}" 2>/dev/null || true
rm -rf "${BUNDLE}"

mkdir -p "${BUNDLE}/Contents/MacOS"
mkdir -p "${BUNDLE}/Contents/Resources/Logos"
cp "${BINARY}" "${BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "Aura/Info.plist" "${BUNDLE}/Contents/"
# Logos for menu bar / dock branding
if [ -d "Aura/Resources/Logos" ]; then
  cp -R Aura/Resources/Logos/. "${BUNDLE}/Contents/Resources/Logos/"
fi
# Also copy SPM resource bundle logos if present
SPM_RES=$(find .build -type d -path "*Aura_Aura.bundle*" 2>/dev/null | head -1)
if [ -n "$SPM_RES" ] && [ -d "$SPM_RES" ]; then
  cp -R "$SPM_RES"/. "${BUNDLE}/Contents/Resources/" 2>/dev/null || true
fi

# Sign with entitlements so Spotify/Music Apple Events + Calendar work
codesign --force --deep --sign - \
  --entitlements "${ENTITLEMENTS}" \
  "${BUNDLE}/Contents/MacOS/${APP_NAME}"
codesign --force --deep --sign - \
  --entitlements "${ENTITLEMENTS}" \
  "${BUNDLE}"

open "${BUNDLE}"

echo ""
echo "If music still doesn't appear: System Settings → Privacy & Security → Automation"
echo "  enable Aura → Spotify and Aura → Music"
echo "Also grant Calendar access when prompted."
