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
- **AI-Powered Naming** - Automatically generate descriptive names using your choice of AI provider (Anthropic Claude, OpenAI GPT, or Google Gemini)
- **AI-Powered Search** - Semantic search ranking that understands intent, not just keywords
- **Spotlight-like Search** - Fast, keyboard-driven prompt search with fuzzy matching
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
3. The text is saved as a new prompt with an auto-generated name

### Finding & Using Prompts

1. Press `Cmd+Shift+P` (without selecting text)
2. Type to search your prompts
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

## AI Naming (Optional)

To enable AI-powered prompt naming:

1. Open **Settings > AI Naming**
2. Enable "AI-generated prompt names"
3. Select your preferred AI provider:
   - **Anthropic (Claude)** - Get API key from [Anthropic Console](https://console.anthropic.com/settings/keys)
   - **OpenAI (GPT)** - Get API key from [OpenAI Platform](https://platform.openai.com/api-keys)
   - **Google (Gemini)** - Get API key from [Google AI Studio](https://aistudio.google.com/apikey)
4. Paste your API key and click "Save Key"
5. Click "Test Connection" to verify

Your API key is stored securely in the macOS Keychain. You can switch providers at any time.

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
├── PromptManagerApp.swift    # App entry point & AppDelegate
├── MainWindowView.swift      # Main management UI
├── MenuBarView.swift         # Menu bar popover
├── SettingsView.swift        # Settings window (General & AI tabs)
├── Prompt.swift              # Data model
├── PromptStore.swift         # State management & persistence
├── Constants.swift           # Keyboard shortcut constants
├── Services/
│   ├── AccessibilityService.swift    # Text capture from other apps
│   ├── AIProvider.swift              # AI provider enum & protocol
│   ├── AIServiceFactory.swift        # AI service selection & management
│   ├── AnthropicService.swift        # Claude API integration
│   ├── OpenAIService.swift           # GPT API integration
│   ├── GeminiService.swift           # Gemini API integration
│   ├── SearchService.swift           # Local fuzzy + AI semantic search
│   ├── KeychainService.swift         # Secure API key storage
│   ├── PasteService.swift            # Auto-paste to previous app
│   ├── BackgroundRenameService.swift # Async prompt renaming
│   ├── NetworkMonitor.swift          # Connectivity monitoring
│   └── Logger.swift                  # Logging utility
└── Views/
    ├── SearchPanelView.swift         # Spotlight-like search UI
    ├── FloatingPanel.swift           # Floating window container
    ├── ToastView.swift               # Toast notifications
    └── OnboardingView.swift          # First-run setup
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

## Known Limitations

- **Accessibility Permission Required** - The app cannot capture selected text or auto-paste without Accessibility permission enabled in System Settings
- **App Sandbox Disabled** - Required for Accessibility features; the app has full filesystem access
- **AI Features Require Internet** - AI naming and semantic search need an active internet connection
- **API Rate Limits** - Heavy usage may hit rate limits on AI provider APIs (the app includes 0.5s delays between requests)
- **Text Capture Reliability** - Some applications may not support text selection capture via Accessibility API; clipboard-based fallback is used

## Privacy

- All data is stored locally on your Mac
- No telemetry or analytics
- API keys are stored in your macOS Keychain
- Prompt content is only sent to your selected AI provider (Anthropic, OpenAI, or Google) when AI features are enabled:
  - AI naming: first 500 characters sent for name generation
  - AI search: prompt names and first 100 characters sent for semantic ranking

## License

MIT License - see [LICENSE](LICENSE) for details

## Acknowledgments

- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) by Sindre Sorhus
