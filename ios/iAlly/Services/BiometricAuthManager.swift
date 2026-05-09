// BiometricAuthManager.swift
// iAlly — Biometric Authentication Gate (Phase 4)
//
// Provides Face ID / Touch ID protection for iAlly.
// - Gates app access when returning from background after an idle period
// - Re-authenticates after 1-hour idle (configurable)
// - Degrades gracefully on devices without biometrics (passcode fallback)
// - Observable so the main app scene can react to lock state
//
// Usage:
//   BiometricAuthManager.shared.handleScenePhase(.active)
//   if !BiometricAuthManager.shared.isUnlocked { LockScreenView() }

import LocalAuthentication
import SwiftUI
import Observation

// MARK: - BiometricAuthManager

@Observable
@MainActor
final class BiometricAuthManager {

    // MARK: - Shared instance

    static let shared = BiometricAuthManager()

    // MARK: - Observable state

    private(set) var isUnlocked = true          // Start unlocked until first background
    private(set) var biometryType: LABiometryType = .none
    private(set) var isAuthenticating = false
    private(set) var authError: String?

    // MARK: - Configuration

    /// Idle duration (seconds) after which the app re-locks on next foreground. Default: 3600 (1 hour).
    var idleLockThreshold: TimeInterval = 3_600

    /// Whether biometric/passcode lock is enabled. Stored in UserDefaults.
    var isLockEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "ially.biometricLockEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "ially.biometricLockEnabled") }
    }

    // MARK: - Private

    private var backgroundedAt: Date?

    // MARK: - Init

    private init() {
        refreshBiometryType()
    }

    // MARK: - Scene Phase Handling

    /// Call from the main app `.onChange(of: scenePhase)`.
    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background, .inactive:
            backgroundedAt = Date()

        case .active:
            guard isLockEnabled else {
                isUnlocked = true
                return
            }
            guard let backgrounded = backgroundedAt else {
                // First foreground — don't lock
                isUnlocked = true
                return
            }
            let idleDuration = Date().timeIntervalSince(backgrounded)
            if idleDuration >= idleLockThreshold {
                isUnlocked = false
                Task { await authenticate() }
            } else {
                isUnlocked = true
            }

        @unknown default:
            break
        }
    }

    // MARK: - Authentication

    /// Trigger biometric/passcode authentication. Updates `isUnlocked` on completion.
    func authenticate() async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        authError = nil

        let ctx = LAContext()
        var error: NSError?

        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // No biometrics AND no passcode — treat as unlocked
            isUnlocked = true
            isAuthenticating = false
            return
        }

        let reason = "Authenticate to open iAlly"
        do {
            let success = try await ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            isUnlocked = success
            if !success { authError = "Authentication failed" }
        } catch let laError as LAError {
            // User cancelled — keep locked but don't show error
            if laError.code != .userCancel && laError.code != .systemCancel {
                authError = laError.localizedDescription
            }
            isUnlocked = false
        } catch {
            authError = error.localizedDescription
            isUnlocked = false
        }

        isAuthenticating = false
    }

    // MARK: - Biometry Detection

    /// Refresh the detected biometry type (call on init and after settings change).
    func refreshBiometryType() {
        let ctx = LAContext()
        var error: NSError?
        if ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            biometryType = ctx.biometryType
        } else {
            biometryType = .none
        }
    }

    /// Human-readable label for the current biometry type.
    var biometryLabel: String {
        switch biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Passcode"
        }
    }

    /// SF Symbol name for the current biometry type.
    var biometryIcon: String {
        switch biometryType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        default: return "lock.fill"
        }
    }
}

// MARK: - LockScreenView

/// Overlay displayed when the app is locked. Shown over `MainTabView` until biometric auth succeeds.
struct LockScreenView: View {
    @State private var auth = BiometricAuthManager.shared

    var body: some View {
        ZStack {
            DSColors.canvasPrimary.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                Image(systemName: auth.biometryIcon)
                    .font(.system(size: 64))
                    .foregroundColor(.accentColor)

                VStack(spacing: 8) {
                    Text("iAlly is Locked")
                        .font(.title2.bold())
                    Text("Authenticate to continue")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                if let error = auth.authError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button {
                    Task { await auth.authenticate() }
                } label: {
                    if auth.isAuthenticating {
                        ProgressView()
                            .frame(width: 200, height: 50)
                    } else {
                        Label("Unlock with \(auth.biometryLabel)", systemImage: auth.biometryIcon)
                            .frame(width: 200, height: 50)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(auth.isAuthenticating)
                .accessibilityLabel("Unlock with \(auth.biometryLabel)")

                Spacer()
                Spacer()
            }
            .padding()
        }
    }
}
