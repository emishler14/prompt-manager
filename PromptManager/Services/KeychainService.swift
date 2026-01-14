import Foundation
import Security

/// Service for securely storing and retrieving API keys from the macOS Keychain
/// Uses the standard keychain for compatibility across archive/distribution scenarios
enum KeychainService {
    private static let service = "com.promptmanager.app"

    // MARK: - API Key Operations

    /// Save an API key to the Keychain for a specific provider
    /// - Parameters:
    ///   - key: The API key to store
    ///   - provider: The AI provider this key is for
    /// - Returns: True if successful, false otherwise
    @discardableResult
    static func saveAPIKey(_ key: String, for provider: AIProvider) -> Bool {
        // Delete any existing key first
        deleteAPIKey(for: provider)

        guard let data = key.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.keychainAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            Logger.logError("Failed to save API key for \(provider.displayName): \(status)", category: .ai)
        }
        return status == errSecSuccess
    }

    /// Retrieve an API key from the Keychain for a specific provider
    /// - Parameter provider: The AI provider to get the key for
    /// - Returns: The API key if found, nil otherwise
    static func getAPIKey(for provider: AIProvider) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status != errSecSuccess && status != errSecItemNotFound {
            Logger.logError("Failed to retrieve API key for \(provider.displayName): \(status)", category: .ai)
        }

        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }

        return key
    }

    /// Delete an API key from the Keychain for a specific provider
    /// - Parameter provider: The AI provider to delete the key for
    /// - Returns: True if successful or key didn't exist, false on error
    @discardableResult
    static func deleteAPIKey(for provider: AIProvider) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.keychainAccount
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Check if an API key is stored for a specific provider
    /// - Parameter provider: The AI provider to check for
    /// - Returns: True if a key exists in the Keychain
    static func hasAPIKey(for provider: AIProvider) -> Bool {
        return getAPIKey(for: provider) != nil
    }

    // MARK: - Legacy Support (for migration)

    /// Get the legacy Gemini API key (for migration purposes)
    /// Checks for old "gemini-api-key" account name
    static func getLegacyGeminiAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "gemini-api-key",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }

        return key
    }

    /// Migrate legacy Gemini API key to new format
    static func migrateLegacyGeminiKey() {
        if let legacyKey = getLegacyGeminiAPIKey() {
            saveAPIKey(legacyKey, for: .google)

            // Delete the legacy key
            let legacyQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: "gemini-api-key"
            ]
            SecItemDelete(legacyQuery as CFDictionary)

            Logger.logInfo("Migrated legacy Gemini API key to new format", category: .ai)
        }
    }
}
