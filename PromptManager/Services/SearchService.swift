import Foundation

/// Service for searching prompts with fuzzy matching
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
}

// MARK: - Supporting Types

struct ScoredPrompt {
    let prompt: Prompt
    let score: Double
}
