import SwiftUI
import KeyboardShortcuts
import ServiceManagement

struct SettingsView: View {
    @State private var launchAtLogin: Bool = false
    @State private var launchAtLoginError: String?

    var body: some View {
        generalSettingsTab
            .frame(width: 400, height: 260)
    }

    // MARK: - General Settings Tab

    private var generalSettingsTab: some View {
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

            Divider()

            Text("Startup")
                .font(.headline)

            Toggle("Launch at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { newValue in
                    setLaunchAtLogin(enabled: newValue)
                }

            if let error = launchAtLoginError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            } else {
                Text("Automatically start Prompt Manager when you log in.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .onAppear {
            launchAtLogin = getLaunchAtLoginStatus()
        }
    }

    private func getLaunchAtLoginStatus() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            return false
        }
    }

    private func setLaunchAtLogin(enabled: Bool) {
        launchAtLoginError = nil
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // Revert the toggle and show error
                launchAtLogin = !enabled
                launchAtLoginError = "Failed to update login settings"
                Logger.logError("Launch at login failed: \(error.localizedDescription)", category: .app)
            }
        } else {
            launchAtLoginError = "Requires macOS 13.0 or later"
            launchAtLogin = false
        }
    }
}
