import Foundation

/// Service for searching prompts with fuzzy matching and optional AI-powered semantic ranking
class SearchService {
    static let shared = SearchService()

    private init() {}

    // MARK: - Local Search with Fuzzy Matching

    /// Search prompts using fuzzy matching, returning scored results
    /// - Parameters:
    ///   - query: The search query
    ///   - prompts: All available prompts
    /// - Returns: Prompts sorted by relevance score (highest first)
    func searchLocal(query: String, in prompts: [Prompt]) -> [ScoredPrompt] {
        guard !query.isEmpty else {
            // No query: return all prompts sorted by usage (most used first)
            return prompts
                .sorted { $0.usageCount > $1.usageCount }
                .map { ScoredPrompt(prompt: $0, score: Double($0.usageCount)) }
        }

        let queryLower = query.lowercased().trimmingCharacters(in: .whitespaces)
        let queryWords = queryLower.split(separator: " ").map { String($0) }

        var scoredPrompts: [ScoredPrompt] = []

        for prompt in prompts {
            let score = calculateScore(query: queryLower, queryWords: queryWords, prompt: prompt)
            if score > 0 {
                scoredPrompts.append(ScoredPrompt(prompt: prompt, score: score))
            }
        }

        // Sort by score (descending), then by usage count for ties
        return scoredPrompts.sorted {
            if abs($0.score - $1.score) < 0.1 {
                return $0.prompt.usageCount > $1.prompt.usageCount
            }
            return $0.score > $1.score
        }
    }

    /// Calculate relevance score for a prompt given a query
    /// Scoring tiers:
    /// - 10000+: Exact name match
    /// - 5000+: Name starts with query
    /// - 1000+: Name contains query phrase
    /// - 500+: All query words in name
    /// - 100+: Some query words in name
    /// - 50+: Query words in content
    /// - 1+: Fuzzy match
    private func calculateScore(query: String, queryWords: [String], prompt: Prompt) -> Double {
        let nameLower = prompt.name.lowercased()
        let contentLower = prompt.content.lowercased()

        var score: Double = 0

        // TIER 1: Exact name match (highest priority)
        if nameLower == query {
            score += 10000
        }
        // TIER 2: Name starts with query
        else if nameLower.hasPrefix(query) {
            score += 5000
        }
        // TIER 3: Name contains query as phrase
        else if nameLower.contains(query) {
            score += 1000
        }

        // TIER 4: All query words appear in name
        let nameWordsMatched = queryWords.filter { nameLower.contains($0) }.count
        if nameWordsMatched == queryWords.count && queryWords.count > 0 {
            score += 500
        }
        // Add points for each word matched in name
        score += Double(nameWordsMatched) * 100

        // TIER 5: Content contains query phrase
        if contentLower.contains(query) {
            score += 50
        }

        // TIER 6: Query words in content
        let contentWordsMatched = queryWords.filter { contentLower.contains($0) }.count
        score += Double(contentWordsMatched) * 10

        // TIER 7: Fuzzy matching for typos (only if no strong matches)
        if score < 100 {
            let fuzzyScore = fuzzyMatch(query: query, prompt: prompt)
            score += fuzzyScore
        }

        // Small usage bonus (doesn't override relevance, just breaks ties)
        score += Double(prompt.usageCount) * 0.1

        return score
    }

    /// Fuzzy match that checks both name and content
    private func fuzzyMatch(query: String, prompt: Prompt) -> Double {
        let nameLower = prompt.name.lowercased()
        let contentLower = prompt.content.lowercased()

        var bestScore: Double = 0

        // Check fuzzy match in name (worth more)
        if let nameScore = fuzzyMatchString(query: query, target: nameLower) {
            bestScore = max(bestScore, nameScore * 50)
        }

        // Check fuzzy match in content
        if let contentScore = fuzzyMatchString(query: query, target: contentLower) {
            bestScore = max(bestScore, contentScore * 10)
        }

        return bestScore
    }

    /// Simple fuzzy match - returns score 0-1 if characters appear in order, nil otherwise
    private func fuzzyMatchString(query: String, target: String) -> Double? {
        guard !query.isEmpty, !target.isEmpty else { return nil }

        var queryIndex = query.startIndex
        var matchPositions: [Int] = []
        var position = 0

        for char in target {
            if queryIndex < query.endIndex && char == query[queryIndex] {
                matchPositions.append(position)
                queryIndex = query.index(after: queryIndex)
            }
            position += 1
        }

        // All query characters must be found in order
        guard queryIndex == query.endIndex else { return nil }

        // Score based on how "tight" the match is (consecutive chars are better)
        var consecutiveBonus: Double = 0
        for i in 1..<matchPositions.count {
            if matchPositions[i] == matchPositions[i-1] + 1 {
                consecutiveBonus += 0.2
            }
        }

        // Base score: query length / target length (longer matches in shorter targets = better)
        let baseScore = Double(query.count) / Double(target.count)

        return min(1.0, baseScore + consecutiveBonus)
    }

