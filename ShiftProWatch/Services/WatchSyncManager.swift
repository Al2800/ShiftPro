import Foundation
import WatchConnectivity
import Combine

/// Manages data synchronization between Apple Watch and iPhone app.
/// Uses WatchConnectivity framework for real-time updates.
@MainActor
final class WatchSyncManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    
    @Published var data: WatchDataContainer = .empty
    @Published var isConnected: Bool = false
    @Published var isReachable: Bool = false
    @Published var lastSyncTime: Date?
    @Published var syncError: String?
    @Published var isPendingAction: Bool = false
    
    // MARK: - Private Properties
    
    private var session: WCSession?
    private let dataKey = "shiftData"
    private let actionKey = "shiftAction"
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupWatchConnectivity()
    }
    
    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else {
            syncError = "Watch Connectivity not supported"
            return
        }
        
        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }
    
    // MARK: - Public Methods
    
    /// Request fresh data from iPhone
    func refreshData() {
        guard let session = session, session.isReachable else {
            syncError = "iPhone not reachable"
            loadCachedData()
            return
        }
        
        isPendingAction = true
        let message: [String: Any] = [actionKey: WatchAction.refreshData.rawValue]
        
        session.sendMessage(message, replyHandler: { [weak self] response in
            Task { @MainActor in
                self?.handleDataResponse(response)
                self?.isPendingAction = false
            }
        }, errorHandler: { [weak self] error in
            Task { @MainActor in
                self?.syncError = error.localizedDescription
                self?.isPendingAction = false
                self?.loadCachedData()
            }
        })
    }
    
    /// Start the current shift
    func startShift() {
        sendAction(.startShift)
    }
    
    /// End the current shift
    func endShift() {
        sendAction(.endShift)
    }
    
    /// Log a break during shift
    func logBreak() {
        sendAction(.logBreak)
    }
    
    /// Mark current time as overtime
    func markOvertime() {
        sendAction(.markOvertime)
    }
    
    // MARK: - Private Methods
    
    private func sendAction(_ action: WatchAction) {
        guard let session = session, session.isReachable else {
            syncError = "iPhone not reachable"
            triggerHaptic(.failure)
            return
        }
        
        isPendingAction = true
        let message: [String: Any] = [actionKey: action.rawValue]
        
        session.sendMessage(message, replyHandler: { [weak self] response in
            Task { @MainActor in
                self?.handleActionResponse(response, action: action)
            }
        }, errorHandler: { [weak self] error in
            Task { @MainActor in
                self?.syncError = error.localizedDescription
                self?.isPendingAction = false
                self?.triggerHaptic(.failure)
            }
        })
    }
    
    private func handleDataResponse(_ response: [String: Any]) {
        guard let jsonData = response[dataKey] as? Data else {
            syncError = "Invalid data format"
            return
        }
        
        do {
            let container = try JSONDecoder().decode(WatchDataContainer.self, from: jsonData)
            self.data = container
            self.lastSyncTime = Date()
            self.syncError = nil
            cacheData(container)
        } catch {
            syncError = "Failed to decode data: \(error.localizedDescription)"
        }
    }
    
    private func handleActionResponse(_ response: [String: Any], action: WatchAction) {
        isPendingAction = false
        
        if let success = response["success"] as? Bool, success {
            triggerHaptic(.success)
            
            if let jsonData = response[dataKey] as? Data {
                do {
                    let container = try JSONDecoder().decode(WatchDataContainer.self, from: jsonData)
                    self.data = container
                    self.lastSyncTime = Date()
                    cacheData(container)
                } catch {
                    // Action succeeded but data update failed
                }
            }
        } else {
            let message = response["message"] as? String ?? "Action failed"
            syncError = message
            triggerHaptic(.failure)
        }
    }
    
    private func triggerHaptic(_ type: WKHapticType) {
        WKInterfaceDevice.current().play(type)
    }
    
    // MARK: - Caching
    
    private func cacheData(_ container: WatchDataContainer) {
        do {
            let jsonData = try JSONEncoder().encode(container)
            UserDefaults.standard.set(jsonData, forKey: "cachedWatchData")
        } catch {
            // Cache failure is non-critical
        }
    }
    
    private func loadCachedData() {
        guard let jsonData = UserDefaults.standard.data(forKey: "cachedWatchData") else {
            return
        }
        
        do {
            let container = try JSONDecoder().decode(WatchDataContainer.self, from: jsonData)
            self.data = container
        } catch {
            // Cache load failure is non-critical
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchSyncManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            self.isConnected = activationState == .activated
            
            if let error = error {
                self.syncError = error.localizedDescription
            } else if activationState == .activated {
                self.refreshData()
            }
        }
    }
    
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
            
            if session.isReachable {
                self.syncError = nil
            }
        }
    }
    
    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor in
            self.handleDataResponse(applicationContext)
        }
    }
    
    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        Task { @MainActor in
            self.handleDataResponse(message)
        }
    }
    
    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        Task { @MainActor in
            self.handleDataResponse(message)
            replyHandler(["received": true])
        }
    }
}
