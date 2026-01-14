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

            if #available(macOS 14.0, *) {
                SettingsLink {
                    Text("Settings...")
                }
                .keyboardShortcut(",")
            } else {
                Button("Settings...") {
                    NSApp.sendAction(NSSelectorFromString("showSettingsWindow:"), to: nil, from: nil)
                }
                .keyboardShortcut(",")
            }

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
        // Bring app to foreground
        NSApp.activate(ignoringOtherApps: true)

        // Find existing Prompt Manager window
        if let window = NSApp.windows.first(where: { $0.title == "Prompt Manager" }) {
            // Window exists - bring it to front
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        } else {
            // No window exists - create one
            // Use openWindow environment action via notification
            NotificationCenter.default.post(name: NSNotification.Name("OpenMainWindow"), object: nil)
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
