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
        if let text = getSelectedTextViaAccessibility() {
            return text
        }

        // Fallback to clipboard method
        return getSelectedTextViaClipboard()
    }

    /// Primary method: Use Accessibility API to get selected text
    private func getSelectedTextViaAccessibility() -> String? {
        guard isAccessibilityEnabled() else {
            return nil
        }

        // Get the system-wide accessibility element
        let systemWide = AXUIElementCreateSystemWide()

        // Get the focused application
        var focusedApp: AnyObject?
        let appResult = AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedApp)

        guard appResult == .success, let appElement = focusedApp else {
            return nil
        }

        // Get the focused UI element within the app
        var focusedElement: AnyObject?
        let elementResult = AXUIElementCopyAttributeValue(appElement as! AXUIElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)

        guard elementResult == .success, let element = focusedElement else {
            return nil
        }

        // Try to get selected text
        var selectedText: AnyObject?
        let textResult = AXUIElementCopyAttributeValue(element as! AXUIElement, kAXSelectedTextAttribute as CFString, &selectedText)

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

        // Small delay to allow the copy to complete
        Thread.sleep(forTimeInterval: 0.1)

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
