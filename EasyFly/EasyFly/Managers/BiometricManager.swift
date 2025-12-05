import Foundation
import LocalAuthentication
import CryptoKit
import os

final class BiometricManager {
    static let shared = BiometricManager()

    private let keychain = KeychainHelper.shared
    private let defaults = UserDefaults.standard
    private let logger = OSLog(subsystem: "com.aerofly.EasyFly", category: "BiometricManager")

    private init() {}

    // MARK: - Biometric Type Detection
    enum BiometricType {
        case none
        case touchID
        case faceID
        
        var description: String {
            switch self {
            case .none: return "Biometria não disponível"
            case .touchID: return "Touch ID"
            case .faceID: return "Face ID"
            }
        }
    }

    func getBiometricType() -> BiometricType {
        let ctx = LAContext()
        var error: NSError?
        
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }

        if #available(iOS 11.0, *) {
            switch ctx.biometryType {
            case .faceID:
                return .faceID
            case .touchID:
                return .touchID
            default:
                return .none
            }
        }
        return .none
    }

    // MARK: - PBKDF2 Key Derivation (Per-User)
    // Derive unique encryption key for each user using PBKDF2
    private func deriveKeyForUser(_ email: String) -> SymmetricKey? {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Get or create per-user salt (stored in UserDefaults for non-sensitive use)
        let saltKey = "biometric_salt:\(normalized)"
        let salt: Data
        
        if let existingSalt = defaults.data(forKey: saltKey) {
            salt = existingSalt
        } else {
            // Generate new salt on first setup
            salt = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
            defaults.set(salt, forKey: saltKey)
            os_log("Generated new salt for: %{private}@", log: self.logger, type: .default, normalized)
        }
        
        // PBKDF2: Derive 256-bit key from email + salt
        // Using email as password (deterministic), 100k iterations
        guard let passwordData = normalized.data(using: .utf8) else { return nil }
        
        let keyBytes = PBKDF2.deriveKey(
            password: Array(passwordData),
            salt: Array(salt),
            iterations: 100_000,
            keyLength: 32, // 256 bits
            hashAlgorithm: .sha256
        )
        
        return SymmetricKey(data: Data(keyBytes))
    }

    // MARK: - Biometric Enrollment & Persistence
    
    func enableBiometricLogin(for email: String) {
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let key = "biometric_enabled:\(e)"
        defaults.set(true, forKey: key)
        os_log("Biometric enabled: %{private}@", log: logger, type: .default, e)
    }

    func disableBiometricLogin(for email: String) {
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let key = "biometric_enabled:\(e)"
        defaults.removeObject(forKey: key)
        let secretKey = "biometric_secret:\(e)"
        defaults.removeObject(forKey: secretKey)
        os_log("Biometric disabled: %{private}@", log: logger, type: .default, e)
    }

    func isBiometricLoginEnabled(for email: String) -> Bool {
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let key = "biometric_enabled:\(e)"
        return defaults.bool(forKey: key)
    }

    // MARK: - Encrypted Storage (Per-User Keys)
    
    // Encrypt secret using per-user derived key via PBKDF2
    private func encryptSecret(_ secret: String, for email: String) -> String? {
        guard let data = secret.data(using: .utf8) else { return nil }
        guard let key = deriveKeyForUser(email) else { return nil }
        
        let sealedBox = try? AES.GCM.seal(data, using: key)
        guard let box = sealedBox else {
            os_log("Failed to encrypt secret for: %{private}@", log: self.logger, type: .fault, email)
            return nil
        }
        
        let encrypted = box.combined?.base64EncodedString() ?? ""
        os_log("Secret encrypted for: %{private}@", log: self.logger, type: .default, email)
        return encrypted
    }

    // Decrypt secret using per-user derived key
    private func decryptSecret(_ encryptedSecret: String, for email: String) -> String? {
        guard let encryptedData = Data(base64Encoded: encryptedSecret) else { return nil }
        guard let key = deriveKeyForUser(email) else { return nil }

        guard let sealedBox = try? AES.GCM.SealedBox(combined: encryptedData) else {
            os_log("Failed to parse sealed box for: %{private}@", log: self.logger, type: .fault, email)
            return nil
        }
        
        guard let decrypted = try? AES.GCM.open(sealedBox, using: key) else {
            os_log("Failed to decrypt secret for: %{private}@", log: self.logger, type: .fault, email)
            return nil
        }
        
        return String(data: decrypted, encoding: .utf8)
    }

    // MARK: - Biometric Authentication with Persistent Storage
    
    func authenticateWithBiometrics(for email: String, reason: String = "Autenticar para acessar sua conta") async -> Bool {
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Check if biometric login is enabled
        guard isBiometricLoginEnabled(for: e) else {
            os_log("Biometric not enabled: %{private}@", log: logger, type: .fault, e)
            return false
        }

        let ctx = LAContext()
        ctx.interactionNotAllowed = false

        return await withCheckedContinuation { cont in
            ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
                if success {
                    os_log("Biometric auth successful: %{private}@", log: self.logger, type: .default, e)
                    cont.resume(returning: true)
                } else {
                    os_log("Biometric auth failed: %{private}@", log: self.logger, type: .fault, e)
                    cont.resume(returning: false)
                }
            }
        }
    }

    // Setup biometric: generate secret + encrypt with per-user key
    func setupBiometricLogin(for email: String) -> Bool {
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Generate random secret unique to this user+device
        let secret = UUID().uuidString
        
        // Encrypt with per-user PBKDF2-derived key
        if let encrypted = encryptSecret(secret, for: e) {
            let secretKey = "biometric_secret:\(e)"
            defaults.set(encrypted, forKey: secretKey)
            enableBiometricLogin(for: e)
            os_log("Biometric setup complete: %{private}@", log: logger, type: .default, e)
            return true
        }
        
        os_log("Biometric setup failed: %{private}@", log: logger, type: .fault, e)
        return false
    }

    // Verify secret integrity
    func verifyBiometricSecret(for email: String) -> Bool {
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let secretKey = "biometric_secret:\(e)"
        
        guard let encrypted = defaults.string(forKey: secretKey) else {
            os_log("No biometric secret found: %{private}@", log: logger, type: .fault, e)
            return false
        }
        let decrypted = decryptSecret(encrypted, for: e)
        let valid = decrypted != nil
        os_log("Biometric secret verification: %{private}@ - %@", log: logger, type: valid ? .default : .fault, e, valid ? "valid" : "invalid")
        return valid
    }

    // MARK: - Clear all biometric data (sign-out)
    func clearBiometricData(for email: String) {
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        disableBiometricLogin(for: e)
        let secretKey = "biometric_secret:\(e)"
        defaults.removeObject(forKey: secretKey)
        os_log("Biometric data cleared: %{private}@", log: logger, type: .default, e)
    }
}
