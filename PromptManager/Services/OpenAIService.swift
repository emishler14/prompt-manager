import Foundation

/// Service for generating prompt names using OpenAI's GPT API
class OpenAIService: AINameGeneratorService {
    static let shared = OpenAIService()

    let provider: AIProvider = .openai
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    private let timeout: TimeInterval = 15.0
    private let model = "gpt-4o-mini"

    private init() {}

    // MARK: - AINameGeneratorService Protocol

    /// Generate a concise name for a prompt using OpenAI GPT
    /// - Parameter content: The prompt content to name
    /// - Returns: A generated name (3-6 words) or nil if failed
    func generateName(for content: String) async -> String? {
        guard let apiKey = KeychainService.getAPIKey(for: provider), !apiKey.isEmpty else {
            Logger.logInfo("No OpenAI API key found - falling back to timestamp", category: .ai)
            return nil
        }

        // Truncate content if too long (to save tokens and speed up response)
        let truncatedContent = String(content.prefix(500))

        let prompt = """
        Generate a concise 3-6 word name for this prompt/text snippet. \
        Return ONLY the name, no quotes, no explanation, no punctuation at the end. \
        The name should capture the main topic or purpose.

        Text: \(truncatedContent)
        """

        do {
            let response = try await callOpenAIAPI(prompt: prompt, apiKey: apiKey)
            let name = cleanGeneratedName(response)
            Logger.logInfo("Generated name: \(name)", category: .ai)
            return name
        } catch let error as AIServiceError {
            Logger.logError("OpenAI API error: \(error.localizedDescription)", category: .ai)
            return nil
        } catch let urlError as URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                Logger.logError("No internet connection - falling back to timestamp", category: .ai)
            case .timedOut:
                Logger.logError("Request timed out - falling back to timestamp", category: .ai)
            case .networkConnectionLost:
                Logger.logError("Network connection lost - falling back to timestamp", category: .ai)
            default:
                Logger.logError("Network error: \(urlError.localizedDescription)", category: .ai)
            }
            return nil
        } catch {
            Logger.logError("Unexpected error: \(error.localizedDescription)", category: .ai)
            return nil
        }
    }

    /// Test the API connection with the stored key
    /// - Returns: A result with success status and message
    func testConnection() async -> (success: Bool, message: String) {
        guard let apiKey = KeychainService.getAPIKey(for: provider), !apiKey.isEmpty else {
            return (false, "No API key stored")
        }

        do {
            let _ = try await callOpenAIAPI(prompt: "Say 'OK' if you can read this.", apiKey: apiKey)
            return (true, "Connected!")
        } catch let error as AIServiceError {
            return (false, error.localizedDescription)
        } catch let urlError as URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return (false, "No internet connection")
            case .timedOut:
                return (false, "Request timed out")
            default:
                return (false, "Network error: \(urlError.localizedDescription)")
            }
        } catch {
            return (false, "Error: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Methods

    private func callOpenAIAPI(prompt: String, apiKey: String) async throws -> String {
        guard let url = URL(string: baseURL) else {
            throw AIServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = timeout

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 50,
            "temperature": 0.7,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            Logger.logDebug("OpenAI API error: HTTP \(httpResponse.statusCode)", category: .ai)

            switch httpResponse.statusCode {
            case 401:
                throw AIServiceError.unauthorized
            case 429:
                throw AIServiceError.rateLimited
            default:
                throw AIServiceError.serverError(statusCode: httpResponse.statusCode)
            }
        }

        // Parse the response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIServiceError.parseError
        }

        return content
    }

    private func cleanGeneratedName(_ rawName: String) -> String {
        var name = rawName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "'", with: "")

        // Remove trailing punctuation
        while let last = name.last, ".!?:;,".contains(last) {
            name.removeLast()
        }

        // Ensure reasonable length (truncate if too long)
        let words = name.split(separator: " ")
        if words.count > 8 {
            name = words.prefix(6).joined(separator: " ")
        }

        // Capitalize first letter of each word for title case
        name = name.capitalized

        return name.isEmpty ? "Untitled Prompt" : name
    }
}
