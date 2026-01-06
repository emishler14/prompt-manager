import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Keyboard Shortcut")
                .font(.headline)

            HStack {
                Text("Trigger Shortcut:")
                Spacer()
                KeyboardShortcuts.Recorder(for: .triggerPromptManager)
            }

            Text("Press this shortcut to save selected text or search your prompts.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 350, height: 120)
        .padding()
    }
}

#Preview {
    SettingsView()
}
