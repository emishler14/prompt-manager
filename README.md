# Prompt Manager

A native macOS menu bar application for saving, organizing, and quickly accessing text prompts. Perfect for developers, writers, and anyone who frequently uses text snippets.

![macOS](https://img.shields.io/badge/macOS-12.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## Features

- **Menu Bar Integration** - Quick access from your menu bar
- **Global Keyboard Shortcut** - Press `Cmd+Shift+P` (customizable) to:
  - Save selected text as a new prompt
  - Search and paste existing prompts
- **Spotlight-like Search** - Fast, keyboard-driven prompt search with fuzzy matching
- **Auto-Paste** - Automatically paste selected prompts into the previous app
- **Export/Import** - Backup and restore your prompts as JSON
- **Launch at Login** - Optional auto-start

## Installation

### Requirements

- macOS 12.0 (Monterey) or later
- Xcode 15.0+ (for building from source)

### Build from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/emishler14/prompt-manager.git
   cd prompt-manager
   ```

2. Open in Xcode:
   ```bash
   open PromptManager.xcodeproj
   ```

3. Build and run (`Cmd+R`)

### First Launch

On first launch, you'll be prompted to grant **Accessibility permissions**. This is required to:
- Capture selected text from other applications
- Auto-paste prompts into other applications

To enable:
1. Open **System Settings > Privacy & Security > Accessibility**
2. Find **Prompt Manager** and toggle it on

## Usage

### Saving Prompts

1. Select text in any application
2. Press `Cmd+Shift+P`
3. The text is saved as a new prompt with a timestamp name
4. Rename the prompt later from the main window if desired

### Finding & Using Prompts

1. Press `Cmd+Shift+P` (without selecting text)
2. Type to search your prompts (fuzzy matching supported)
3. Use arrow keys to navigate
4. Press `Enter` to paste the selected prompt

### Managing Prompts

- Click the menu bar icon to see recent prompts
- Click "Open Prompt Manager" for the full management interface
- Edit, rename, or delete prompts from the main window
- Select multiple prompts with Cmd+click or Shift+click for bulk operations

### Export/Import

- Use the toolbar buttons in the main window to export or import prompts
- Exports are JSON files that can be shared or backed up

## Configuration

### Keyboard Shortcut

Change the global shortcut in **Settings > Trigger Shortcut**

### Launch at Login

Enable auto-start in **Settings > Launch at Login**

### Data Location

Prompts are stored locally at:
```
~/Library/Application Support/PromptManager/prompts.json
```

No cloud sync or external services are used.

## Architecture

```
PromptManager/
├── PromptManagerApp.swift    # App entry point & AppDelegate
├── MainWindowView.swift      # Main management UI
├── MenuBarView.swift         # Menu bar popover
├── SettingsView.swift        # Settings window
├── Prompt.swift              # Data model
├── PromptStore.swift         # State management & persistence
├── Constants.swift           # Keyboard shortcut constants
├── Services/
│   ├── AccessibilityService.swift  # Text capture from other apps
│   ├── SearchService.swift         # Fuzzy search algorithm
│   ├── PasteService.swift          # Auto-paste to previous app
│   └── Logger.swift                # Logging utility
└── Views/
    ├── SearchPanelView.swift       # Spotlight-like search UI
    ├── FloatingPanel.swift         # Floating window container
    ├── ToastView.swift             # Toast notifications
    └── OnboardingView.swift        # First-run setup
```

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Notes

- Uses SwiftUI for the UI
- Uses `os.log` for logging (view with Console.app, filter by "PromptManager")
- Thread-safe data store with serial dispatch queue
- Prompts validated for size (max 1MB) and content

## Known Limitations

- **Accessibility Permission Required** - The app cannot capture selected text or auto-paste without Accessibility permission enabled in System Settings
- **App Sandbox Disabled** - Required for Accessibility features; the app has full filesystem access
- **Text Capture Reliability** - Some applications may not support text selection capture via Accessibility API; clipboard-based fallback is used
- **Local Storage Only** - Data is not encrypted at rest; prompts are stored as plain JSON

## Privacy

- **All data is stored locally** on your Mac
- **No network connections** - the app is fully offline
- **No telemetry or analytics**
- **No cloud sync** - your prompts never leave your device

## License

MIT License - see [LICENSE](LICENSE) for details

## Acknowledgments

- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) by Sindre Sorhus
