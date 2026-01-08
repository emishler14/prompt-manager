import Foundation

/// Service that renames timestamp-named prompts using AI when network is available
class BackgroundRenameService {
    static let shared = BackgroundRenameService()

    private var isProcessing = false
    private weak var promptStore: PromptStore?
    private var networkObserver: NSObjectProtocol?

    private init() {}

    /// Start monitoring for network availability to rename prompts
    func start(promptStore: PromptStore) {
        self.promptStore = promptStore

        // Listen for network becoming available
        networkObserver = NotificationCenter.default.addObserver(
            forName: .networkBecameAvailable,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.processTimestampedPrompts()
        }

        // Also check on startup if we're already connected
        if NetworkMonitor.shared.isConnected {
            // Delay slightly to let the app finish launching
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.processTimestampedPrompts()
            }
        }

        Logger.logBackgroundRename("Service started")
    }

    func stop() {
        if let observer = networkObserver {
            NotificationCenter.default.removeObserver(observer)
            networkObserver = nil
        }
    }

    /// Process all prompts with timestamp names
    func processTimestampedPrompts() {
        guard !isProcessing else {
            Logger.logBackgroundRename("Already processing, skipping")
            return
        }

        // Check if AI naming is enabled
        guard UserDefaults.standard.bool(forKey: "aiNamingEnabled") else {
            Logger.logBackgroundRename("AI naming is disabled, skipping")
            return
        }

        // Check if we have an API key
        guard KeychainService.hasAPIKey() else {
            Logger.logBackgroundRename("No API key, skipping")
            return
        }

        // Check if we're connected
        guard NetworkMonitor.shared.isConnected else {
            Logger.logBackgroundRename("No network connection, skipping")
            return
        }

        guard let store = promptStore else {
            Logger.logBackgroundRename("No prompt store available")
            return
        }

        // Find prompts needing rename
        let promptsToRename = store.prompts.filter { $0.hasTimestampName }

        guard !promptsToRename.isEmpty else {
            Logger.logBackgroundRename("No prompts need renaming")
            return
        }

        Logger.logBackgroundRename("Found \(promptsToRename.count) prompts to rename")
        isProcessing = true

        Task {
            await renamePrompts(promptsToRename, store: store)
            await MainActor.run {
                isProcessing = false
            }
        }
    }

    private func renamePrompts(_ prompts: [Prompt], store: PromptStore) async {
        var successCount = 0
        var failCount = 0

        for prompt in prompts {
            // Check we're still connected before each request
            guard NetworkMonitor.shared.isConnected else {
                Logger.logBackgroundRename("Lost connection, pausing")
                break
            }

            Logger.logBackgroundRename("Renaming: \(prompt.name)")

            if let newName = await GeminiService.shared.generateName(for: prompt.content) {
                await MainActor.run {
                    var updatedPrompt = prompt
                    updatedPrompt.name = newName
                    store.update(updatedPrompt)
                }
                successCount += 1
                Logger.logBackgroundRename("Renamed to: \(newName)")
            } else {
                failCount += 1
                Logger.logBackgroundRename("Failed to rename prompt", type: .error)
            }

            // Small delay between requests to avoid rate limiting
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }

        Logger.logBackgroundRename("Complete - \(successCount) renamed, \(failCount) failed")
    }
}
