import SwiftUI
import KeyboardShortcuts

@main
struct PromptManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Main window for prompt management
        WindowGroup("Prompt Manager") {
            MainWindowView(store: appDelegate.promptStore)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        // Settings window for customizing shortcuts
        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    let promptStore = PromptStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupKeyboardShortcuts()
        setDefaultShortcutIfNeeded()

        // Debug: Check accessibility status
        let trusted = AXIsProcessTrusted()
        print("🔑 Accessibility trusted: \(trusted)")

        if let shortcut = KeyboardShortcuts.getShortcut(for: .triggerPromptManager) {
            print("⌨️ Shortcut registered: \(shortcut)")
        } else {
            print("⚠️ No shortcut registered!")
        }

        if !trusted {
            // Prompt for accessibility permission
            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            AXIsProcessTrustedWithOptions(options)
        }
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "text.quote", accessibilityDescription: "Prompt Manager")
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover?.contentSize = NSSize(width: 280, height: 220)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: MenuBarView(promptStore: promptStore))
    }

    private func setupKeyboardShortcuts() {
        KeyboardShortcuts.onKeyUp(for: .triggerPromptManager) { [weak self] in
            self?.handleShortcutTriggered()
        }
    }

    private func setDefaultShortcutIfNeeded() {
        if KeyboardShortcuts.getShortcut(for: .triggerPromptManager) == nil {
            KeyboardShortcuts.setShortcut(.init(.p, modifiers: [.command, .shift]), for: .triggerPromptManager)
        }
    }

    private func handleShortcutTriggered() {
        print("🎯 Hotkey triggered!")
        // Show a simple alert to confirm it works
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Hotkey Detected!"
            alert.informativeText = "Cmd+Shift+P was pressed successfully."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button, let popover = popover else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.title == "Prompt Manager" }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            // Create new window if none exists
            NSApp.sendAction(Selector(("newWindowForTab:")), to: nil, from: nil)
        }
    }
}
