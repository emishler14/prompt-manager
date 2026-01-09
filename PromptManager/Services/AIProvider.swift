import Foundation

/// Enum representing different AI service providers
enum AIProvider: String, CaseIterable, Codable {
    case anthropic = "Anthropic (Claude)"
    case openai = "OpenAI (GPT)"
    case google = "Google (Gemini)"

    var id: String {
        switch self {
        case .anthropic: return "anthropic"
        case .openai: return "openai"
        case .google: return "google"
        }
    }

    var displayName: String {
        return self.rawValue
    }

    var apiKeyURL: String {
        switch self {
        case .anthropic:
            return "https://console.anthropic.com/settings/keys"
        case .openai:
            return "https://platform.openai.com/api-keys"
        case .google:
            return "https://aistudio.google.com/apikey"
        }
    }

    var keychainAccount: String {
        return "\(id)-api-key"
    }
}

/// Protocol that all AI naming services must conform to
protocol AINameGeneratorService {
    /// Generate a short name (3-6 words) for the given prompt content
    /// - Parameter content: The prompt content to generate a name for
    /// - Returns: A generated name, or nil if generation failed
    func generateName(for content: String) async -> String?

    /// Test the connection to the AI service
    /// - Returns: A tuple with success status and a message
    func testConnection() async -> (success: Bool, message: String)

    /// The provider type for this service
    var provider: AIProvider { get }
}

/// Errors that can occur when using AI services
enum AIServiceError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidAPIKey
    case unauthorized
    case rateLimited
    case serverError(statusCode: Int)
    case parseError
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from AI service"
        case .invalidAPIKey:
            return "Invalid or missing API key"
        case .unauthorized:
            return "Unauthorized - please check your API key"
        case .rateLimited:
            return "Rate limited - please try again later"
        case .serverError(let statusCode):
            return "Server error (status \(statusCode))"
        case .parseError:
            return "Failed to parse AI response"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
