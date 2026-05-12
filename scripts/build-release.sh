#!/bin/bash
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
cd "$PROJECT_ROOT"

PROJECT="RecessEyes.xcodeproj"
SCHEME="RecessEyes"
APP_NAME="RecessEyes.app"
BUILD_DIR="$PROJECT_ROOT/.build_release"
VERSION_FILE="$PROJECT_ROOT/RecessEyes/Version.xcconfig"

# Auto-bump CURRENT_PROJECT_VERSION
CURRENT_BUILD=$(grep "^CURRENT_PROJECT_VERSION" "$VERSION_FILE" | awk -F'=' '{print $2}' | tr -d ' ')
NEW_BUILD=$((CURRENT_BUILD + 1))
sed -i '' "s/^CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = $NEW_BUILD/" "$VERSION_FILE"
echo "▶ Build number: $CURRENT_BUILD → $NEW_BUILD"

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

DEST="/Applications/$APP_NAME"

echo "▶ Installing to $DEST..."

if pgrep -x "RecessEyes" > /dev/null; then
    echo "  Stopping running instance..."
    pkill -x "RecessEyes" || true
    sleep 1
fi

rm -rf "$DEST"
cp -R "$BUILD_PATH" "$DEST"

echo "✓ Done: $DEST"
