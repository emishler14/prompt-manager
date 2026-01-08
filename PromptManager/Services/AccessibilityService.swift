import Foundation
import AppKit
import ApplicationServices

class AccessibilityService {
    static let shared = AccessibilityService()

    private init() {}

    // MARK: - Permission Checking

    /// Check if accessibility permission is granted
    func isAccessibilityEnabled() -> Bool {
        return AXIsProcessTrusted()
    }

    /// Request accessibility permission (shows system dialog)
    func requestAccessibility() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Text Capture

    /// Get selected text from the frontmost application
    /// Returns nil if no text is selected or if accessibility permission is not granted
    func getSelectedText() -> String? {
        // Try accessibility API first
        Logger.logAccessibility("Trying accessibility API method")
        if let text = getSelectedTextViaAccessibility() {
            Logger.logAccessibility("Got text via accessibility API (\(text.count) chars)")
            return text
        }
        Logger.logAccessibility("Accessibility API returned nil, trying clipboard fallback")

        // Fallback to clipboard method
        let clipboardResult = getSelectedTextViaClipboard()
        Logger.logAccessibility("Clipboard fallback result: \(clipboardResult != nil ? "success" : "nil")")
        return clipboardResult
    }

    /// Primary method: Use Accessibility API to get selected text
    private func getSelectedTextViaAccessibility() -> String? {
        guard isAccessibilityEnabled() else {
            return nil
        }

        // Get the system-wide accessibility element
        let systemWide = AXUIElementCreateSystemWide()

        // Get the focused application
        var focusedApp: CFTypeRef?
        let appResult = AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedApp)

        guard appResult == .success, CFGetTypeID(focusedApp) == AXUIElementGetTypeID() else {
            return nil
        }
        let appElement = focusedApp as! AXUIElement

        // Get the focused UI element within the app
        var focusedElement: CFTypeRef?
        let elementResult = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)

        guard elementResult == .success, CFGetTypeID(focusedElement) == AXUIElementGetTypeID() else {
            return nil
        }
        let element = focusedElement as! AXUIElement

        // Try to get selected text
        var selectedText: CFTypeRef?
        let textResult = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedText)

        if textResult == .success, let text = selectedText as? String, !text.isEmpty {
            return text
        }

        return nil
    }

    /// Fallback method: Copy selected text via clipboard
    /// Saves current clipboard, simulates Cmd+C, reads clipboard, restores original
    private func getSelectedTextViaClipboard() -> String? {
        let pasteboard = NSPasteboard.general

        // Save current clipboard contents
        let originalContents = pasteboard.string(forType: .string)
        let originalChangeCount = pasteboard.changeCount

        // Clear clipboard
        pasteboard.clearContents()

        // Simulate Cmd+C
        simulateCopy()

        // Delay to allow the copy to complete (longer for reliability)
        Thread.sleep(forTimeInterval: 0.2)

        // Check if clipboard changed (meaning copy was successful)
        guard pasteboard.changeCount != originalChangeCount else {
            // Restore original clipboard if copy didn't work
            if let original = originalContents {
                pasteboard.clearContents()
                pasteboard.setString(original, forType: .string)
            }
            return nil
        }

        // Get the copied text
        let copiedText = pasteboard.string(forType: .string)

        // Restore original clipboard contents
        pasteboard.clearContents()
        if let original = originalContents {
            pasteboard.setString(original, forType: .string)
        }

        return copiedText
    }

    /// Simulate Cmd+C keypress using CGEvent
    private func simulateCopy() {
        let source = CGEventSource(stateID: .hidSystemState)

        // Key code for 'C' is 8
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)

        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
