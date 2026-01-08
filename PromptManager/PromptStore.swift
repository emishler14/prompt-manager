import Foundation

class PromptStore: ObservableObject {
    @Published private(set) var prompts: [Prompt] = []

    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.promptmanager.store", qos: .userInitiated)

    /// Maximum allowed prompt content size (1MB)
    static let maxPromptSize = 1_000_000

    init() {
        // ~/Library/Application Support/PromptManager/prompts.json
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("PromptManager", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)

        self.fileURL = appFolder.appendingPathComponent("prompts.json")
        loadAll()
    }

    // MARK: - CRUD Operations

    func loadAll() {
        queue.sync {
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                DispatchQueue.main.async {
                    self.prompts = []
                }
                return
            }

            do {
                let data = try Data(contentsOf: fileURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                var loadedPrompts = try decoder.decode([Prompt].self, from: data)
                // Sort by most recently updated
                loadedPrompts.sort { $0.updatedAt > $1.updatedAt }
                DispatchQueue.main.async {
                    self.prompts = loadedPrompts
                }
            } catch {
                Logger.logStorage("Error loading prompts: \(error.localizedDescription)", type: .error)
                DispatchQueue.main.async {
                    self.prompts = []
                }
            }
        }
    }

    func save(_ prompt: Prompt) {
        // Validate prompt content size
        guard prompt.content.utf8.count <= Self.maxPromptSize else {
            Logger.logStorage("Prompt content exceeds maximum size limit", type: .error)
            return
        }

        queue.async { [weak self] in
            guard let self = self else { return }

            var newPrompt = prompt
            newPrompt.updatedAt = Date()
            // Sanitize name (remove control characters)
            newPrompt.name = newPrompt.name.sanitized

            DispatchQueue.main.async {
                if let index = self.prompts.firstIndex(where: { $0.id == prompt.id }) {
                    self.prompts[index] = newPrompt
                } else {
                    self.prompts.insert(newPrompt, at: 0)
                }
            }

            self.persistSync()
        }
    }

    func delete(id: UUID) {
        queue.async { [weak self] in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.prompts.removeAll { $0.id == id }
            }

            self.persistSync()
        }
    }

    func update(_ prompt: Prompt) {
        save(prompt)
    }

    func incrementUsage(id: UUID) {
        queue.async { [weak self] in
            guard let self = self else { return }

            DispatchQueue.main.async {
                guard let index = self.prompts.firstIndex(where: { $0.id == id }) else { return }
                self.prompts[index].usageCount += 1
                self.prompts[index].updatedAt = Date()
            }

            self.persistSync()
        }
    }

    // MARK: - Export/Import

    /// Export all prompts to a JSON file at the specified URL
    /// - Parameter url: Destination file URL
    /// - Returns: Number of prompts exported, or nil if failed
    func exportPrompts(to url: URL) -> Int? {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

            let exportData = ExportData(
                version: 1,
                exportedAt: Date(),
                prompts: prompts
            )

            let data = try encoder.encode(exportData)
            try data.write(to: url, options: .atomic)
            Logger.logStorage("Exported \(prompts.count) prompts to \(url.lastPathComponent)")
            return prompts.count
        } catch {
            Logger.logStorage("Export failed: \(error.localizedDescription)", type: .error)
            return nil
        }
    }

    /// Import prompts from a JSON file
    /// - Parameters:
    ///   - url: Source file URL
    ///   - merge: If true, merge with existing prompts; if false, replace all
    /// - Returns: Number of prompts imported, or nil if failed
    func importPrompts(from url: URL, merge: Bool = true) -> Int? {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            // Try to decode as ExportData first (new format)
            let importedPrompts: [Prompt]
            if let exportData = try? decoder.decode(ExportData.self, from: data) {
                importedPrompts = exportData.prompts
            } else {
                // Fallback to plain array (legacy format)
                importedPrompts = try decoder.decode([Prompt].self, from: data)
            }

            // Validate imported prompts
            let validPrompts = importedPrompts.filter { $0.content.utf8.count <= Self.maxPromptSize }

            if merge {
                // Merge: add only prompts with new IDs
                let existingIDs = Set(prompts.map { $0.id })
                let newPrompts = validPrompts.filter { !existingIDs.contains($0.id) }
                for prompt in newPrompts {
                    prompts.insert(prompt, at: 0)
                }
                prompts.sort { $0.updatedAt > $1.updatedAt }
                persistSync()
                Logger.logStorage("Imported \(newPrompts.count) new prompts (merged)")
                return newPrompts.count
            } else {
                // Replace all
                prompts = validPrompts
                prompts.sort { $0.updatedAt > $1.updatedAt }
                persistSync()
                Logger.logStorage("Imported \(validPrompts.count) prompts (replaced)")
                return validPrompts.count
            }
        } catch {
            Logger.logStorage("Import failed: \(error.localizedDescription)", type: .error)
            return nil
        }
    }

    /// Get the data directory URL for user reference
    var dataDirectoryURL: URL {
        fileURL.deletingLastPathComponent()
    }

    // MARK: - Persistence

    private func persistSync() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted

            // Get prompts from main thread
            var promptsCopy: [Prompt] = []
            DispatchQueue.main.sync {
                promptsCopy = self.prompts
            }

            let data = try encoder.encode(promptsCopy)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            Logger.logStorage("Error saving prompts: \(error.localizedDescription)", type: .error)
        }
    }
}

// MARK: - Export Data Structure

private struct ExportData: Codable {
    let version: Int
    let exportedAt: Date
    let prompts: [Prompt]
}

// MARK: - String Sanitization

private extension String {
    /// Remove control characters and normalize whitespace
    var sanitized: String {
        let cleaned = self
            .components(separatedBy: .controlCharacters)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Untitled" : cleaned
    }
}
