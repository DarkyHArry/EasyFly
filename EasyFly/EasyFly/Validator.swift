import Foundation

struct Validator {
    static func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // RFC 5321 limit: 254 chars
        guard !trimmed.isEmpty, trimmed.count <= 254 else { return false }
        
        // More restrictive email pattern: standard alphanumeric + common symbols
        let pattern = "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(location: 0, length: trimmed.utf16.count)
        
        guard regex?.firstMatch(in: trimmed, options: [], range: range) != nil else { return false }
        
        // Additional check: no consecutive dots, no leading/trailing dots
        guard !trimmed.contains(".."), !trimmed.hasPrefix("."), !trimmed.hasSuffix(".") else { return false }
        
        // Split and validate local & domain parts
        let parts = trimmed.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2 else { return false }
        
        let localPart = String(parts[0])
        let domainPart = String(parts[1])
        
        // Local part: max 64 chars
        guard !localPart.isEmpty, localPart.count <= 64 else { return false }
        
        // Domain must have at least one dot
        guard domainPart.contains(".") else { return false }
        
        return true
    }

    static func passwordStrengthIssues(_ password: String) -> [String] {
        var issues: [String] = []
        let trimmed = password.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.count < 8 {
            issues.append("Mínimo 8 caracteres")
        }
        
        if trimmed.count > 128 {
            issues.append("Máximo 128 caracteres")
        }

        if trimmed.rangeOfCharacter(from: .uppercaseLetters) == nil {
            issues.append("Incluir pelo menos uma letra maiúscula")
        }

        if trimmed.rangeOfCharacter(from: .lowercaseLetters) == nil {
            issues.append("Incluir pelo menos uma letra minúscula")
        }

        if trimmed.rangeOfCharacter(from: .decimalDigits) == nil {
            issues.append("Incluir pelo menos um número")
        }

        let symbolSet = CharacterSet.punctuationCharacters.union(.symbols)
        if trimmed.rangeOfCharacter(from: symbolSet) == nil {
            issues.append("Incluir pelo menos um símbolo (ex: !@#$%)")
        }

        if isRepeatedCharacters(trimmed) {
            issues.append("Senha não pode ser números ou caracteres repetidos")
        }

        if isDateLike(trimmed) {
            issues.append("Senha não pode ser uma data (ex: aniversário)")
        }
        
        if isCommonPattern(trimmed) {
            issues.append("Senha contém padrão muito comum ou sequência óbvia")
        }

        return issues
    }

    static func strengthScore(_ password: String) -> Int {
        let s = password.trimmingCharacters(in: .whitespacesAndNewlines)
        var score = 0

        if s.count >= 8 { score += 1 }

        if s.rangeOfCharacter(from: .uppercaseLetters) != nil && s.rangeOfCharacter(from: .lowercaseLetters) != nil {
            score += 1
        }

        if s.rangeOfCharacter(from: .decimalDigits) != nil {
            score += 1
        }

        let symbolSet = CharacterSet.punctuationCharacters.union(.symbols)
        if s.rangeOfCharacter(from: symbolSet) != nil {
            score += 1
        }

        // Penalize obvious weak patterns
        if isRepeatedCharacters(s) || isDateLike(s) || isCommonPattern(s) {
            score = max(0, score - 1)
        }

        return min(max(score, 0), 4)
    }

    static func strengthLabelAndColorKey(_ password: String) -> (label: String, key: Int) {
        let score = strengthScore(password)
        switch score {
        case 0...1: return ("Fraca", 0)
        case 2: return ("Média", 1)
        default: return ("Forte", 2)
        }
    }

    private static func isRepeatedCharacters(_ s: String) -> Bool {
        guard !s.isEmpty else { return false }
        let first = s.first!
        return s.allSatisfy { $0 == first }
    }

    private static func isDateLike(_ s: String) -> Bool {
        // Remove tudo exceto dígitos
        let digits = s.compactMap { $0.isNumber ? $0 : nil }
        let digitStr = String(digits)
        if digitStr.count < 6 || digitStr.count > 8 { return false }

        // Try parsing with several common date formats
        let formats = ["ddMMyyyy", "ddMMyy", "yyyyMMdd", "MMddyyyy", "MMyyyy"]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        for fmt in formats {
            formatter.dateFormat = fmt
            if let _ = formatter.date(from: digitStr) {
                return true
            }
        }

        // Also try with separators present in original string
        let cleaned = s.replacingOccurrences(of: "-", with: "/").replacingOccurrences(of: ".", with: "/")
        let sepFormats = ["dd/MM/yyyy", "dd/MM/yy", "yyyy/MM/dd", "MM/dd/yyyy", "MM-dd-yyyy"]
        for fmt in sepFormats {
            formatter.dateFormat = fmt
            if let _ = formatter.date(from: cleaned) {
                return true
            }
        }

        return false
    }
    
    private static func isCommonPattern(_ s: String) -> Bool {
        let common = ["qwerty", "asdfgh", "123456", "password", "admin", "letmein", "welcome", "monkey", "dragon"]
        let lower = s.lowercased()
        
        // Check if password contains common weak patterns
        for pattern in common {
            if lower.contains(pattern) {
                return true
            }
        }
        
        // Check for simple sequences like abcdef or 123456789
        if containsAsciiSequence(lower) || containsNumberSequence(lower) {
            return true
        }
        
        return false
    }
    
    private static func containsAsciiSequence(_ s: String) -> Bool {
        for i in 0..<(s.count - 4) {
            let start = s.index(s.startIndex, offsetBy: i)
            let end = s.index(start, offsetBy: 5)
            let substring = String(s[start..<end])
            
            var isSequence = true
            var lastAscii: UInt32? = nil
            
            for char in substring.unicodeScalars {
                if let last = lastAscii, char.value != last + 1 {
                    isSequence = false
                    break
                }
                lastAscii = char.value
            }
            
            if isSequence { return true }
        }
        return false
    }
    
    private static func containsNumberSequence(_ s: String) -> Bool {
        for i in 0..<(s.count - 4) {
            let start = s.index(s.startIndex, offsetBy: i)
            let end = s.index(start, offsetBy: 5)
            let substring = String(s[start..<end])
            
            let digits = substring.compactMap { Int(String($0)) }
            if digits.count == 5 {
                var isSequence = true
                for j in 0..<(digits.count - 1) {
                    if digits[j + 1] != digits[j] + 1 {
                        isSequence = false
                        break
                    }
                }
                if isSequence { return true }
            }
        }
        return false
    }
}
