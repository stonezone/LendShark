import Foundation

// MARK: - Types

/// Result of parsing user input
public enum ParsedAction: Sendable {
    case add(TransactionDTO)
    case settle(String)
}

/// Parsing errors
public enum ParsingError: Error, LocalizedError, Sendable {
    case invalidFormat(String)
    case missingRequiredField(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidFormat(let msg): return msg
        case .missingRequiredField(let field): return "Missing: \(field)"
        }
    }
}

// MARK: - Parser

/// Simple natural language parser per CLAUDE.md
/// Pattern: "[name] owes [amount]", "paid [name]", "i owe [name] [amount]"
/// NO categories, NO analytics, NO over-engineering
public final class ParserService: Sendable {
    
    public init() {}
    
    /// Parse input using either provided abbreviations or internal defaults.
    /// - Parameter abbreviations: Optional slang map (e.g. from SettingsService.abbreviations).
    public func parse(
        _ input: String,
        abbreviations customAbbreviations: [String: Decimal]? = nil
    ) -> Result<ParsedAction, ParsingError> {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return .failure(.invalidFormat("Nothing written. Try 'john owes 50'."))
        }
        
        let lower = text.lowercased()
        let words = lower.split(separator: " ").map { String($0) }
        let abbreviations = customAbbreviations ?? Self.defaultAbbreviations
        
        // Pattern: "settle with [name]" or "settled with [name]"
        if let settleResult = parseSettle(words) {
            return settleResult
        }
        
        // Pattern: "[name] owes [amount]" or "[name] owes me [amount]"
        if let owesResult = parseOwes(words, originalText: text, abbreviations: abbreviations) {
            return owesResult
        }
        
        // Pattern: "i owe [name] [amount]"
        if let iOweResult = parseIOwe(words, originalText: text, abbreviations: abbreviations) {
            return iOweResult
        }
        
        // Pattern: "lent [amount] to [name]"
        if let lentResult = parseLent(words, originalText: text, abbreviations: abbreviations) {
            return lentResult
        }
        
        // Pattern: "borrowed [amount] from [name]"
        if let borrowedResult = parseBorrowed(words, originalText: text, abbreviations: abbreviations) {
            return borrowedResult
        }
        
        // Pattern: "[name] paid [amount]" or "paid [name] [amount]"
        if let paidResult = parsePaid(words, originalText: text, abbreviations: abbreviations) {
            return paidResult
        }
        
