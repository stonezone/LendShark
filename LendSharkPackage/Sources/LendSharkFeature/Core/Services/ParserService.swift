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
    
    public func parse(_ input: String) -> Result<ParsedAction, ParsingError> {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return .failure(.invalidFormat("Nothing written. Try 'john owes 50'."))
        }
        
        let lower = text.lowercased()
        let words = lower.split(separator: " ").map { String($0) }
        
        // Pattern: "settle with [name]" or "settled with [name]"
        if let settleResult = parseSettle(words) {
            return settleResult
        }
        
        // Pattern: "[name] owes [amount]" or "[name] owes me [amount]"
        if let owesResult = parseOwes(words) {
            return owesResult
        }
        
        // Pattern: "i owe [name] [amount]"
        if let iOweResult = parseIOwe(words) {
            return iOweResult
        }
        
        // Pattern: "lent [amount] to [name]"
        if let lentResult = parseLent(words) {
            return lentResult
        }
        
        // Pattern: "borrowed [amount] from [name]"
        if let borrowedResult = parseBorrowed(words) {
            return borrowedResult
        }
        
        // Pattern: "[name] paid [amount]" or "paid [name] [amount]"
        if let paidResult = parsePaid(words) {
            return paidResult
        }
        
        return .failure(.invalidFormat("Didn't catch that. Try 'john owes 50' or 'lent 20 to sarah'."))
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
    
    private func parseOwes(_ words: [String]) -> Result<ParsedAction, ParsingError>? {
        guard let owesIdx = words.firstIndex(where: { $0 == "owes" || $0 == "owe" }) else { return nil }
        guard owesIdx > 0 else { return nil }
        
        let name = words[owesIdx - 1].capitalized
        
        // Skip "me" if present: "[name] owes me [amount]"
        var amountIdx = owesIdx + 1
        if amountIdx < words.count && words[amountIdx] == "me" {
            amountIdx += 1
        }
        
        guard amountIdx < words.count else { return nil }
        
        if let amount = parseAmount(words[amountIdx]) {
            let dto = TransactionDTO(
                party: name,
                amount: amount,
                direction: .lent,
                isItem: false
            )
            return .success(.add(dto))
        }
        return nil
    }
    
    private func parseIOwe(_ words: [String]) -> Result<ParsedAction, ParsingError>? {
        guard words.first == "i" else { return nil }
        guard let oweIdx = words.firstIndex(of: "owe"), oweIdx + 2 < words.count else { return nil }
        
        let name = words[oweIdx + 1].capitalized
        
        if let amount = parseAmount(words[oweIdx + 2]) {
            let dto = TransactionDTO(
                party: name,
                amount: amount,
                direction: .borrowed,
                isItem: false
            )
            return .success(.add(dto))
        }
        return nil
    }
    
    private func parseLent(_ words: [String]) -> Result<ParsedAction, ParsingError>? {
        guard let lentIdx = words.firstIndex(of: "lent"), lentIdx + 1 < words.count else { return nil }
        
        guard let amount = parseAmount(words[lentIdx + 1]) else { return nil }
        
        if let toIdx = words.firstIndex(of: "to"), toIdx + 1 < words.count {
            let name = words[toIdx + 1].capitalized
            let dto = TransactionDTO(
                party: name,
                amount: amount,
                direction: .lent,
                isItem: false
            )
            return .success(.add(dto))
        }
        return nil
    }
    
    private func parseBorrowed(_ words: [String]) -> Result<ParsedAction, ParsingError>? {
        guard let borrowedIdx = words.firstIndex(of: "borrowed"), borrowedIdx + 1 < words.count else { return nil }
        
        guard let amount = parseAmount(words[borrowedIdx + 1]) else { return nil }
        
        if let fromIdx = words.firstIndex(of: "from"), fromIdx + 1 < words.count {
            let name = words[fromIdx + 1].capitalized
            let dto = TransactionDTO(
                party: name,
                amount: amount,
                direction: .borrowed,
                isItem: false
            )
            return .success(.add(dto))
        }
        return nil
    }
    
    private func parsePaid(_ words: [String]) -> Result<ParsedAction, ParsingError>? {
        guard let paidIdx = words.firstIndex(of: "paid") else { return nil }
        
        // "[name] paid [amount]" - settlement
        if paidIdx > 0 {
            let name = words[paidIdx - 1].capitalized
            if paidIdx + 1 < words.count, let amount = parseAmount(words[paidIdx + 1]) {
                let dto = TransactionDTO(
                    party: name,
                    amount: amount,
                    direction: .lent,
                    isItem: false,
                    settled: true
                )
                return .success(.add(dto))
            }
            // Just "[name] paid" - settle all
            return .success(.settle(name))
        }
        
        // "paid [name]" - settle all with that person
        if paidIdx + 1 < words.count {
            let name = words[paidIdx + 1].capitalized
            return .success(.settle(name))
        }
        
        return nil
    }
    
    // MARK: - Amount Parsing
    
    private func parseAmount(_ token: String) -> Decimal? {
        let cleaned = token.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
        return Decimal(string: cleaned)
    }
}
