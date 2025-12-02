import Foundation
import LocalAuthentication
import CryptoKit
import os

final class UserManager {
    static let shared = UserManager()

    private let keychain = KeychainHelper.shared
    private let defaults = UserDefaults.standard
    private let logger = OSLog(subsystem: "com.aerofly.EasyFly", category: "UserManager")

    private init() {}

    // Normalize email: trim and lowercase fully
    func normalizeEmail(_ email: String) -> String {
        return email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // SHA-256 hash password for secure storage
    private func hashPassword(_ password: String) -> String {
        guard let data = password.data(using: .utf8) else { return "" }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }

    // MARK: - Credentials
    func createUser(email: String, password: String) -> Bool {
        let e = normalizeEmail(email)
        
        // Check if user already exists (prevent duplicate accounts)
        if hasAccount(email: e) {
            os_log("Email já existe: %{private}@", log: logger, type: .warning, e)
            return false
        }
        
        // Hash password before storage (SHA-256)
        let hashedPassword = hashPassword(password)
        let success = keychain.save(password: hashedPassword, account: e)
        if success {
            os_log("User created: %{private}@", log: logger, type: .info, e)
        } else {
            os_log("Failed to create user: %{private}@", log: logger, type: .error, e)
        }
        return success
    }

    func verifyPassword(email: String, password: String) -> Bool {
        let e = normalizeEmail(email)
        guard !isLocked(email: e) else {
            os_log("Account locked: %{private}@", log: logger, type: .warning, e)
            return false
        }
        if let stored = keychain.readPassword(account: e) {
            let inputHash = hashPassword(password)
            if stored == inputHash {
                resetFailedAttempts(email: e)
                os_log("Password verified: %{private}@", log: logger, type: .info, e)
                return true
            } else {
                recordFailedAttempt(email: e)
                os_log("Password mismatch: %{private}@", log: logger, type: .warning, e)
                return false
            }
        }
        recordFailedAttempt(email: e)
        return false
    }

    func changePassword(email: String, newPassword: String) -> Bool {
        let e = normalizeEmail(email)
        // Hash new password before storage
        let hashedPassword = hashPassword(newPassword)
        let saved = keychain.save(password: hashedPassword, account: e)
        if saved {
            resetFailedAttempts(email: e)
            os_log("Password changed: %{private}@", log: logger, type: .info, e)
        } else {
            os_log("Failed to change password: %{private}@", log: logger, type: .error, e)
        }
        return saved
    }

    // MARK: - Failed attempts & lockout
    private func attemptsKey(_ email: String) -> String { "failedAttempts:\(email)" }
    private func lockKey(_ email: String) -> String { "lockUntil:\(email)" }

    func recordFailedAttempt(email: String) {
        let e = normalizeEmail(email)
        var attempts = defaults.integer(forKey: attemptsKey(e))
        attempts += 1
        defaults.set(attempts, forKey: attemptsKey(e))
        os_log("Failed attempt %d: %{private}@", log: logger, type: .warning, attempts, e)
        if attempts >= 5 {
            // lock for 5 minutes
            let until = Date().addingTimeInterval(5 * 60)
            defaults.set(until, forKey: lockKey(e))
            os_log("Account locked for 5 minutes: %{private}@", log: logger, type: .error, e)
        }
    }

    func resetFailedAttempts(email: String) {
        let e = normalizeEmail(email)
        defaults.removeObject(forKey: attemptsKey(e))
        defaults.removeObject(forKey: lockKey(e))
        os_log("Failed attempts reset: %{private}@", log: logger, type: .info, e)
    }

    func isLocked(email: String) -> Bool {
        let e = normalizeEmail(email)
        if let until = defaults.object(forKey: lockKey(e)) as? Date {
            if Date() < until { return true }
            // expired
            resetFailedAttempts(email: e)
        }
        return false
    }
    
    func getMinutesUntilUnlock(email: String) -> Int {
        let e = normalizeEmail(email)
        if let until = defaults.object(forKey: lockKey(e)) as? Date {
            if Date() < until {
                let remaining = until.timeIntervalSince(Date())
                return Int(ceil(remaining / 60))
            }
        }
        return 0
    }

    // MARK: - Biometrics
    func canEvaluateBiometrics() -> Bool {
        let ctx = LAContext()
        var error: NSError?
        return ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    func authenticateBiometrics(for email: String?, reason: String = "Autenticar") async -> Bool {
        let ctx = LAContext()
        ctx.interactionNotAllowed = false
        return await withCheckedContinuation { cont in
            ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, err in
                if success {
                    // if email provided, check if we have credentials
                    if let e = email.map({ self.normalizeEmail($0) }), !e.isEmpty {
                        if self.keychain.readPassword(account: e) != nil {
                            cont.resume(returning: true)
                            return
                        }
                        cont.resume(returning: false)
                    } else {
                        // no email provided, but biometrics ok
                        cont.resume(returning: true)
                    }
                } else {
                    cont.resume(returning: false)
                }
            }
        }
    }

    func hasAccount(email: String) -> Bool {
        let e = normalizeEmail(email)
        return keychain.readPassword(account: e) != nil
    }

    // MARK: - Password Duplicate Validation
    /// Verifica se a senha já é usada por outro usuário
    /// - Parameters:
    ///   - password: Senha do novo usuário
    ///   - excludeEmail: Email para excluir da busca (do usuário sendo criado)
    /// - Returns: true se a senha já é usada por outro usuário, false caso contrário
    func isPasswordUsedByOtherUser(password: String, excludeEmail: String) -> Bool {
        let normalizedExclude = normalizeEmail(excludeEmail)
        let incomingHash = hashPassword(password)
        
        // Itera por todos os usuários armazenados
        // Nota: Para uma aplicação real com backend, isso seria validado no servidor
        let allAccounts = getAllStoredAccounts()
        
        for account in allAccounts {
            // Não verifica a conta sendo modificada
            if account == normalizedExclude {
                continue
            }
            
            // Compara hash da senha de entrada com hash armazenado
            if let storedHash = keychain.readPassword(account: account) {
                if storedHash == incomingHash {
                    os_log("Password collision detected with account: %{private}@", log: logger, type: .warning, account)
                    return true
                }
            }
        }
        
        return false
    }
    
    /// Retorna lista de todas as contas armazenadas no Keychain
    /// - Returns: Array de emails armazenados
    private func getAllStoredAccounts() -> [String] {
        // Busca todas as entradas no Keychain para este serviço
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.easyfly.credentials",
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let items = result as? [[String: Any]] else {
            return []
        }
        
        return items.compactMap { item in
            item[kSecAttrAccount as String] as? String
        }
    }
}
