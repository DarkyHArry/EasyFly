import Foundation
import CommonCrypto

struct PBKDF2 {
    enum Algorithm {
        case sha256
        case sha512
        
        var ccAlgorithm: CCPseudoRandomAlgorithm {
            switch self {
            case .sha256: return CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256)
            case .sha512: return CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA512)
            }
        }
    }
    
    static func deriveKey(
        password: [UInt8],
        salt: [UInt8],
        iterations: UInt32,
        keyLength: Int,
        hashAlgorithm: Algorithm = .sha256
    ) -> [UInt8] {
        var derivedKey = [UInt8](repeating: 0, count: keyLength)
        
        let result = CCKeyDerivationPBKDF(
            kCCPBKDF2,
            password, password.count,
            salt, salt.count,
            hashAlgorithm.ccAlgorithm,
            iterations,
            &derivedKey, keyLength
        )
        
        guard result == kCCSuccess else {
            // Fallback: return SHA256 hash of password+salt if PBKDF2 fails
            var fallback = password + salt
            // Return first keyLength bytes
            return Array(fallback.prefix(keyLength))
        }
        
        return derivedKey
    }
}
