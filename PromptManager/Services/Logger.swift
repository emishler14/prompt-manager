import Foundation
import os.log

/// Centralized logging utility using os.log for proper macOS logging
enum Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.promptmanager.app"

    // MARK: - Log Categories

    private static let accessibility = OSLog(subsystem: subsystem, category: "Accessibility")
    private static let gemini = OSLog(subsystem: subsystem, category: "GeminiAPI")
    private static let storage = OSLog(subsystem: subsystem, category: "Storage")
    private static let backgroundRename = OSLog(subsystem: subsystem, category: "BackgroundRename")
    private static let app = OSLog(subsystem: subsystem, category: "App")

    // MARK: - Logging Methods

    /// Log accessibility-related events
    static func logAccessibility(_ message: String, type: OSLogType = .debug) {
        os_log("%{public}@", log: accessibility, type: type, message)
    }

    /// Log Gemini API events
    static func logGemini(_ message: String, type: OSLogType = .debug) {
        os_log("%{public}@", log: gemini, type: type, message)
    }

    /// Log storage operations
    static func logStorage(_ message: String, type: OSLogType = .debug) {
        os_log("%{public}@", log: storage, type: type, message)
    }

    /// Log background rename service events
    static func logBackgroundRename(_ message: String, type: OSLogType = .debug) {
        os_log("%{public}@", log: backgroundRename, type: type, message)
    }

    /// Log general app events
    static func logApp(_ message: String, type: OSLogType = .debug) {
        os_log("%{public}@", log: app, type: type, message)
    }

    /// Log errors with additional context
    static func logError(_ message: String, error: Error? = nil, category: OSLog? = nil) {
        let log = category ?? app
        if let error = error {
            os_log("%{public}@: %{public}@", log: log, type: .error, message, error.localizedDescription)
        } else {
            os_log("%{public}@", log: log, type: .error, message)
        }
    }
}