    // MARK: - AI Semantic Search

    /// Use AI to semantically rank prompts based on search intent
    /// - Parameters:
    ///   - query: The search query (what user is looking for)
    ///   - prompts: Prompts to rank (typically pre-filtered by local search)
    /// - Returns: Prompts re-ranked by semantic relevance, or nil if AI unavailable
    func searchWithAI(query: String, in prompts: [Prompt]) async -> [ScoredPrompt]? {
        guard !query.isEmpty, !prompts.isEmpty else { return nil }
        guard AIServiceFactory.shared.hasAPIKey() else { return nil }
        guard NetworkMonitor.shared.isConnected else { return nil }

        // Limit to top prompts for efficiency
        let promptsToRank = Array(prompts.prefix(20))

        // Build prompt list for AI
        var promptList = ""
        for (index, prompt) in promptsToRank.enumerated() {
            let truncatedContent = String(prompt.content.prefix(100)).replacingOccurrences(of: "\n", with: " ")
            promptList += "\(index + 1). \"\(prompt.name)\" - \(truncatedContent)\n"
        }

        let aiPrompt = """
        Given the search query: "\(query)"

        Rank these prompts by how relevant they are to the search query. Consider semantic meaning, not just keywords.
        Return ONLY a comma-separated list of numbers representing the ranking from most to least relevant.
        Include ALL prompt numbers. Example format: 3,1,5,2,4

        Prompts:
        \(promptList)

        Ranking (most relevant first):
        """

        guard let ranking = await getAIRanking(prompt: aiPrompt) else {
            return nil
        }

        // Parse the ranking
        let rankedIndices = ranking
            .components(separatedBy: CharacterSet(charactersIn: ",; \n"))
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            .filter { $0 >= 1 && $0 <= promptsToRank.count }

        guard !rankedIndices.isEmpty else { return nil }

        // Build scored results based on AI ranking
        var scoredPrompts: [ScoredPrompt] = []
        var seenIndices = Set<Int>()

        for (rank, index) in rankedIndices.enumerated() {
            let arrayIndex = index - 1 // Convert 1-based to 0-based
            if arrayIndex >= 0 && arrayIndex < promptsToRank.count && !seenIndices.contains(arrayIndex) {
                seenIndices.insert(arrayIndex)
                let score = Double(promptsToRank.count - rank) * 10 + Double(promptsToRank[arrayIndex].usageCount)
                scoredPrompts.append(ScoredPrompt(prompt: promptsToRank[arrayIndex], score: score))
            }
        }

        // Add any prompts not included in ranking at the end
        for (index, prompt) in promptsToRank.enumerated() {
            if !seenIndices.contains(index) {
                scoredPrompts.append(ScoredPrompt(prompt: prompt, score: Double(prompt.usageCount)))
            }
        }

        Logger.logInfo("AI search ranked \(scoredPrompts.count) prompts", category: .ai)
        return scoredPrompts
    }

    /// Call AI to get ranking (simplified call for search)
    private func getAIRanking(prompt: String) async -> String? {
        // Use the current AI service's underlying API
        let provider = AIServiceFactory.shared.selectedProvider

        guard let apiKey = KeychainService.getAPIKey(for: provider), !apiKey.isEmpty else {
            return nil
        }

        do {
            switch provider {
            case .google:
                return try await callGeminiForSearch(prompt: prompt, apiKey: apiKey)
            case .openai:
                return try await callOpenAIForSearch(prompt: prompt, apiKey: apiKey)
            case .anthropic:
                return try await callAnthropicForSearch(prompt: prompt, apiKey: apiKey)
            }
        } catch let urlError as URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                Logger.logError("AI search: No internet connection", category: .ai)
            case .timedOut:
                Logger.logError("AI search: Request timed out", category: .ai)
            case .networkConnectionLost:
                Logger.logError("AI search: Network connection lost", category: .ai)
            default:
                Logger.logError("AI search network error: \(urlError.localizedDescription)", category: .ai)
            }
            return nil
        } catch {
            Logger.logError("AI search error: \(error.localizedDescription)", category: .ai)
            return nil
        }
    }

    private func callGeminiForSearch(prompt: String, apiKey: String) async throws -> String? {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.timeoutInterval = 10

        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": ["temperature": 0.3, "maxOutputTokens": 100]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            return nil
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func callOpenAIForSearch(prompt: String, apiKey: String) async throws -> String? {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": 100,
            "temperature": 0.3
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            return nil
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func callAnthropicForSearch(prompt: String, apiKey: String) async throws -> String? {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 10

        let body: [String: Any] = [
            "model": "claude-3-haiku-20240307",
            "max_tokens": 100,
            "messages": [["role": "user", "content": prompt]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String else {
            return nil
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Supporting Types

struct ScoredPrompt {
    let prompt: Prompt
    let score: Double
}
