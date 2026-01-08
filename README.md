# Prompt Manager

A native macOS menu bar application for saving, organizing, and quickly accessing text prompts. Perfect for AI enthusiasts, developers, and anyone who frequently uses text snippets.

![macOS](https://img.shields.io/badge/macOS-12.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## Features

- **Menu Bar Integration** - Quick access from your menu bar
- **Global Keyboard Shortcut** - Press `Cmd+Shift+P` (customizable) to:
  - Save selected text as a new prompt
  - Search and paste existing prompts
- **AI-Powered Naming** - Automatically generate descriptive names using Google Gemini API
- **Spotlight-like Search** - Fast, keyboard-driven prompt search
- **Auto-Paste** - Automatically paste selected prompts into the previous app
- **Export/Import** - Backup and restore your prompts
- **Launch at Login** - Optional auto-start

## Installation

### Requirements

- macOS 12.0 (Monterey) or later
- Xcode 15.0+ (for building from source)

### Build from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/prompt-manager.git
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
3. The text is saved as a new prompt with an auto-generated name

### Finding & Using Prompts

1. Press `Cmd+Shift+P` (without selecting text)
2. Type to search your prompts
3. Use arrow keys to navigate
4. Press `Enter` to paste the selected prompt

### Managing Prompts

- Click the menu bar icon to see recent prompts
- Click "Open Prompt Manager" for the full management interface
- Edit, delete, or copy prompts from the main window

### Export/Import

- Use the toolbar buttons in the main window to export or import prompts
- Exports are JSON files that can be shared or backed up

## AI Naming (Optional)

To enable AI-powered prompt naming:

1. Get a free API key from [Google AI Studio](https://aistudio.google.com/apikey)
2. Open **Settings > AI Naming**
3. Enable "AI-generated prompt names"
4. Paste your API key and click "Save Key"
5. Click "Test Connection" to verify

Your API key is stored securely in the macOS Keychain.

## Configuration

### Keyboard Shortcut

Change the global shortcut in **Settings > General > Trigger Shortcut**

### Data Location

Prompts are stored at:
```
~/Library/Application Support/PromptManager/prompts.json
```

## Architecture

```
PromptManager/
├── PromptManagerApp.swift    # App entry point
├── MainWindowView.swift      # Main management UI
├── MenuBarView.swift         # Menu bar popover
├── SettingsView.swift        # Settings window
├── Prompt.swift              # Data model
├── PromptStore.swift         # State management & persistence
├── Constants.swift           # Keyboard shortcut constants
├── Services/
│   ├── AccessibilityService.swift   # Text capture
│   ├── GeminiService.swift          # AI naming
│   ├── KeychainService.swift        # Secure storage
│   ├── PasteService.swift           # Auto-paste
│   ├── BackgroundRenameService.swift # Async renaming
│   ├── NetworkMonitor.swift         # Connectivity
│   └── Logger.swift                 # Logging utility
└── Views/
    ├── SearchPanelView.swift        # Spotlight-like search
    ├── FloatingPanel.swift          # Floating window
    ├── ToastView.swift              # Notifications
    └── OnboardingView.swift         # First-run setup
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
- Uses `os.log` for logging (view with Console.app)
- Thread-safe data store with serial dispatch queue
- Keychain for secure API key storage

## Privacy

- All data is stored locally on your Mac
- No telemetry or analytics
- API keys are stored in your macOS Keychain
- Prompt content is only sent to Gemini API if AI naming is enabled (for name generation only)

## License

MIT License - see [LICENSE](LICENSE) for details

## Acknowledgments

- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) by Sindre Sorhus
