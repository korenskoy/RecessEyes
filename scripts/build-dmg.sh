#!/bin/bash
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
cd "$PROJECT_ROOT"

PROJECT="RecessEyes.xcodeproj"
SCHEME="RecessEyes"
APP_NAME="RecessEyes.app"
BUILD_DIR="$PROJECT_ROOT/.build_release"
OUTPUT_DIR="$PROJECT_ROOT/build"
VERSION_FILE="$PROJECT_ROOT/RecessEyes/Version.xcconfig"

MARKETING_VERSION=$(grep "^MARKETING_VERSION" "$VERSION_FILE" | awk -F'=' '{print $2}' | tr -d ' ')

CURRENT_BUILD=$(grep "^CURRENT_PROJECT_VERSION" "$VERSION_FILE" | awk -F'=' '{print $2}' | tr -d ' ')
BUILD_NUMBER=$((CURRENT_BUILD + 1))
sed -i '' "s/^CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = $BUILD_NUMBER/" "$VERSION_FILE"
echo "▶ Build number: $CURRENT_BUILD → $BUILD_NUMBER"

echo "▶ Packaging RecessEyes ${MARKETING_VERSION} (build ${BUILD_NUMBER})"
echo "▶ Clean build $SCHEME (Release)..."
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    clean build

BUILD_PATH="$BUILD_DIR/Build/Products/Release/$APP_NAME"
if [ ! -d "$BUILD_PATH" ]; then
    echo "✗ Build artifact not found at: $BUILD_PATH"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"
DMG_NAME="RecessEyes-${MARKETING_VERSION}.dmg"
DMG_PATH="$OUTPUT_DIR/$DMG_NAME"
rm -f "$DMG_PATH"

# Стейджинг: копируем .app + симлинк на /Applications для drag-to-install UX
STAGING="$(mktemp -d -t recesseyes_dmg)"
trap 'rm -rf "$STAGING"' EXIT

cp -R "$BUILD_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

echo "▶ Creating DMG → $DMG_PATH"
hdiutil create \
    -volname "RecessEyes ${MARKETING_VERSION}" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    -fs HFS+ \
    "$DMG_PATH" >/dev/null

SIZE=$(du -h "$DMG_PATH" | awk '{print $1}')
echo "✓ Done: $DMG_PATH ($SIZE)"
