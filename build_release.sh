#!/bin/bash

# Prompt Manager - Release Build Script
# This script builds and packages the app for distribution

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="PromptManager"
VERSION="1.0"
BUILD_DIR="./build"
RELEASE_DIR="./release"

echo -e "${GREEN}Building Prompt Manager for distribution...${NC}\n"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf "$BUILD_DIR"
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

# Build the app
echo -e "\n📦 Building Release version..."
xcodebuild -project "${APP_NAME}.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  clean build

APP_PATH="$BUILD_DIR/Build/Products/Release/${APP_NAME}.app"

if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}❌ Build failed! App not found at $APP_PATH${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Build successful!${NC}"

# Copy app to release directory
echo -e "\n📋 Copying app to release directory..."
cp -R "$APP_PATH" "$RELEASE_DIR/"

# Create ZIP
echo -e "\n🗜️  Creating ZIP archive..."
cd "$RELEASE_DIR"
ditto -c -k --keepParent "${APP_NAME}.app" "${APP_NAME}-${VERSION}.zip"
cd ..

# Create DMG if create-dmg is available
if command -v create-dmg &> /dev/null; then
    echo -e "\n💿 Creating DMG..."
    create-dmg \
      --volname "Prompt Manager" \
      --window-pos 200 120 \
      --window-size 800 400 \
      --icon-size 100 \
      --icon "${APP_NAME}.app" 200 190 \
      --hide-extension "${APP_NAME}.app" \
      --app-drop-link 600 185 \
      "${RELEASE_DIR}/${APP_NAME}-${VERSION}.dmg" \
      "${RELEASE_DIR}/${APP_NAME}.app" || {
        echo -e "${YELLOW}⚠️  DMG creation failed, but ZIP is available${NC}"
      }
else
    echo -e "${YELLOW}⚠️  create-dmg not found. Install with: brew install create-dmg${NC}"
    echo -e "   Creating basic DMG instead..."

    # Create a simple DMG using hdiutil
    hdiutil create -volname "Prompt Manager" \
      -srcfolder "${RELEASE_DIR}/${APP_NAME}.app" \
      -ov -format UDZO \
      "${RELEASE_DIR}/${APP_NAME}-${VERSION}.dmg"
fi

# Display results
echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✨ Build complete!${NC}\n"
echo "📁 Release files are in: ${RELEASE_DIR}/"
echo ""
ls -lh "$RELEASE_DIR"

echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Test the app on a clean Mac or different user account"
echo "2. Upload to GitHub Releases or your hosting service"
echo "3. Share the download link with users"
echo ""
echo -e "${YELLOW}For notarization (requires Apple Developer account):${NC}"
echo "   See DISTRIBUTION_GUIDE.md for detailed instructions"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
