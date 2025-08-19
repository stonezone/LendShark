import Foundation

/// Natural language parser for transaction input
/// Pure functions following functional programming principles
public final class ParserService: ParserServiceProtocol, Sendable {
    private let validationService: ValidationServiceProtocol
    
    // Common variations for direction indicators
    private let lentVariations = ["lent", "lended", "loaned", "gave", "paid for", "spotted", "covered", "fronted"]
    private let borrowedVariations = ["borrowed", "owe", "owes", "got", "received", "took"]
    private let settleVariations = ["settle", "settled", "paid", "pay", "repaid", "repay", "clear", "cleared", "square", "squared"]
    
    public init(validationService: ValidationServiceProtocol) {
        self.validationService = validationService
    }
    
    public func parse(_ input: String) -> Result<ParsedAction, ParsingError> {
        let sanitizedInput = validationService.sanitizeInput(input.trimmingCharacters(in: .whitespacesAndNewlines), for: .notes)
        
        guard !sanitizedInput.isEmpty else {
            return .failure(.invalidFormat("Input cannot be empty"))
        }
        
        let normalized = sanitizedInput.lowercased()
        
        // Check for settlement action first
        if let settleAction = parseSettlement(normalized) {
            return .success(settleAction)
        }
        
        // Parse as transaction
        return parseTransaction(normalized, originalInput: sanitizedInput)
    }
    
    private func parseSettlement(_ input: String) -> ParsedAction? {
        for settle in settleVariations {
            if input.contains(settle) {
                // Extract party name after settle keyword
                for settleWord in settleVariations {
                    if let range = input.range(of: "\(settleWord) with ") {
                        let party = String(input[range.upperBound...])
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        if !party.isEmpty {
                            let sanitizedParty = validationService.sanitizeInput(party, for: .partyName)
                            return .settle(party: sanitizedParty)
                        }
                    }
                    
                    if let range = input.range(of: "with .* \(settleWord)", options: .regularExpression) {
                        let substring = String(input[range])
                        let components = substring.components(separatedBy: " ")
                        if components.count > 2 {
                            let party = components[1..<components.count-1].joined(separator: " ")
                            let sanitizedParty = validationService.sanitizeInput(party, for: .partyName)
                            return .settle(party: sanitizedParty)
                        }
                    }
                }
            }
        }
        return nil
    }
    
    private func parseTransaction(_ input: String, originalInput: String) -> Result<ParsedAction, ParsingError> {
        var direction: TransactionDTO.TransactionDirection?
        var amount: Decimal?
        var item: String?
        var party: String?
        var isItem = false
        var notes: String?
        var dueDate: Date?
        
        // Determine direction
        for lent in lentVariations {
            if input.contains(lent) {
                direction = .lent
                break
            }
        }
        
        if direction == nil {
            for borrowed in borrowedVariations {
                if input.contains(borrowed) {
                    direction = .borrowed
                    break
                }
            }
        }
        
        guard let transactionDirection = direction else {
            return .failure(.invalidFormat("Could not determine if lending or borrowing. Use words like 'lent', 'borrowed', 'gave', or 'owe'"))
        }
        
        // Extract amount or item
        let amountPattern = #"\$?(\d+\.?\d*)"#
        if let match = input.range(of: amountPattern, options: .regularExpression) {
            let amountString = String(input[match])
                .replacingOccurrences(of: "$", with: "")
            amount = Decimal(string: amountString)
        }
        
        // Check for item indicators
        let itemIndicators = ["my", "the", "a", "an", "their", "his", "her"]
        for indicator in itemIndicators {
            if input.contains(indicator) && amount == nil {
                isItem = true
                // Extract item description
                if let itemMatch = extractItem(from: input, indicators: itemIndicators) {
                    item = validationService.sanitizeInput(itemMatch, for: .itemDescription)
                }
                break
            }
        }
        
        // Extract party name
        let prepositions = transactionDirection == .lent ? ["to", "for"] : ["from", "off"]
        for prep in prepositions {
            if let partyName = extractParty(from: input, preposition: prep) {
                party = validationService.sanitizeInput(partyName, for: .partyName)
                break
            }
        }
        
        // Parse due date patterns
        if let parsedDueDate = parseDueDate(from: input) {
            dueDate = parsedDueDate
        }
        
        // Extract notes (anything in quotes or after "note:" or "memo:")
        if let extractedNotes = extractNotes(from: originalInput) {
            notes = validationService.sanitizeInput(extractedNotes, for: .notes)
        }
        
        guard let partyName = party, !partyName.isEmpty else {
            return .failure(.missingRequiredField("party name"))
        }
        
        if !isItem && amount == nil {
            return .failure(.missingRequiredField("amount or item description"))
        }
        
        let dto = TransactionDTO(
            party: partyName,
            amount: isItem ? nil : amount,
            item: isItem ? item : nil,
            direction: transactionDirection,
            isItem: isItem,
            dueDate: dueDate,
            notes: notes
        )
        
        return .success(.add(dto))
    }
    
