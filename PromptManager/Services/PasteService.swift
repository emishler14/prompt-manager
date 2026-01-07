import AppKit
import Carbon.HIToolbox

/// Service for auto-pasting text into the previously active application
class PasteService {
    static let shared = PasteService()

    private var previousApp: NSRunningApplication?

    private init() {}

    // MARK: - App Tracking

    /// Store the currently active app (call before showing search panel)
    func storePreviousApp() {
        previousApp = NSWorkspace.shared.frontmostApplication
    }

    /// Get the stored previous app
    func getPreviousApp() -> NSRunningApplication? {
        return previousApp
    }

    // MARK: - Paste Operations

    /// Copy text to clipboard and paste into the previously active app
    /// - Parameters:
    ///   - text: The text to paste
    ///   - completion: Called when paste operation completes
    func pasteText(_ text: String, completion: (() -> Void)? = nil) {
        // 1. Copy text to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // 2. Activate the previous app
        guard let app = previousApp else {
            completion?()
            return
        }

        app.activate(options: .activateIgnoringOtherApps)

        // 3. Small delay to ensure app is focused, then simulate Cmd+V
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.simulatePaste()
            completion?()
        }
    }

    /// Copy text to clipboard without pasting (user will paste manually)
    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    // MARK: - Private Methods

    /// Simulate Cmd+V keypress using CGEvent
    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)

        // Key code for 'V' is 9 (0x09)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) else {
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    /// Activates the previous app without pasting
    func returnToPreviousApp() {
        previousApp?.activate(options: .activateIgnoringOtherApps)
    }
}
