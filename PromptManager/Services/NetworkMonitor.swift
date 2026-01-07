import Foundation
import Network

/// Monitors network connectivity and triggers actions when connection is available
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published private(set) var isConnected: Bool = false
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasConnected = self?.isConnected ?? false
                self?.isConnected = path.status == .satisfied

                // Notify when we regain connection
                if !wasConnected && path.status == .satisfied {
                    NotificationCenter.default.post(name: .networkBecameAvailable, object: nil)
                }
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}

extension Notification.Name {
    static let networkBecameAvailable = Notification.Name("networkBecameAvailable")
}