    private func extractParty(from input: String, preposition: String) -> String? {
        let pattern = "\(preposition) ([a-zA-Z]+(?:\\s+[a-zA-Z]+)*)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        
        let matches = regex.matches(in: input, range: NSRange(input.startIndex..., in: input))
        guard let match = matches.first, match.numberOfRanges > 1 else {
            return nil
        }
        
        let range = match.range(at: 1)
        guard let swiftRange = Range(range, in: input) else {
            return nil
        }
        
        return String(input[swiftRange])
    }
    
    private func extractItem(from input: String, indicators: [String]) -> String? {
        for indicator in indicators {
            let pattern = "\(indicator) ([a-zA-Z]+(?:\\s+[a-zA-Z]+)*)"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
                continue
            }
            
            let matches = regex.matches(in: input, range: NSRange(input.startIndex..., in: input))
            if let match = matches.first, match.numberOfRanges > 1 {
                let range = match.range(at: 1)
                if let swiftRange = Range(range, in: input) {
                    return String(input[swiftRange])
                }
            }
        }
        return nil
    }
    
    private func parseDueDate(from input: String) -> Date? {
        let calendar = Calendar.current
        let now = Date()
        
        // Common date patterns
        let patterns: [(pattern: String, handler: (String) -> Date?)] = [
            ("tomorrow", { _ in calendar.date(byAdding: .day, value: 1, to: now) }),
            ("next week", { _ in calendar.date(byAdding: .weekOfYear, value: 1, to: now) }),
            ("next month", { _ in calendar.date(byAdding: .month, value: 1, to: now) }),
            ("in (\\d+) days?", { match in
                if let days = Int(match) {
                    return calendar.date(byAdding: .day, value: days, to: now)
                }
                return nil
            }),
            ("in (\\d+) weeks?", { match in
                if let weeks = Int(match) {
                    return calendar.date(byAdding: .weekOfYear, value: weeks, to: now)
                }
                return nil
            })
        ]
        
        for (pattern, handler) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
                continue
            }
            
            let matches = regex.matches(in: input, range: NSRange(input.startIndex..., in: input))
            if let match = matches.first {
                if match.numberOfRanges > 1 {
                    let range = match.range(at: 1)
                    if let swiftRange = Range(range, in: input) {
                        let matchedString = String(input[swiftRange])
                        return handler(matchedString)
                    }
                } else {
                    return handler("")
                }
            }
        }
        
        return nil
    }
    
    private func extractNotes(from input: String) -> String? {
        // Check for quoted text
        let quotePattern = "\"([^\"]*)\""
        if let regex = try? NSRegularExpression(pattern: quotePattern),
           let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)),
           match.numberOfRanges > 1 {
            let range = match.range(at: 1)
            if let swiftRange = Range(range, in: input) {
                return String(input[swiftRange])
            }
        }
        
        // Check for note: or memo: prefix
        let prefixes = ["note:", "memo:", "notes:", "//"]
        for prefix in prefixes {
            if let range = input.range(of: prefix, options: .caseInsensitive) {
                let notes = String(input[range.upperBound...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !notes.isEmpty {
                    return notes
                }
            }
        }
        
        return nil
    }
}
