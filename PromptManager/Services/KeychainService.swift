import Foundation
import Security

/// Service for securely storing and retrieving API keys from the macOS Keychain
enum KeychainService {
    private static let service = "com.promptmanager.app"
    private static let apiKeyAccount = "gemini-api-key"

    // MARK: - API Key Operations

    /// Save the Gemini API key to the Keychain
    /// - Parameter key: The API key to store
    /// - Returns: True if successful, false otherwise
    @discardableResult
    static func saveAPIKey(_ key: String) -> Bool {
        // Delete any existing key first
        deleteAPIKey()

        guard let data = key.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Retrieve the Gemini API key from the Keychain
    /// - Returns: The API key if found, nil otherwise
    static func getAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyAccount,
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

    /// Delete the Gemini API key from the Keychain
    /// - Returns: True if successful or key didn't exist, false on error
    @discardableResult
    static func deleteAPIKey() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyAccount
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Check if an API key is stored
    /// - Returns: True if a key exists in the Keychain
    static func hasAPIKey() -> Bool {
        return getAPIKey() != nil
    }
}
