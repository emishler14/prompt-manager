import Foundation

/// Factory for creating and managing AI services
class AIServiceFactory {
    static let shared = AIServiceFactory()

    private init() {
        // Migrate legacy Gemini API key if needed
        KeychainService.migrateLegacyGeminiKey()
    }

    /// Get the currently selected AI provider
    /// - Returns: The selected provider, defaults to Google if none selected
    var selectedProvider: AIProvider {
        get {
            if let providerString = UserDefaults.standard.string(forKey: "selectedAIProvider"),
               let provider = AIProvider.allCases.first(where: { $0.id == providerString }) {
                return provider
            }
            return .google // Default to Google Gemini
        }
        set {
            UserDefaults.standard.set(newValue.id, forKey: "selectedAIProvider")
        }
    }

    /// Get the AI service for the currently selected provider
    /// - Returns: An AI name generator service instance
    func getCurrentService() -> AINameGeneratorService {
        return getService(for: selectedProvider)
    }

    /// Get the AI service for a specific provider
    /// - Parameter provider: The AI provider to get the service for
    /// - Returns: An AI name generator service instance
    func getService(for provider: AIProvider) -> AINameGeneratorService {
        switch provider {
        case .anthropic:
            return AnthropicService.shared
        case .openai:
            return OpenAIService.shared
        case .google:
            return GeminiService.shared
        }
    }

    /// Check if the current provider has an API key configured
    /// - Returns: True if an API key is configured
    func hasAPIKey() -> Bool {
        return KeychainService.hasAPIKey(for: selectedProvider)
    }

    /// Check if AI naming is enabled
    /// - Returns: True if AI naming is enabled
    var isAINamingEnabled: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "aiNamingEnabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "aiNamingEnabled")
        }
    }
}