        return .failure(.invalidFormat("Didn't catch that. Try 'john owes 50 due 2 weeks at 10%'."))
    }
    
    // MARK: - Parse Patterns
    
    private func parseSettle(_ words: [String]) -> Result<ParsedAction, ParsingError>? {
        guard words.contains("settle") || words.contains("settled") else { return nil }
        
        if let withIdx = words.firstIndex(of: "with"), withIdx + 1 < words.count {
            let name = words[withIdx + 1].capitalized
            return .success(.settle(name))
        }
        return nil
    }
    
    private func parseOwes(
        _ words: [String],
        originalText: String,
        abbreviations: [String: Decimal]
    ) -> Result<ParsedAction, ParsingError>? {
        guard let owesIdx = words.firstIndex(where: { $0 == "owes" || $0 == "owe" }) else { return nil }
        guard owesIdx > 0 else { return nil }

        let name = words[owesIdx - 1].capitalized

        // Skip "me" if present: "[name] owes me [amount]"
        var amountIdx = owesIdx + 1
        if amountIdx < words.count && words[amountIdx] == "me" {
            amountIdx += 1
        }

        guard amountIdx < words.count else { return nil }

        // Try two-word amount first ("2 notes"), then single word
        if let amount = parseAmountFromWords(words, startingAt: amountIdx, abbreviations: abbreviations) {
            let dto = createDTO(party: name, amount: amount, direction: .lent, originalText: originalText)
            return .success(.add(dto))
        }
        return nil
    }
    
    private func parseIOwe(
        _ words: [String],
        originalText: String,
        abbreviations: [String: Decimal]
    ) -> Result<ParsedAction, ParsingError>? {
        guard words.first == "i" else { return nil }
        guard let oweIdx = words.firstIndex(of: "owe"), oweIdx + 2 < words.count else { return nil }

        let name = words[oweIdx + 1].capitalized

        // Try two-word amount first ("2 notes"), then single word
        if let amount = parseAmountFromWords(words, startingAt: oweIdx + 2, abbreviations: abbreviations) {
            let dto = createDTO(party: name, amount: amount, direction: .borrowed, originalText: originalText)
            return .success(.add(dto))
        }
        return nil
    }
    
    private func parseLent(
        _ words: [String],
        originalText: String,
        abbreviations: [String: Decimal]
    ) -> Result<ParsedAction, ParsingError>? {
        guard let lentIdx = words.firstIndex(of: "lent"), lentIdx + 1 < words.count else { return nil }

        guard let amount = parseAmountFromWords(words, startingAt: lentIdx + 1, abbreviations: abbreviations) else { return nil }

        if let toIdx = words.firstIndex(of: "to"), toIdx + 1 < words.count {
            let name = words[toIdx + 1].capitalized
            let dto = createDTO(party: name, amount: amount, direction: .lent, originalText: originalText)
            return .success(.add(dto))
        }
        return nil
    }
    
    private func parseBorrowed(
        _ words: [String],
        originalText: String,
        abbreviations: [String: Decimal]
    ) -> Result<ParsedAction, ParsingError>? {
        guard let borrowedIdx = words.firstIndex(of: "borrowed"), borrowedIdx + 1 < words.count else { return nil }

        guard let amount = parseAmountFromWords(words, startingAt: borrowedIdx + 1, abbreviations: abbreviations) else { return nil }

        if let fromIdx = words.firstIndex(of: "from"), fromIdx + 1 < words.count {
            let name = words[fromIdx + 1].capitalized
            let dto = createDTO(party: name, amount: amount, direction: .borrowed, originalText: originalText)
            return .success(.add(dto))
        }
        return nil
    }
    
    private func parsePaid(
        _ words: [String],
        originalText: String,
        abbreviations: [String: Decimal]
    ) -> Result<ParsedAction, ParsingError>? {
        guard let paidIdx = words.firstIndex(of: "paid") else { return nil }

        // "[name] paid [amount]" - partial payment (creates counter-transaction)
        // Pattern: "john paid 50" or "john paid 2 notes"
        if paidIdx > 0 {
            let name = words[paidIdx - 1].capitalized
            if paidIdx + 1 < words.count,
               let amount = parseAmountFromWords(words, startingAt: paidIdx + 1, abbreviations: abbreviations) {
                // Create partial payment - direction .borrowed means they paid us (reduces debt)
                let dto = TransactionDTO(
                    party: name,
                    amount: amount,
                    direction: .borrowed, // Payment FROM them TO us
                    isItem: false,
                    settled: false, // Must be false so DebtLedger includes it in calculations!
                    notes: "Partial payment"
                )
                return .success(.add(dto))
            }
            // Just "[name] paid" without amount - settle all
            return .success(.settle(name))
        }

        // "paid [name] [amount]" - partial payment
        if paidIdx + 1 < words.count {
            let name = words[paidIdx + 1].capitalized
            // Check if there's an amount after name
            if paidIdx + 2 < words.count,
               let amount = parseAmountFromWords(words, startingAt: paidIdx + 2, abbreviations: abbreviations) {
                let dto = TransactionDTO(
                    party: name,
                    amount: amount,
                    direction: .borrowed,
                    isItem: false,
                    settled: false, // Must be false so DebtLedger includes it in calculations!
                    notes: "Partial payment"
                )
                return .success(.add(dto))
            }
            // Just "paid [name]" - settle all
            return .success(.settle(name))
        }

        return nil
    }
    
    // MARK: - Amount Parsing

    /// Abbreviations for amount parsing (e.g., "note" = $100)
    private static let defaultAbbreviations: [String: Decimal] = [
        "note": 100,
        "k": 1000,
        "point": 1,
        "half": 50,
        "quarter": 25,
        "dime": 10,
        "nickel": 5,
        "buck": 1
    ]

    /// Try to parse amount from words array, checking two-word patterns first ("2 notes"), then single word
    private func parseAmountFromWords(
        _ words: [String],
        startingAt idx: Int,
        abbreviations: [String: Decimal]
    ) -> Decimal? {
        guard idx < words.count else { return nil }

        // Try two-word pattern first: "2 notes", "3 bucks", etc.
        if idx + 1 < words.count {
            let numStr = words[idx]
            let unitStr = words[idx + 1].lowercased()

            // Check if first word is a number and second is an abbreviation
            if let multiplier = Decimal(string: numStr) {
                // Strip trailing 's' for plural forms
                let stripped = unitStr.replacingOccurrences(of: "s$", with: "", options: .regularExpression)
                if let value = abbreviations[stripped] {
                    return multiplier * value
                }
            }
        }

        // Fall back to single-word parsing
        return parseAmount(words[idx], abbreviations: abbreviations)
    }
    
    private func parseAmount(
        _ token: String,
        abbreviations: [String: Decimal]
    ) -> Decimal? {
        let lower = token.lowercased()

        // Try direct number first
        let cleaned = token.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
        if let direct = Decimal(string: cleaned), !cleaned.isEmpty {
            return direct
        }

        // Check abbreviations with multiplier (e.g., "2notes", "3k")
        for (abbr, value) in abbreviations {
            // Pattern: "2notes" or "2 notes"
            if lower.hasSuffix(abbr) || lower.hasSuffix(abbr + "s") {
                let suffix = lower.hasSuffix(abbr + "s") ? abbr + "s" : abbr
                let numPart = String(lower.dropLast(suffix.count))
                if let multiplier = Decimal(string: numPart.trimmingCharacters(in: .whitespaces)) {
                    return multiplier * value
                }
            }
        }

        // Check direct abbreviation match
        let stripped = lower.replacingOccurrences(of: "s$", with: "", options: .regularExpression)
        if let value = abbreviations[stripped] {
            return value
        }

        return nil
    }
    
    // MARK: - Modifier Extraction
    
    /// Extract due date from patterns like "due 2 weeks", "due friday", "due tomorrow"
    private func extractDueDate(from text: String) -> Date? {
        let lower = text.lowercased()
        
        // Pattern: "due X days/weeks" or "due in X days/hours/weeks"
        if let range = lower.range(of: #"due\s+(?:in\s+)?(\d+)\s*(hour|day|week|month)s?"#, options: .regularExpression) {
            let match = String(lower[range])
            let parts = match.components(separatedBy: .whitespaces)
            // Handle "due in X" format - find the number and unit
            let numPattern = #"(\d+)\s*(hour|day|week|month)"#
            if let numRange = match.range(of: numPattern, options: .regularExpression) {
                let numMatch = String(match[numRange])
                let numParts = numMatch.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if numParts.count >= 2, let num = Int(numParts[0]) {
                    let unit = numParts[1]
                    if unit.hasPrefix("hour") {
                        return Calendar.current.date(byAdding: .hour, value: num, to: Date())
                    }
                    var days = num
                    if unit.hasPrefix("week") { days = num * 7 }
                    if unit.hasPrefix("month") { days = num * 30 }
                    return Calendar.current.date(byAdding: .day, value: days, to: Date())
                }
            }
            // Fallback to old parsing for backwards compatibility
            if parts.count >= 3, let num = Int(parts[1]) {
                let unit = parts[2]
                var days = num
                if unit.hasPrefix("week") { days = num * 7 }
                if unit.hasPrefix("month") { days = num * 30 }
                return Calendar.current.date(byAdding: .day, value: days, to: Date())
            }
        }
        
        // Pattern: "due tomorrow"
        if lower.contains("due tomorrow") {
            return Calendar.current.date(byAdding: .day, value: 1, to: Date())
        }
        
        // Pattern: "due next week"
        if lower.contains("due next week") {
            return Calendar.current.date(byAdding: .day, value: 7, to: Date())
        }
        
        return nil
    }
    
    /// Extract interest rate from patterns like "at 10%" or "10% interest"
    private func extractInterestRate(from text: String) -> Decimal? {
        let lower = text.lowercased()
        
        // Pattern: "at X%" or "X% interest" or "X% weekly"
        if let range = lower.range(of: #"(\d+(?:\.\d+)?)\s*%"#, options: .regularExpression) {
            let match = String(lower[range])
            let numStr = match.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
            if let rate = Decimal(string: numStr) {
                return rate / 100 // Convert percentage to decimal
            }
        }
        
        return nil
    }
    
    /// Extract notes/collateral from parentheses: "(has my watch)"
    private func extractNotes(from text: String) -> String? {
        if let start = text.firstIndex(of: "("),
           let end = text.firstIndex(of: ")"),
           start < end {
            let noteStart = text.index(after: start)
            return String(text[noteStart..<end])
        }
        return nil
    }
    
    /// Extract phone number from text
    /// Supports formats: (555) 123-4567, 555-123-4567, 5551234567, 555.123.4567
    private func extractPhoneNumber(from text: String) -> String? {
        // Common phone patterns
        let patterns = [
            #"\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}"#,  // (555) 123-4567 or 555-123-4567
            #"\d{3}[-.\s]\d{4}"#,                       // 555-1234 (7 digit)
            #"\d{10}"#                                   // 5551234567
        ]
        
        for pattern in patterns {
            if let range = text.range(of: pattern, options: .regularExpression) {
                let match = String(text[range])
                // Clean and format the phone number
                let digits = match.filter { $0.isNumber }
                if digits.count >= 7 {
                    return formatPhoneNumber(digits)
                }
            }
        }
        return nil
    }
    
    /// Format phone digits into standard format
    private func formatPhoneNumber(_ digits: String) -> String {
        if digits.count == 10 {
            let areaCode = digits.prefix(3)
            let exchange = digits.dropFirst(3).prefix(3)
            let subscriber = digits.suffix(4)
            return "(\(areaCode)) \(exchange)-\(subscriber)"
        } else if digits.count == 7 {
            let exchange = digits.prefix(3)
            let subscriber = digits.suffix(4)
            return "\(exchange)-\(subscriber)"
        }
        return digits
    }
    
    /// Enhanced DTO creation with modifiers
    private func createDTO(
        party: String,
        amount: Decimal,
        direction: TransactionDTO.TransactionDirection,
        originalText: String
    ) -> TransactionDTO {
        return TransactionDTO(
            party: party,
            amount: amount,
            direction: direction,
            isItem: false,
            dueDate: extractDueDate(from: originalText),
            interestRate: extractInterestRate(from: originalText),
            notes: extractNotes(from: originalText),
            phoneNumber: extractPhoneNumber(from: originalText)
        )
    }
}
