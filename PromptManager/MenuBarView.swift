import SwiftUI
import KeyboardShortcuts

struct MenuBarView: View {
    @ObservedObject var promptStore: PromptStore

    var body: some View {
        VStack(spacing: 8) {
            Text("Prompt Manager")
                .font(.headline)
                .padding(.top, 8)

            Text("\(promptStore.prompts.count) prompts saved")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            if let shortcut = KeyboardShortcuts.getShortcut(for: .triggerPromptManager) {
                Text("Press \(shortcut.description) to save or search prompts")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Divider()

            Button("Open Prompt Manager") {
                openMainWindow()
            }

            Button("Settings...") {
                openSettings()
            }
            .keyboardShortcut(",")

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
            .padding(.bottom, 8)
        }
        .frame(width: 250)
        .padding(.vertical, 4)
    }

    private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        // Try to find existing window or create new one
        if let window = NSApp.windows.first(where: { $0.title == "Prompt Manager" && $0.isVisible == false }) {
            window.makeKeyAndOrderFront(nil)
        } else if NSApp.windows.filter({ $0.title == "Prompt Manager" }).isEmpty {
            // No window exists, the WindowGroup will create one when app activates
        }
        // Close the popover
        NSApp.windows.first(where: { $0.contentView is NSHostingView<MenuBarView> })?.close()
    }

    private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        // Use the standard macOS 13+ API if available, fallback for older
        if #available(macOS 13.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }
}

#Preview {
    MenuBarView(promptStore: PromptStore())
}
