import Foundation

/// Input validation and sanitization service
/// Pure functions for data validation following functional programming principles
public final class ValidationService: ValidationServiceProtocol, Sendable {
    
    // CloudKit problematic characters
    private let cloudKitProblematicCharacters = CharacterSet(charactersIn: "\u{0000}\u{0001}\u{0002}\u{0003}\u{0004}\u{0005}\u{0006}\u{0007}\u{0008}\u{0009}\u{000A}\u{000B}\u{000C}\u{000D}\u{000E}\u{000F}\u{007F}\u{200B}\u{200C}\u{200D}\u{FEFF}")
    
    // Injection patterns to detect
    private let injectionPatterns = [
        "<script", "</script>", "javascript:", "eval(", "onclick=", "onerror=",
        "'; DROP TABLE", "1=1", "OR 1=1", "' OR '", "\" OR \"",
        "../", "..\\", "%00", "\u{0000}"
    ]
    
    // Maximum lengths
    private let maxPartyLength = 100
    private let maxItemLength = 200
    private let maxNotesLength = 500
    
    public init() {}
    
    public func validateTransaction(_ dto: TransactionDTO) -> Result<TransactionDTO, ValidationError> {
        // Validate party name
        if dto.party.isEmpty {
            return .failure(.invalidPartyName("Party name cannot be empty"))
        }
        
        if dto.party.count > maxPartyLength {
            return .failure(.excessiveLength(field: "Party name", maxLength: maxPartyLength))
        }
        
        // Check for injection attempts
        if containsInjectionPattern(dto.party) {
            return .failure(.injectionAttempt("Party name contains suspicious patterns"))
        }
        
        // Validate amount or item
        if !dto.isItem {
            if let amount = dto.amount {
                if amount <= 0 {
                    return .failure(.invalidAmount("Amount must be greater than zero"))
                }
                if amount > 999999999 {
                    return .failure(.invalidAmount("Amount exceeds maximum allowed value"))
                }
            } else {
                return .failure(.invalidAmount("Amount is required for non-item transactions"))
            }
        } else {
            if let item = dto.item {
                if item.count > maxItemLength {
                    return .failure(.excessiveLength(field: "Item description", maxLength: maxItemLength))
                }
                if containsInjectionPattern(item) {
                    return .failure(.injectionAttempt("Item description contains suspicious patterns"))
                }
            }
        }
        
        // Validate notes if present
        if let notes = dto.notes {
            if notes.count > maxNotesLength {
                return .failure(.excessiveLength(field: "Notes", maxLength: maxNotesLength))
            }
        }
        
        // Create sanitized DTO
        let sanitizedDTO = TransactionDTO(
            id: dto.id,
            party: sanitizeInput(dto.party, for: .partyName),
            amount: dto.amount,
            item: dto.item.map { sanitizeInput($0, for: .itemDescription) },
            direction: dto.direction,
            isItem: dto.isItem,
            settled: dto.settled,
            timestamp: dto.timestamp,
            dueDate: dto.dueDate,
            notes: dto.notes.map { sanitizeInput($0, for: .notes) },
            cloudKitRecordID: dto.cloudKitRecordID
        )
        
        return .success(sanitizedDTO)
    }
    
    public func sanitizeInput(_ input: String, for field: InputField) -> String {
        var sanitized = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Unicode normalization to prevent homograph attacks
        sanitized = sanitized.precomposedStringWithCanonicalMapping
        
        // Remove CloudKit problematic characters
        sanitized = String(sanitized.unicodeScalars.filter { !cloudKitProblematicCharacters.contains($0) })
        
        // Field-specific sanitization
        switch field {
        case .partyName:
            // Strict: Only allow letters, numbers, spaces, and basic punctuation
            let allowed = CharacterSet.alphanumerics.union(.whitespaces).union(CharacterSet(charactersIn: ".-'"))
            sanitized = String(sanitized.unicodeScalars.filter { allowed.contains($0) })
            sanitized = sanitized.prefix(maxPartyLength).trimmingCharacters(in: .whitespaces)
            
        case .itemDescription:
            // Moderate: Allow more characters but remove dangerous ones
            sanitized = sanitized
                .replacingOccurrences(of: "<", with: "")
                .replacingOccurrences(of: ">", with: "")
                .replacingOccurrences(of: "\"", with: "'")
            sanitized = String(sanitized.prefix(maxItemLength))
            
        case .notes:
            // Lenient: Preserve most user input while ensuring safety
            sanitized = sanitized
                .replacingOccurrences(of: "<script", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "</script>", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "javascript:", with: "", options: .caseInsensitive)
            sanitized = String(sanitized.prefix(maxNotesLength))
            
        case .amount:
            // Numbers only
            let allowed = CharacterSet(charactersIn: "0123456789.")
            sanitized = String(sanitized.unicodeScalars.filter { allowed.contains($0) })
        }
        
        return sanitized
    }
    
    private func containsInjectionPattern(_ input: String) -> Bool {
        let lowercased = input.lowercased()
        return injectionPatterns.contains { pattern in
            lowercased.contains(pattern.lowercased())
        }
    }
}
