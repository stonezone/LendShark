import Foundation

/// Protocol defining transaction data operations
/// Following Dependency Injection principle - pass collaborators, don't hard-wire imports
public protocol TransactionServiceProtocol: Sendable {
    func addTransaction(_ dto: TransactionDTO) async throws -> TransactionDTO
    func updateTransaction(_ dto: TransactionDTO) async throws -> TransactionDTO
    func deleteTransaction(id: UUID) async throws
    func getTransaction(id: UUID) async throws -> TransactionDTO?
    func getAllTransactions() async throws -> [TransactionDTO]
    func getTransactions(for party: String) async throws -> [TransactionDTO]
    func settleTransactions(for party: String) async throws -> Int
}

/// Protocol for export operations
public protocol ExportServiceProtocol: Sendable {
    func exportTransactions(_ transactions: [TransactionDTO], format: ExportFormat) async throws -> ExportResultDTO
    func getSupportedFormats() -> [ExportFormat]
}

/// Protocol for sync operations
public protocol SyncServiceProtocol: Sendable {
    func syncTransactions() async throws
    func getLastSyncDate() -> Date?
    func isSyncEnabled() -> Bool
    func enableSync() async throws
    func disableSync() async throws
}

/// Protocol for validation operations
public protocol ValidationServiceProtocol: Sendable {
    func validateTransaction(_ dto: TransactionDTO) -> Result<TransactionDTO, ValidationError>
    func sanitizeInput(_ input: String, for field: InputField) -> String
}

/// Protocol for parsing operations
public protocol ParserServiceProtocol: Sendable {
    func parse(_ input: String) -> Result<ParsedAction, ParsingError>
}

/// Validation error types
public enum ValidationError: Error, LocalizedError {
    case invalidPartyName(String)
    case invalidAmount(String)
    case invalidItem(String)
    case excessiveLength(field: String, maxLength: Int)
    case injectionAttempt(String)
    case cloudKitIncompatible(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidPartyName(let reason):
            return "Invalid party name: \(reason)"
        case .invalidAmount(let reason):
            return "Invalid amount: \(reason)"
        case .invalidItem(let reason):
            return "Invalid item: \(reason)"
        case .excessiveLength(let field, let maxLength):
            return "\(field) exceeds maximum length of \(maxLength)"
        case .injectionAttempt(let details):
            return "Security: Potential injection attempt detected: \(details)"
        case .cloudKitIncompatible(let reason):
            return "CloudKit compatibility issue: \(reason)"
        }
    }
}

/// Parsing error types
public enum ParsingError: Error, LocalizedError {
    case invalidFormat(String)
    case missingRequiredField(String)
    case ambiguousInput(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidFormat(let details):
            return "Invalid format: \(details)"
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        case .ambiguousInput(let details):
            return "Ambiguous input: \(details)"
        }
    }
}

/// Input field types for validation
public enum InputField {
    case partyName
    case itemDescription
    case notes
    case amount
}

/// Parsed action types
public enum ParsedAction {
    case add(TransactionDTO)
    case settle(party: String)
}
