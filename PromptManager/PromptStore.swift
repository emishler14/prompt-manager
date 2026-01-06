import Foundation

class PromptStore: ObservableObject {
    @Published private(set) var prompts: [Prompt] = []

    private let fileURL: URL

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
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            prompts = []
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            prompts = try decoder.decode([Prompt].self, from: data)
            // Sort by most recently updated
            prompts.sort { $0.updatedAt > $1.updatedAt }
        } catch {
            print("Error loading prompts: \(error)")
            prompts = []
        }
    }

    func save(_ prompt: Prompt) {
        var newPrompt = prompt
        newPrompt.updatedAt = Date()

        if let index = prompts.firstIndex(where: { $0.id == prompt.id }) {
            prompts[index] = newPrompt
        } else {
            prompts.insert(newPrompt, at: 0)
        }

        persist()
    }

    func delete(id: UUID) {
        prompts.removeAll { $0.id == id }
        persist()
    }

    func update(_ prompt: Prompt) {
        save(prompt)
    }

    func incrementUsage(id: UUID) {
        guard let index = prompts.firstIndex(where: { $0.id == id }) else { return }
        prompts[index].usageCount += 1
        prompts[index].updatedAt = Date()
        persist()
    }

    // MARK: - Persistence

    private func persist() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(prompts)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Error saving prompts: \(error)")
        }
    }
}
