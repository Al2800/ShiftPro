import Foundation
import LocalAuthentication
import Combine

/// Manages biometric and PIN-based authentication for app access
@MainActor
final class AuthenticationManager: ObservableObject {
    enum AuthMethod: String, Codable {
        case none
        case biometric  // Face ID or Touch ID
        case pin
    }

    enum AuthError: LocalizedError {
        case biometricNotAvailable
        case biometricNotEnrolled
        case authenticationFailed
        case pinNotSet
        case pinInvalid
        case cancelled

        var errorDescription: String? {
            switch self {
            case .biometricNotAvailable:
                return "Biometric authentication is not available on this device"
            case .biometricNotEnrolled:
                return "No biometric credentials are enrolled. Please set up Face ID or Touch ID in Settings."
            case .authenticationFailed:
                return "Authentication failed. Please try again."
            case .pinNotSet:
                return "No PIN is set. Please set a PIN in Security Settings."
            case .pinInvalid:
                return "Incorrect PIN"
            case .cancelled:
                return "Authentication was cancelled"
            }
        }
    }

    enum LockTimeout: Int, CaseIterable, Identifiable, Codable {
        case immediate = 0
        case oneMinute = 60
        case fiveMinutes = 300
        case fifteenMinutes = 900
        case thirtyMinutes = 1800
        case oneHour = 3600

        var id: Int { rawValue }

        var displayName: String {
            switch self {
            case .immediate: return "Immediately"
            case .oneMinute: return "1 minute"
            case .fiveMinutes: return "5 minutes"
            case .fifteenMinutes: return "15 minutes"
            case .thirtyMinutes: return "30 minutes"
            case .oneHour: return "1 hour"
            }
        }
    }

    @Published private(set) var isLocked: Bool = true
    @Published private(set) var authMethod: AuthMethod = .none
    @Published private(set) var lockTimeout: LockTimeout = .immediate
    @Published private(set) var biometricType: LABiometryType = .none

    private let storage: SecureStorage
    private let context = LAContext()
    private var lastActiveTime: Date?
    private var lockTimer: Timer?

    private let authMethodKey = "auth.method"
    private let lockTimeoutKey = "auth.lockTimeout"
    private let pinKey = "auth.pin"

    init(storage: SecureStorage = SecureStorage()) {
        self.storage = storage
        loadSettings()
        updateBiometricType()
        setupNotifications()
    }

    // MARK: - Biometric Support

    func biometricsAvailable() -> Bool {
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    func updateBiometricType() {
        guard biometricsAvailable() else {
            biometricType = .none
            return
        }
        biometricType = context.biometryType
    }

    var biometricDisplayName: String {
        switch biometricType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        default:
            return "Biometric Authentication"
        }
    }

    // MARK: - Authentication Methods

    func authenticate() async throws {
        switch authMethod {
        case .none:
            isLocked = false
        case .biometric:
            try await authenticateWithBiometrics()
        case .pin:
            // PIN authentication requires UI interaction
            // Caller should show PIN entry UI and call authenticateWithPIN
            throw AuthError.pinNotSet
        }
    }

    func authenticateWithBiometrics(reason: String = "Unlock ShiftPro") async throws {
        guard biometricsAvailable() else {
            throw AuthError.biometricNotAvailable
        }

        let context = LAContext()
        context.localizedCancelTitle = "Use PIN"

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )

            if success {
                isLocked = false
                recordActiveTime()
            } else {
                throw AuthError.authenticationFailed
            }
        } catch let error as LAError {
            switch error.code {
            case .biometryNotAvailable:
                throw AuthError.biometricNotAvailable
            case .biometryNotEnrolled:
                throw AuthError.biometricNotEnrolled
            case .userCancel, .systemCancel, .appCancel:
                throw AuthError.cancelled
            default:
                throw AuthError.authenticationFailed
            }
        }
    }

    func authenticateWithPIN(_ pin: String) throws {
        guard let storedPIN = try storage.loadString(forKey: pinKey) else {
            throw AuthError.pinNotSet
        }

        guard pin == storedPIN else {
            throw AuthError.pinInvalid
        }

        isLocked = false
        recordActiveTime()
    }

    // MARK: - Settings Management

    func setAuthMethod(_ method: AuthMethod) throws {
        // Validate method is available
        switch method {
        case .biometric:
            guard biometricsAvailable() else {
                throw AuthError.biometricNotAvailable
            }
        case .pin:
            // Verify PIN is set
            guard (try? storage.loadString(forKey: pinKey)) != nil else {
                throw AuthError.pinNotSet
            }
        case .none:
            break
        }

        authMethod = method
        try storage.save(method.rawValue, forKey: authMethodKey)
    }

    func setPIN(_ pin: String) throws {
        try storage.saveString(pin, forKey: pinKey)

        // If PIN auth was previously set, keep it
        // Otherwise user needs to explicitly enable it
    }

    func clearPIN() throws {
        try storage.delete(forKey: pinKey)

        // If using PIN auth, switch to none
        if authMethod == .pin {
            try setAuthMethod(.none)
        }
    }

    func setLockTimeout(_ timeout: LockTimeout) throws {
        lockTimeout = timeout
        try storage.save(timeout.rawValue, forKey: lockTimeoutKey)
        resetLockTimer()
    }

    // MARK: - Lock Management

    func lock() {
        isLocked = true
        lastActiveTime = nil
        lockTimer?.invalidate()
    }

    func recordActiveTime() {
        lastActiveTime = Date()
        resetLockTimer()
    }

    private func resetLockTimer() {
        lockTimer?.invalidate()

        guard authMethod != .none, lockTimeout != .immediate else {
            return
        }

        lockTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(lockTimeout.rawValue), repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.lock()
            }
        }
    }

    private func checkShouldLock() {
        guard authMethod != .none else { return }

        if lockTimeout == .immediate {
            lock()
            return
        }

        guard let lastActive = lastActiveTime else {
            lock()
            return
        }

        let elapsed = Date().timeIntervalSince(lastActive)
        if elapsed >= TimeInterval(lockTimeout.rawValue) {
            lock()
        }
    }

    // MARK: - Lifecycle

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func handleWillResignActive() {
        recordActiveTime()
    }

    @objc private func handleDidBecomeActive() {
        Task { @MainActor in
            checkShouldLock()
        }
    }

    // MARK: - Persistence

    private func loadSettings() {
        if let methodString: String = try? storage.load(forKey: authMethodKey),
           let method = AuthMethod(rawValue: methodString) {
            authMethod = method
        }

        if let timeoutValue: Int = try? storage.load(forKey: lockTimeoutKey),
           let timeout = LockTimeout(rawValue: timeoutValue) {
            lockTimeout = timeout
        }

        // Start locked if auth is enabled
        isLocked = authMethod != .none
    }
}

// MARK: - UIApplication Import
import UIKit
