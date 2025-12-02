import Foundation
import CoreData

/// Core people tracking - no entity needed, calculates from transactions
struct DebtLedger {
    
    /// What we track about each debtor
    struct DebtorInfo {
        let name: String
        let principal: Decimal      // Original amount
        let accruedInterest: Decimal // Interest accumulated
        let daysOverdue: Int
        let notes: String?          // Collateral or notes
        
        var totalOwed: Decimal {
            principal + accruedInterest
        }
        
        var isOverdue: Bool {
            daysOverdue > 0
        }
        
        var owesMe: Bool {
            totalOwed > 0
        }
        
        var iOwe: Bool {
            totalOwed < 0
        }
        
        var hasInterest: Bool {
            accruedInterest > 0
        }
    }
    
    /// Calculate debtors from transactions - no storage needed
    static func getDebtors(from transactions: [Transaction]) -> [DebtorInfo] {
        struct DebtData {
            var principal: Decimal = 0
            var interest: Decimal = 0
            var dueDate: Date?
            var oldestDate: Date?
            var notes: String?
        }
        
        var debtorMap: [String: DebtData] = [:]
        let now = Date()
        
        // GROUP BY person and SUM unsettled amounts + calculate interest
        for transaction in transactions {
            guard !transaction.settled else { continue }
            guard let party = transaction.party, !party.isEmpty else { continue }
            
            let amount = transaction.amount as? Decimal ?? 0
            // Use DTO-level direction to avoid drift between enums
            let direction = TransactionDTO.TransactionDirection(rawValue: Int(transaction.direction)) ?? .lent
            let debtAmount = direction == .lent ? amount : -amount
            
            // Calculate interest if rate is set
            var interestAmount: Decimal = 0
            if let rate = transaction.interestRate as? Decimal,
               let timestamp = transaction.timestamp,
               debtAmount > 0 {
                let weeks = Decimal(Calendar.current.dateComponents([.day], from: timestamp, to: now).day ?? 0) / 7
                interestAmount = debtAmount * rate * weeks
            }
            
            if var existing = debtorMap[party] {
                existing.principal += debtAmount
                existing.interest += interestAmount
                
                // Track oldest date and earliest due date
                if let transDate = transaction.timestamp {
                    existing.oldestDate = existing.oldestDate.map { min($0, transDate) } ?? transDate
                }
                if let due = transaction.dueDate {
                    existing.dueDate = existing.dueDate.map { min($0, due) } ?? due
                }
                // Combine notes
                if let note = transaction.notes, !note.isEmpty {
                    existing.notes = existing.notes.map { $0 + "; " + note } ?? note
                }
                debtorMap[party] = existing
            } else {
                debtorMap[party] = DebtData(
                    principal: debtAmount,
                    interest: interestAmount,
                    dueDate: transaction.dueDate,
                    oldestDate: transaction.timestamp,
                    notes: transaction.notes
                )
            }
        }
        
        // Convert to DebtorInfo
        let debtors = debtorMap.compactMap { (person, data) -> DebtorInfo? in
            guard data.principal != 0 else { return nil }
            
            let daysOverdue: Int
            if data.principal > 0 {
                if let dueDate = data.dueDate {
                    // Use explicit due date
                    let days = Calendar.current.dateComponents([.day], from: dueDate, to: now).day ?? 0
                    daysOverdue = max(0, days)
                } else if let oldestDate = data.oldestDate {
                    // Fall back to 7-day grace from creation
                    let daysSince = Calendar.current.dateComponents([.day], from: oldestDate, to: now).day ?? 0
                    daysOverdue = max(0, daysSince - 7)
                } else {
                    daysOverdue = 0
                }
            } else {
                daysOverdue = 0
            }
            
            return DebtorInfo(
                name: person,
                principal: data.principal,
                accruedInterest: data.interest,
                daysOverdue: daysOverdue,
                notes: data.notes
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
