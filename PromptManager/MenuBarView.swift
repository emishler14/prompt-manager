import SwiftUI
import KeyboardShortcuts

struct MenuBarView: View {
    @ObservedObject var promptStore: PromptStore

    private var recentPrompts: [Prompt] {
        Array(promptStore.prompts.prefix(5))
    }

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

            // Recent Prompts Section
            if !recentPrompts.isEmpty {
                Divider()

                Text("Recent Prompts")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)

                ForEach(recentPrompts) { prompt in
                    Button(action: { copyToClipboard(prompt) }) {
                        HStack {
                            Text(prompt.name)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Spacer()
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                }
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

    private func copyToClipboard(_ prompt: Prompt) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt.content, forType: .string)
        promptStore.incrementUsage(id: prompt.id)
    }
}

#Preview {
    MenuBarView(promptStore: PromptStore())
}
