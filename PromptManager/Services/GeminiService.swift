import Foundation

/// Service for generating prompt names using Google's Gemini API
class GeminiService {
    static let shared = GeminiService()

    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent"
    private let timeout: TimeInterval = 15.0

    private init() {}

    // MARK: - Public API

    /// Generate a concise name for a prompt using Gemini AI
    /// - Parameter content: The prompt content to name
    /// - Returns: A generated name (3-6 words) or nil if failed
    func generateName(for content: String) async -> String? {
        guard let apiKey = KeychainService.getAPIKey(), !apiKey.isEmpty else {
            print("[GeminiService] No API key found - falling back to timestamp")
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
            let response = try await callGeminiAPI(prompt: prompt, apiKey: apiKey)
            let name = cleanGeneratedName(response)
            print("[GeminiService] Generated name: \(name)")
            return name
        } catch let error as GeminiError {
            print("[GeminiService] API error: \(error.localizedDescription)")
            return nil
        } catch {
            print("[GeminiService] Unexpected error: \(error.localizedDescription)")
            return nil
        }
    }

    /// Test the API connection with the stored key
    /// - Returns: A result with success status and message
    func testConnection() async -> (success: Bool, message: String) {
        guard let apiKey = KeychainService.getAPIKey(), !apiKey.isEmpty else {
            return (false, "No API key stored")
        }

        do {
            let _ = try await callGeminiAPI(prompt: "Say 'OK' if you can read this.", apiKey: apiKey)
            return (true, "Connected!")
        } catch let error as GeminiError {
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

    private func callGeminiAPI(prompt: String, apiKey: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)?key=\(apiKey)") else {
            throw GeminiError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout

        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.7,
                "maxOutputTokens": 50
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let bodyString = String(data: data, encoding: .utf8)
            throw GeminiError.apiError(statusCode: httpResponse.statusCode, body: bodyString)
        }

        // Parse the response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw GeminiError.parseError
        }

        return text
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

// MARK: - Error Types

enum GeminiError: Error {
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int, body: String?)
    case parseError

    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .apiError(let statusCode, let body):
            var message = "API error (status \(statusCode))"
            switch statusCode {
            case 400:
                message = "Bad request - check API key format"
            case 401:
                message = "Invalid API key"
            case 403:
                message = "API key doesn't have permission"
            case 429:
                message = "Rate limited - too many requests"
            case 500...599:
                message = "Gemini server error (\(statusCode))"
            default:
                break
            }
            if let body = body {
                print("[GeminiService] Response body: \(body)")
            }
            return message
        case .parseError:
            return "Failed to parse API response"
        }
    }
}
