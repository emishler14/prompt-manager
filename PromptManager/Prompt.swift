import Foundation

struct Prompt: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var content: String
    var createdAt: Date
    var updatedAt: Date
    var usageCount: Int

    init(
        id: UUID = UUID(),
        name: String,
        content: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        usageCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.usageCount = usageCount
    }

    /// Creates a prompt with an auto-generated timestamp name
    static func withTimestampName(content: String) -> Prompt {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let name = "Prompt - \(formatter.string(from: Date()))"
        return Prompt(name: name, content: content)
    }

    /// Returns true if this prompt has an auto-generated timestamp name (not user-customized)
    var hasTimestampName: Bool {
        // Match patterns like "Prompt - Jan 7, 2025 at 3:45 PM" or "Prompt - Jan 7, 2025, 3:45 PM"
        name.hasPrefix("Prompt - ") && name.count > 10
    }
}
