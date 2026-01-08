import SwiftUI
import KeyboardShortcuts
import ServiceManagement

struct SettingsView: View {
    @State private var apiKey: String = ""
    @State private var aiNamingEnabled: Bool = AIServiceFactory.shared.isAINamingEnabled
    @State private var isTestingConnection: Bool = false
    @State private var connectionTestResult: ConnectionTestResult?
    @State private var selectedProvider: AIProvider = AIServiceFactory.shared.selectedProvider
    @State private var hasStoredKey: Bool = false
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
        .frame(width: 500, height: 400)
        .onAppear {
            // Load masked key indicator (don't load actual key for security)
            hasStoredKey = KeychainService.hasAPIKey(for: selectedProvider)
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
                            AIServiceFactory.shared.isAINamingEnabled = newValue
                        }

                    Text("When enabled, AI will generate descriptive names for your prompts instead of timestamps.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                // AI Provider Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("AI Provider")
                        .font(.headline)

                    Picker("Provider", selection: $selectedProvider) {
                        ForEach(AIProvider.allCases, id: \.id) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedProvider) { newProvider in
                        AIServiceFactory.shared.selectedProvider = newProvider
                        hasStoredKey = KeychainService.hasAPIKey(for: newProvider)
                        apiKey = ""
                        connectionTestResult = nil
                    }

                    Text("Choose which AI service to use for generating prompt names.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                // API Key Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(selectedProvider.displayName) API Key")
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
                        SecureField("Enter your \(selectedProvider.displayName) API key", text: $apiKey)
                            .textFieldStyle(.roundedBorder)

                        HStack {
                            Button("Save Key") {
                                saveAPIKey()
                            }
                            .disabled(apiKey.isEmpty)

                            if !apiKey.isEmpty {
                                Button("Cancel") {
                                    apiKey = ""
                                    hasStoredKey = KeychainService.hasAPIKey(for: selectedProvider)
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

                    Link("Get a \(selectedProvider.displayName) API key", destination: URL(string: selectedProvider.apiKeyURL)!)
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

        if KeychainService.saveAPIKey(apiKey, for: selectedProvider) {
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
            KeychainService.saveAPIKey(apiKey, for: selectedProvider)
            hasStoredKey = true
            apiKey = ""
        }

        isTestingConnection = true
        connectionTestResult = nil

        Task {
            let service = AIServiceFactory.shared.getService(for: selectedProvider)
            let result = await service.testConnection()

            await MainActor.run {
                isTestingConnection = false
                connectionTestResult = ConnectionTestResult(
                    isSuccess: result.success,
                    message: result.message
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
