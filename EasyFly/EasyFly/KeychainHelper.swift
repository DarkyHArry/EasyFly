import Foundation
import os

final class KeychainHelper {
    static let shared = KeychainHelper()
    
    private let queue = DispatchQueue(label: "com.easyfly.keychain", attributes: .init())
    private let logger = OSLog(subsystem: "com.aerofly.EasyFly", category: "Keychain")

    private init() {}

    func save(password: String, account: String) -> Bool {
        var success = false
        queue.sync {
            guard let data = password.data(using: .utf8) else {
                os_log("Failed to encode password to UTF-8", log: self.logger, type: .error)
                return
            }

            // Delete any existing item first
            let queryDelete: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: account
            ]
            let deleteStatus = SecItemDelete(queryDelete as CFDictionary)
            
            // Only log unexpected delete errors (errSecItemNotFound is OK)
            if deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound {
                os_log("Delete existing item failed: %{public}d", log: self.logger, type: .warning, deleteStatus as CVarArg)
            }

            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: account,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]

            let status = SecItemAdd(query as CFDictionary, nil)
            success = (status == errSecSuccess)
            
            if !success {
                os_log("SecItemAdd failed: %{public}d", log: self.logger, type: .error, status as CVarArg)
            }
        }
        return success
    }

    func readPassword(account: String) -> String? {
        var result: String? = nil
        queue.sync {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: account,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]

            var item: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &item)
            
            guard status == errSecSuccess else {
                if status != errSecItemNotFound {
                    os_log("SecItemCopyMatching failed: %{public}d", log: self.logger, type: .error, status as CVarArg)
                }
                return
            }
            
            guard let data = item as? Data, let password = String(data: data, encoding: .utf8) else {
                os_log("Failed to decode password from data", log: self.logger, type: .error)
                return
            }
            result = password
        }
        return result
    }

    func deletePassword(account: String) {
        queue.sync {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: account
            ]
            let status = SecItemDelete(query as CFDictionary)
            
            if status != errSecSuccess && status != errSecItemNotFound {
                os_log("Delete failed: %{public}d", log: self.logger, type: .warning, status as CVarArg)
            }
        }
    }
}
