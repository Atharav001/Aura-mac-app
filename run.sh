#!/bin/bash
set -e

APP_NAME="Aura"
BUNDLE="/tmp/${APP_NAME}.app"
BINARY=".build/debug/${APP_NAME}"

swift build

killall "${APP_NAME}" 2>/dev/null || true
rm -rf "${BUNDLE}"

mkdir -p "${BUNDLE}/Contents/MacOS"
cp "${BINARY}" "${BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "Aura/Info.plist" "${BUNDLE}/Contents/"
touch "${BUNDLE}/Applications"  # legacy dir marker

open "${BUNDLE}"
