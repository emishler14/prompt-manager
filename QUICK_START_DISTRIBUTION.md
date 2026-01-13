# Quick Start: Distributing Your Mac App

This is a condensed guide to get your app ready for distribution quickly.

## TL;DR - Fastest Path

```bash
# Build and package in one command
./build_release.sh

# Upload the resulting .dmg or .zip from the release/ folder to:
# - GitHub Releases, or
# - Your website, or
# - Google Drive / Dropbox
```

## The Two Main Options

### Option 1: Free but with Warnings (Ad-Hoc Signed)

**Pros:**
- Free
- No Apple Developer account needed
- Quick to set up

**Cons:**
- Users see "unidentified developer" warning
- Users must right-click → Open (first time only)

**How to do it:**
1. Just run `./build_release.sh`
2. Upload the resulting file
3. Tell users to right-click and choose "Open" on first launch

### Option 2: Professional (Developer ID + Notarization)

**Pros:**
- No warnings for users
- Professional appearance
- Users can just double-click to open

**Cons:**
- Requires Apple Developer account ($99/year)
- More setup steps

**How to do it:**
1. Sign up for Apple Developer Program
2. Configure code signing in Xcode
3. Build the app
4. Notarize it with Apple
5. Distribute

See `DISTRIBUTION_GUIDE.md` for detailed steps.

## Recommended Approach for First Release

1. **Start with Ad-Hoc (Free) to test distribution**
   - Build with `./build_release.sh`
   - Upload to GitHub Releases
   - Get user feedback

2. **Upgrade to Developer ID later if needed**
   - If you get traction and users request it
   - Provides smoother experience
   - Same build process, just add notarization

## What Users Will Download

You'll give users one of these:

- **`PromptManager-1.0.dmg`** - Mac disk image (double-click to open, drag to Applications)
- **`PromptManager-1.0.zip`** - Compressed file (double-click to extract, then drag to Applications)

Either works fine. DMG looks more professional.

## Testing Before Distribution

1. Build the app with `./build_release.sh`
2. Copy the `.dmg` or `.zip` to a different Mac (or create a test user account)
3. Try installing and opening it
4. Make sure it works correctly

## Creating a GitHub Release

```bash
# Tag your version
git tag -a v1.0 -m "Release version 1.0"
git push origin v1.0

# Then on github.com:
# 1. Go to your repo → Releases → Draft a new release
# 2. Choose tag v1.0
# 3. Upload your .dmg or .zip
# 4. Write release notes
# 5. Publish
```

Users can then download from:
`https://github.com/yourusername/prompt-manager/releases`

## What to Tell Users

### Installation Instructions (for README or release notes)

```markdown
## Installation

1. Download `PromptManager-1.0.dmg` from the latest release
2. Open the DMG file
3. Drag Prompt Manager to Applications
4. **First launch:** Right-click the app and select "Open" (then click "Open" again)
5. Grant Accessibility permissions when prompted

## System Requirements

- macOS 12.0 (Monterey) or later
```

### If Users See "App is damaged"

This is a Gatekeeper issue. Users can fix it with:

```bash
xattr -cr /Applications/PromptManager.app
```

## Next Steps

- Review the full `DISTRIBUTION_GUIDE.md` for advanced options
- Consider code signing and notarization if you want a smoother user experience
- Set up automated builds with GitHub Actions (see guide)

## Common Questions

**Q: Do I need to pay $99 for Apple Developer?**
A: Not required for basic distribution. Users just need to right-click → Open first time.

**Q: Can I use the Mac App Store?**
A: Yes, but it's a different process with more requirements. This guide is for direct distribution.

**Q: Will this work on Apple Silicon and Intel Macs?**
A: Yes, by default Xcode builds a universal binary that works on both.

**Q: How do I update the app later?**
A: Build a new version with updated version number, create a new release. Users download and replace the old app.

**Q: Is my app code signed?**
A: Yes, with ad-hoc signing (for local use). For wider distribution, consider Developer ID.
