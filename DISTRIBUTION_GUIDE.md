# Distribution Guide: Packaging Prompt Manager for Mac

This guide covers how to package Prompt Manager as a downloadable Mac app for distribution outside the App Store.

## Prerequisites

### Option A: Free Distribution (Ad-Hoc Signed)
- Xcode 15.0 or later
- macOS 12.0 or later
- No Apple Developer account needed

### Option B: Professional Distribution (Recommended)
- Xcode 15.0 or later
- macOS 12.0 or later
- Apple Developer Program membership ($99/year)
- Developer ID certificate

## Step 1: Configure Code Signing

### For Free Distribution (Ad-Hoc)

1. Open `PromptManager.xcodeproj` in Xcode
2. Select the **PromptManager** project in the navigator
3. Select the **PromptManager** target
4. Go to **Signing & Capabilities** tab
5. Set:
   - **Team**: None (or your personal team)
   - **Signing Certificate**: Sign to Run Locally

### For Professional Distribution (Developer ID)

1. Join the Apple Developer Program at https://developer.apple.com
2. In Xcode, go to **Xcode > Settings > Accounts**
3. Add your Apple ID and download certificates
4. In your project:
   - **Team**: Select your development team
   - **Signing Certificate**: Developer ID Application

## Step 2: Build the Release Version

### Using Xcode

1. In Xcode, select **Product > Scheme > Edit Scheme**
2. Select **Run** on the left
3. Change **Build Configuration** to **Release**
4. Click **Close**
5. Select **Product > Build** (⌘B)
6. Select **Product > Archive**
7. When the archive completes, the Organizer window opens
8. Click **Distribute App**
9. Select **Copy App** and click **Next**
10. The exported app will be saved to your chosen location

### Using Command Line (Alternative)

```bash
# Build Release version
xcodebuild -project PromptManager.xcodeproj \
  -scheme PromptManager \
  -configuration Release \
  -derivedDataPath ./build \
  clean build

# The app will be at:
# ./build/Build/Products/Release/PromptManager.app
```

## Step 3: Notarization (Optional, Requires Developer ID)

Notarization lets users open your app without warnings. This requires a paid Apple Developer account.

### Notarize the App

```bash
# 1. Create a ZIP of your app
cd /path/to/PromptManager.app
ditto -c -k --keepParent PromptManager.app PromptManager.zip

# 2. Submit for notarization (replace with your credentials)
xcrun notarytool submit PromptManager.zip \
  --apple-id "your@email.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "app-specific-password" \
  --wait

# 3. If successful, staple the notarization ticket
xcrun stapler staple PromptManager.app
```

### Creating an App-Specific Password

1. Go to https://appleid.apple.com
2. Sign in with your Apple ID
3. Go to **Security > App-Specific Passwords**
4. Click **Generate an app-specific password**
5. Use this password in the notarization command

## Step 4: Create a DMG for Distribution

A DMG (disk image) provides a professional installation experience.

### Option A: Using create-dmg (Recommended)

```bash
# Install create-dmg
brew install create-dmg

# Create DMG
create-dmg \
  --volname "Prompt Manager" \
  --volicon "PromptManager/Assets.xcassets/AppIcon.appiconset/icon_512x512.png" \
  --window-pos 200 120 \
  --window-size 800 400 \
  --icon-size 100 \
  --icon "PromptManager.app" 200 190 \
  --hide-extension "PromptManager.app" \
  --app-drop-link 600 185 \
  "PromptManager-1.0.dmg" \
  "path/to/PromptManager.app"
```

### Option B: Using Disk Utility

1. Open **Disk Utility**
2. Select **File > New Image > Image from Folder**
3. Select your `PromptManager.app`
4. Choose **compressed** format
5. Name it `PromptManager-1.0.dmg`
6. Click **Save**

### Option C: Create ZIP (Simpler Alternative)

```bash
# Create a ZIP file
ditto -c -k --keepParent PromptManager.app PromptManager-1.0.zip
```

## Step 5: Test on a Clean Mac

Before distributing:

1. Copy the DMG/ZIP to a different Mac (or a clean user account)
2. Try to open the app
3. Verify it works correctly
4. Check for any security warnings

### Expected User Experience

**With Notarization:**
- User downloads and opens DMG
- Drags app to Applications
- Double-clicks to open - no warnings

**Without Notarization (Ad-Hoc):**
- User downloads and opens DMG
- Drags app to Applications
- Right-clicks app and selects "Open"
- Confirms they want to open it
- App opens successfully

**Unsigned:**
- Multiple security warnings
- Requires System Settings changes
- Not recommended

## Step 6: Distribute

Upload your DMG or ZIP to:

- GitHub Releases
- Your own website
- File hosting service (Dropbox, Google Drive, etc.)

### Creating a GitHub Release

```bash
# Tag the release
git tag -a v1.0 -m "Release version 1.0"
git push origin v1.0

# Then on GitHub:
# 1. Go to Releases
# 2. Click "Draft a new release"
# 3. Select your tag (v1.0)
# 4. Upload your DMG/ZIP
# 5. Publish release
```

## Distribution README Template

Include this information with your release:

```markdown
# Prompt Manager v1.0

## Installation

1. Download `PromptManager-1.0.dmg`
2. Open the DMG file
3. Drag Prompt Manager to your Applications folder
4. Launch from Applications

## First Launch

On first launch, you'll need to grant Accessibility permissions:

1. Open **System Settings > Privacy & Security > Accessibility**
2. Find **Prompt Manager** and toggle it on
3. Restart the app

## System Requirements

- macOS 12.0 (Monterey) or later
- Apple Silicon or Intel Mac

## Support

For issues, visit: https://github.com/yourusername/prompt-manager/issues
```

## Troubleshooting

### "App is damaged and can't be opened"

This happens if the app's signature is broken. Users can fix it:

```bash
xattr -cr /Applications/PromptManager.app
```

### "App is from an unidentified developer"

Users should:
1. Right-click the app
2. Select **Open**
3. Click **Open** in the dialog

### Gatekeeper Issues

If users can't open the app at all:
```bash
sudo spctl --master-disable  # Disable Gatekeeper (not recommended)
# After opening the app once:
sudo spctl --master-enable   # Re-enable Gatekeeper
```

## Updating Your App

For future releases:

1. Update `MARKETING_VERSION` in Xcode project settings
2. Build and archive new version
3. Create new DMG with version number: `PromptManager-1.1.dmg`
4. Create new GitHub release
5. Users download and replace the old app

## Automation (Advanced)

Consider using fastlane for automated builds:

```bash
# Install fastlane
brew install fastlane

# Initialize
cd /path/to/prompt-manager
fastlane init

# Configure Fastfile for building and notarization
```

## Resources

- [Apple Developer Program](https://developer.apple.com/programs/)
- [Code Signing Guide](https://developer.apple.com/support/code-signing/)
- [Notarization Documentation](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [create-dmg tool](https://github.com/create-dmg/create-dmg)
