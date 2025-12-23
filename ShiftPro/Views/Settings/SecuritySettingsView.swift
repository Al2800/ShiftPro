import SwiftUI
import LocalAuthentication

struct SecuritySettingsView: View {
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var privacyManager = PrivacyManager()

    @State private var showPINSetup = false
    @State private var showPINEntry = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var pendingAuthMethod: AuthenticationManager.AuthMethod?

    var body: some View {
        Form {
            authMethodSection
            lockTimeoutSection
            biometricInfoSection
            dangerZoneSection
        }
        .navigationTitle("Security")
        .sheet(isPresented: $showPINSetup) {
            PINSetupView { pin in
                handlePINSetup(pin)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    private var authMethodSection: some View {
        Section {
            Picker("Authentication", selection: Binding(
                get: { authManager.authMethod },
                set: { newMethod in
                    handleAuthMethodChange(newMethod)
                }
            )) {
                Text("None").tag(AuthenticationManager.AuthMethod.none)

                if authManager.biometricsAvailable() {
                    Text(authManager.biometricDisplayName).tag(AuthenticationManager.AuthMethod.biometric)
                }

                Text("PIN").tag(AuthenticationManager.AuthMethod.pin)
            }
            .font(ShiftProTypography.body)
        } header: {
            Text("App Lock")
        } footer: {
            Text(authMethodFooter)
                .font(ShiftProTypography.caption)
        }
    }

    private var lockTimeoutSection: some View {
        Section {
            Picker("Lock After", selection: Binding(
                get: { authManager.lockTimeout },
                set: { newTimeout in
                    handleLockTimeoutChange(newTimeout)
                }
            )) {
                ForEach(AuthenticationManager.LockTimeout.allCases) { timeout in
                    Text(timeout.displayName).tag(timeout)
                }
            }
            .font(ShiftProTypography.body)
            .disabled(authManager.authMethod == .none)
        } header: {
            Text("Auto-Lock Timeout")
        } footer: {
            Text("App will automatically lock after this period of inactivity")
                .font(ShiftProTypography.caption)
        }
    }

    private var biometricInfoSection: some View {
        Group {
            if authManager.biometricsAvailable() {
                Section {
                    HStack {
                        Image(systemName: authManager.biometricType == .faceID ? "faceid" : "touchid")
                            .foregroundStyle(ShiftProColors.accent)
                        Text("\(authManager.biometricDisplayName) Available")
                            .font(ShiftProTypography.body)
                    }

                    Button {
                        Task {
                            await testBiometrics()
                        }
                    } label: {
                        Text("Test \(authManager.biometricDisplayName)")
                            .font(ShiftProTypography.body)
                    }
                } header: {
                    Text("Biometric Authentication")
                }
            }
        }
    }

    private var dangerZoneSection: some View {
        Section {
            Button(role: .destructive) {
                handleResetSecurity()
            } label: {
                Text("Reset Security Settings")
                    .font(ShiftProTypography.body)
            }
        } header: {
            Text("Danger Zone")
        } footer: {
            Text("This will remove all security settings including saved PIN")
                .font(ShiftProTypography.caption)
        }
    }

    private var authMethodFooter: String {
        switch authManager.authMethod {
        case .none:
            return "App is not locked. Anyone with access to your device can view shift data."
        case .biometric:
            return "App will require \(authManager.biometricDisplayName) to unlock."
        case .pin:
            return "App will require PIN entry to unlock."
        }
    }

    // MARK: - Actions

    private func handleAuthMethodChange(_ newMethod: AuthenticationManager.AuthMethod) {
        switch newMethod {
        case .pin:
            // Check if PIN is already set
            pendingAuthMethod = newMethod
            showPINSetup = true

        case .biometric:
            do {
                try authManager.setAuthMethod(.biometric)
                try privacyManager.logAudit(
                    type: .securitySettingChanged,
                    description: "Enabled \(authManager.biometricDisplayName) authentication"
                )
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }

        case .none:
            do {
                try authManager.setAuthMethod(.none)
                try privacyManager.logAudit(
                    type: .securitySettingChanged,
                    description: "Disabled authentication"
                )
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func handlePINSetup(_ pin: String) {
        do {
            try authManager.setPIN(pin)
            try authManager.setAuthMethod(.pin)
            try privacyManager.logAudit(
                type: .securitySettingChanged,
                description: "Enabled PIN authentication"
            )
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func handleLockTimeoutChange(_ newTimeout: AuthenticationManager.LockTimeout) {
        do {
            try authManager.setLockTimeout(newTimeout)
            try privacyManager.logAudit(
                type: .securitySettingChanged,
                description: "Changed lock timeout to \(newTimeout.displayName)"
            )
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func testBiometrics() async {
        do {
            try await authManager.authenticateWithBiometrics(reason: "Test biometric authentication")
            // Success - app is unlocked
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func handleResetSecurity() {
        do {
            try authManager.clearPIN()
            try authManager.setAuthMethod(.none)
            try authManager.setLockTimeout(.immediate)
            try privacyManager.logAudit(
                type: .securitySettingChanged,
                description: "Reset all security settings"
            )
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - PIN Setup View

struct PINSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pin = ""
    @State private var confirmPin = ""
    @State private var showError = false
    @State private var errorMessage = ""

    let onComplete: (String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Enter PIN", text: $pin)
                        .keyboardType(.numberPad)
                        .font(ShiftProTypography.body)

                    SecureField("Confirm PIN", text: $confirmPin)
                        .keyboardType(.numberPad)
                        .font(ShiftProTypography.body)
                } header: {
                    Text("Set PIN")
                } footer: {
                    Text("Choose a secure 4-6 digit PIN")
                        .font(ShiftProTypography.caption)
                }
            }
            .navigationTitle("Setup PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        handleSave()
                    }
                    .disabled(!isValid)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var isValid: Bool {
        pin.count >= 4 && pin.count <= 6 && pin == confirmPin
    }

    private func handleSave() {
        guard isValid else {
            errorMessage = "PINs must match and be 4-6 digits"
            showError = true
            return
        }

        onComplete(pin)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        SecuritySettingsView()
    }
}
