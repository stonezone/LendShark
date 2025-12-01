import Foundation
import CoreData

/// Core people tracking - no entity needed, calculates from transactions
struct DebtLedger {
    
    /// Just THREE things we track about each debtor
    struct DebtorInfo {
        let name: String
        let totalOwed: Decimal
        let daysOverdue: Int
        
        var isOverdue: Bool {
            daysOverdue > 0
        }
        
        var owesMe: Bool {
            totalOwed > 0
        }
        
        var iOwe: Bool {
            totalOwed < 0
        }
    }
    
    /// Calculate debtors from transactions - no storage needed
    static func getDebtors(from transactions: [Transaction]) -> [DebtorInfo] {
        var debtorMap: [String: (amount: Decimal, oldestDate: Date?)] = [:]
        
        // GROUP BY person and SUM unsettled amounts
        for transaction in transactions {
            guard !transaction.settled else { continue }
            guard let party = transaction.party, !party.isEmpty else { continue }
            
            let person = party
            let amount = transaction.amount as? Decimal ?? 0
            let direction = TransactionDirection(rawValue: transaction.direction) ?? .owedToMe
            
            // Calculate the actual debt amount
            let debtAmount = direction == .owedToMe ? amount : -amount
            
            if var existing = debtorMap[person] {
                existing.amount += debtAmount
                // Keep track of oldest transaction for overdue calculation
                if let transactionDate = transaction.timestamp,
                   let existingOldest = existing.oldestDate {
                    existing.oldestDate = min(existingOldest, transactionDate)
                } else if existing.oldestDate == nil {
                    existing.oldestDate = transaction.timestamp
                }
                debtorMap[person] = existing
            } else {
                debtorMap[person] = (debtAmount, transaction.timestamp)
            }
        }
        
        // Convert to DebtorInfo and calculate overdue days
        let now = Date()
        let debtors = debtorMap.compactMap { (person, data) -> DebtorInfo? in
            // Only include if they owe something or we owe them
            guard data.amount != 0 else { return nil }
            
            let daysOverdue: Int
            if let oldestDate = data.oldestDate, data.amount > 0 {
                // Only positive amounts (money owed to me) can be overdue
                let daysSince = Calendar.current.dateComponents([.day], from: oldestDate, to: now).day ?? 0
                daysOverdue = max(0, daysSince - 7) // Grace period of 7 days
            } else {
                daysOverdue = 0
            }
            
            return DebtorInfo(
                name: person,
                totalOwed: data.amount,
                daysOverdue: daysOverdue
            )
        }
        
        // SORT by amount owed (biggest debts first, then people I owe)
        return debtors.sorted { lhs, rhs in
            // Priority: 
            // 1. Overdue debts first
            // 2. Largest amounts owed to me
            // 3. People I owe (negative amounts)
            
            if lhs.isOverdue && !rhs.isOverdue {
                return true
            } else if !lhs.isOverdue && rhs.isOverdue {
                return false
            }
            
            // Both overdue or both not overdue - sort by amount descending
            return lhs.totalOwed > rhs.totalOwed
        }
    }
}

/// Transaction direction enum for clarity
enum TransactionDirection: Int16, CaseIterable {
    case owedToMe = 1
    case iOwe = -1
    
    var description: String {
        switch self {
        case .owedToMe:
            return "Owed to Me"
        case .iOwe:
            return "I Owe"
        }
    }
}
