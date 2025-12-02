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

        let result: Int32 = password.withUnsafeBufferPointer { pwdBuf in
            salt.withUnsafeBufferPointer { saltBuf in
                // Rebind password bytes to Int8 as CommonCrypto expects a C char* for the password
                let pwdPtr = pwdBuf.baseAddress?.withMemoryRebound(to: Int8.self, capacity: password.count) { $0 }
                let saltPtr = saltBuf.baseAddress

                return CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    pwdPtr,
                    password.count,
                    saltPtr,
                    salt.count,
                    hashAlgorithm.ccAlgorithm,
                    iterations,
                    &derivedKey,
                    keyLength
                )
            }
        }

        guard result == kCCSuccess else {
            // Fallback: return first keyLength bytes of password+salt
            let fallback = password + salt
            return Array(fallback.prefix(keyLength))
        }

        return derivedKey
    }
}
