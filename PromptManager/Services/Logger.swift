import Foundation
import os.log

/// Centralized logging utility using os.log for proper macOS logging
enum Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.promptmanager.app"

    // MARK: - Log Categories

    private static let accessibility = OSLog(subsystem: subsystem, category: "Accessibility")
    private static let storage = OSLog(subsystem: subsystem, category: "Storage")
    private static let app = OSLog(subsystem: subsystem, category: "App")

    enum LogCategory {
        case accessibility
        case storage
        case app

        fileprivate var osLog: OSLog {
            switch self {
            case .accessibility: return Logger.accessibility
            case .storage: return Logger.storage
            case .app: return Logger.app
            }
        }
    }

    // MARK: - Logging Methods

    /// Log accessibility-related events
    static func logAccessibility(_ message: String, type: OSLogType = .debug) {
        os_log("%{public}@", log: accessibility, type: type, message)
    }

    /// Log storage operations
    static func logStorage(_ message: String, type: OSLogType = .debug) {
        os_log("%{public}@", log: storage, type: type, message)
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

    // MARK: - Generic Logging Methods

    /// Log informational message
    static func logInfo(_ message: String, category: LogCategory = .app) {
        os_log("%{public}@", log: category.osLog, type: .info, message)
    }

    /// Log error message
    static func logError(_ message: String, category: LogCategory = .app) {
        os_log("%{public}@", log: category.osLog, type: .error, message)
    }

    /// Log debug message
    static func logDebug(_ message: String, category: LogCategory = .app) {
        os_log("%{public}@", log: category.osLog, type: .debug, message)
    }
}
