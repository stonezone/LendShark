import Foundation

/// Immutable Data Transfer Object for Transaction data
/// Provides a contract between modules following the Stable Contracts principle
public struct TransactionDTO: Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let party: String
    public let amount: Decimal?
    public let item: String?
    public let direction: TransactionDirection
    public let isItem: Bool
    public let settled: Bool
    public let timestamp: Date
    public let dueDate: Date?
    public let notes: String?
    public let cloudKitRecordID: String?
    
    public enum TransactionDirection: Int, Codable, Sendable {
        case borrowed = -1
        case lent = 1
    }
    
    public init(
        id: UUID = UUID(),
        party: String,
        amount: Decimal? = nil,
        item: String? = nil,
        direction: TransactionDirection,
        isItem: Bool = false,
        settled: Bool = false,
        timestamp: Date = Date(),
        dueDate: Date? = nil,
        notes: String? = nil,
        cloudKitRecordID: String? = nil
    ) {
        self.id = id
        self.party = party
        self.amount = amount
        self.item = item
        self.direction = direction
        self.isItem = isItem
        self.settled = settled
        self.timestamp = timestamp
        self.dueDate = dueDate
        self.notes = notes
        self.cloudKitRecordID = cloudKitRecordID
    }
    
    /// Semantic versioning for DTO changes
    public static let version = "1.0.0"
}

/// Data Transfer Object for balance summary calculations
/// Encapsulates balance state without exposing Core Data entities
public struct BalanceSummaryDTO: Codable, Equatable, Sendable {
    public let owedToMe: Decimal
    public let iOwe: Decimal
    public let netBalance: Decimal
    
    public init(owedToMe: Decimal, iOwe: Decimal, netBalance: Decimal) {
        self.owedToMe = owedToMe
        self.iOwe = iOwe
        self.netBalance = netBalance
    }
}

/// Balance calculation result DTO
public struct BalanceDTO: Equatable, Sendable {
    public let owedToMe: Decimal
    public let iOwe: Decimal
    public let netBalance: Decimal
    
    public init(owedToMe: Decimal, iOwe: Decimal) {
        self.owedToMe = owedToMe
        self.iOwe = iOwe
        self.netBalance = owedToMe - iOwe
    }
}

/// Export format options
public enum ExportFormat: String, CaseIterable, Sendable {
    case csv = "CSV"
    case pdf = "PDF"
    case json = "JSON"
}

/// Export result DTO
public struct ExportResultDTO: Sendable {
    public let format: ExportFormat
    public let fileURL: URL
    public let transactionCount: Int
    public let exportDate: Date
    
    public init(format: ExportFormat, fileURL: URL, transactionCount: Int, exportDate: Date = Date()) {
        self.format = format
        self.fileURL = fileURL
        self.transactionCount = transactionCount
        self.exportDate = exportDate
    }
}
