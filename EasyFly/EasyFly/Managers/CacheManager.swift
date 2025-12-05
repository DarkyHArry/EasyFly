import Foundation
import os

/// Gerenciador de cache para melhorar performance da aplicação.
final class CacheManager {
    static let shared = CacheManager()
    
    private let logger = OSLog(subsystem: "com.aerofly.EasyFly", category: "Cache")
    private var biometricTypeCache: [String: Date] = [:] // email -> cached biometric type + timestamp
    private var emailValidationCache: [String: (isValid: Bool, timestamp: Date)] = [:]
    private let cacheQueue = DispatchQueue(label: "com.easyfly.cache")
    
    // Cache duration: 5 minutes for biometric type, 1 minute for validation
    private let BIOMETRIC_CACHE_DURATION: TimeInterval = 5 * 60
    private let VALIDATION_CACHE_DURATION: TimeInterval = 60
    
    private init() {}
    
    /// Cache do tipo biométrico disponível no dispositivo
    func cachedBiometricType() -> BiometricManager.BiometricType {
        // Biometric type é constante por dispositivo, cachear indefinidamente
        let result = cacheQueue.sync { () -> BiometricManager.BiometricType in
            if let cachedType = UserDefaults.standard.object(forKey: "cached_biometric_type") as? String {
                switch cachedType {
                case "faceID": return .faceID
                case "touchID": return .touchID
                default: return .none
                }
            }
            // Primeira vez: detectar e cachear
            let bioType = BiometricManager.shared.getBiometricType()
            let typeString: String
            switch bioType {
            case .faceID: typeString = "faceID"
            case .touchID: typeString = "touchID"
            case .none: typeString = "none"
            }
            UserDefaults.standard.set(typeString, forKey: "cached_biometric_type")
            os_log("Cached biometric type: %@", log: logger, type: .default, typeString)
            return bioType
        }
        return result
    }
    
    /// Cache para validação de email (válido por 1 minuto)
    func cachedEmailValidation(_ email: String) -> Bool? {
        return cacheQueue.sync {
            if let cached = emailValidationCache[email] {
                if Date().timeIntervalSince(cached.timestamp) < VALIDATION_CACHE_DURATION {
                    os_log("Email validation cache hit: %{private}@", log: logger, type: .default, email)
                    return cached.isValid
                } else {
                    // Cache expirado
                    emailValidationCache.removeValue(forKey: email)
                    return nil
                }
            }
            return nil
        }
    }
    
    /// Armazenar resultado de validação de email em cache
    func cacheEmailValidation(_ email: String, isValid: Bool) {
        cacheQueue.sync {
            emailValidationCache[email] = (isValid: isValid, timestamp: Date())
            os_log("Cached email validation: %{private}@ = %@", log: logger, type: .default, email, isValid ? "valid" : "invalid")
        }
    }
    
    /// Limpar cache quando necessário (e.g., logout)
    func clearCache() {
        cacheQueue.sync {
            emailValidationCache.removeAll()
            os_log("Cache cleared", log: logger, type: .default)
        }
    }
    
    /// Limpar cache de um email específico
    func clearEmailCache(_ email: String) {
        _ = cacheQueue.sync {
            emailValidationCache.removeValue(forKey: email)
        }
    }
}

// MARK: - Performance Utilities

/// Utilities para medir performance e identificar bottlenecks
struct PerformanceMonitor {
    static func measure<T>(name: String, block: () -> T) -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = block()
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        
        let logger = OSLog(subsystem: "com.aerofly.EasyFly", category: "Performance")
        if elapsed > 0.1 { // Log apenas operações que levam > 100ms
            os_log("Performance: %@ took %.3f seconds", log: logger, type: .fault, name, elapsed)
        }
        return result
    }
    
    @discardableResult
    static func measureAsync<T>(_ name: String, block: @escaping () async -> T) async -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = await block()
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        
        let logger = OSLog(subsystem: "com.aerofly.EasyFly", category: "Performance")
        if elapsed > 0.1 {
            os_log("Async Performance: %@ took %.3f seconds", log: logger, type: .fault, name, elapsed)
        }
        return result
    }
}
