import SwiftUI
import KeyboardShortcuts
import ServiceManagement

struct SettingsView: View {
    @State private var apiKey: String = ""
    @State private var aiNamingEnabled: Bool = UserDefaults.standard.bool(forKey: "aiNamingEnabled")
    @State private var isTestingConnection: Bool = false
    @State private var connectionTestResult: ConnectionTestResult?
    @State private var hasStoredKey: Bool = KeychainService.hasAPIKey()
    @State private var launchAtLogin: Bool = false

    var body: some View {
        TabView {
            // General Settings Tab
            generalSettingsTab
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            // AI Settings Tab
            aiSettingsTab
                .tabItem {
                    Label("AI Naming", systemImage: "sparkles")
                }
        }
        .frame(width: 450, height: 320)
        .onAppear {
            // Load masked key indicator (don't load actual key for security)
            hasStoredKey = KeychainService.hasAPIKey()
        }
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

            Text("Automatically start Prompt Manager when you log in.")
                .font(.caption)
                .foregroundColor(.secondary)

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
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // Revert the toggle if operation fails
                launchAtLogin = !enabled
            }
        }
    }

    // MARK: - AI Settings Tab

    private var aiSettingsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // AI Naming Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("AI Naming")
                        .font(.headline)

                    Toggle("Enable AI-generated prompt names", isOn: $aiNamingEnabled)
                        .onChange(of: aiNamingEnabled) { newValue in
                            UserDefaults.standard.set(newValue, forKey: "aiNamingEnabled")
                        }

                    Text("When enabled, Gemini AI will generate descriptive names for your prompts instead of timestamps.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                // API Key Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Gemini API Key")
                        .font(.headline)

                    if hasStoredKey {
                        HStack {
                            Text("API Key:")
                            Spacer()
                            Text("••••••••••••••••")
                                .foregroundColor(.secondary)
                            Button("Change") {
                                hasStoredKey = false
                                apiKey = ""
                            }
                            .buttonStyle(.borderless)
                        }
                    } else {
                        SecureField("Enter your Gemini API key", text: $apiKey)
                            .textFieldStyle(.roundedBorder)

                        HStack {
                            Button("Save Key") {
                                saveAPIKey()
                            }
                            .disabled(apiKey.isEmpty)

                            if !apiKey.isEmpty {
                                Button("Cancel") {
                                    apiKey = ""
                                    hasStoredKey = KeychainService.hasAPIKey()
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }

                    HStack {
                        Button("Test Connection") {
                            testConnection()
                        }
                        .disabled(isTestingConnection || (!hasStoredKey && apiKey.isEmpty))

                        if isTestingConnection {
                            ProgressView()
                                .scaleEffect(0.7)
                        }

                        if let result = connectionTestResult {
                            Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(result.isSuccess ? .green : .red)
                            Text(result.message)
                                .font(.caption)
                                .foregroundColor(result.isSuccess ? .green : .red)
                        }
                    }

                    Link("Get a Gemini API key", destination: URL(string: "https://aistudio.google.com/apikey")!)
                        .font(.caption)

                    Text("Your API key is stored securely in the macOS Keychain.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()
        }
    }

    // MARK: - Actions

    private func saveAPIKey() {
        guard !apiKey.isEmpty else { return }

        if KeychainService.saveAPIKey(apiKey) {
            hasStoredKey = true
            apiKey = ""
            connectionTestResult = ConnectionTestResult(isSuccess: true, message: "Key saved")
        } else {
            connectionTestResult = ConnectionTestResult(isSuccess: false, message: "Failed to save")
        }
    }

    private func testConnection() {
        // If entering a new key, save it first temporarily
        if !apiKey.isEmpty {
            KeychainService.saveAPIKey(apiKey)
            hasStoredKey = true
            apiKey = ""
        }

        isTestingConnection = true
        connectionTestResult = nil

        Task {
            let success = await GeminiService.shared.testConnection()

            await MainActor.run {
                isTestingConnection = false
                connectionTestResult = ConnectionTestResult(
                    isSuccess: success,
                    message: success ? "Connected!" : "Connection failed"
                )
            }
        }
    }
}

// MARK: - Supporting Types

struct ConnectionTestResult {
    let isSuccess: Bool
    let message: String
}

#Preview {
    SettingsView()
}
