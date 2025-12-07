import Foundation
import CoreData

/// Core people tracking - no entity needed, calculates from transactions
struct DebtLedger {

    /// A borrowed physical item (not money)
    struct BorrowedItem {
        let name: String           // Item name (e.g., "impact wrench")
        let dueDate: Date
        let theyHaveMine: Bool     // true = they borrowed from me, false = I borrowed from them

        var daysOverdue: Int {
            let days = Calendar.current.dateComponents([.day], from: dueDate, to: Date()).day ?? 0
            return max(0, days)
        }

        var isOverdue: Bool {
            daysOverdue > 0
        }

        var daysUntilDue: Int {
            let days = Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
            return max(0, days)
        }
    }

    /// What we track about each debtor
    struct DebtorInfo {
        let name: String
        let principal: Decimal      // Original amount
        let accruedInterest: Decimal // Interest accumulated
        let daysOverdue: Int
        let notes: String?          // Collateral or notes
        let items: [BorrowedItem]   // Physical items they have or I have

        var totalOwed: Decimal {
            principal + accruedInterest
        }

        var isOverdue: Bool {
            daysOverdue > 0 || items.contains { $0.isOverdue }
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

        var hasItems: Bool {
            !items.isEmpty
        }

        var overdueItems: [BorrowedItem] {
            items.filter { $0.isOverdue }
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
            var items: [BorrowedItem] = []
        }

        var debtorMap: [String: DebtData] = [:]
        let now = Date()
        
        // GROUP BY person and SUM unsettled amounts + calculate interest
        for transaction in transactions {
            guard !transaction.settled else { continue }
            guard let party = transaction.party, !party.isEmpty else { continue }

            let direction = TransactionDTO.TransactionDirection(rawValue: Int(transaction.direction)) ?? .lent

            // Handle borrowed ITEMS separately from money
            if transaction.isItem {
                let itemName = transaction.notes ?? "Item"
                let dueDate = transaction.dueDate ?? Calendar.current.date(byAdding: .day, value: 7, to: transaction.timestamp ?? Date()) ?? Date()
                let theyHaveMine = direction == .lent // .lent means they borrowed FROM me

                let item = BorrowedItem(name: itemName, dueDate: dueDate, theyHaveMine: theyHaveMine)

                if var existing = debtorMap[party] {
                    existing.items.append(item)
                    debtorMap[party] = existing
                } else {
                    debtorMap[party] = DebtData(items: [item])
                }
                continue
            }

            // Handle MONEY transactions
            let amount = transaction.amount as? Decimal ?? 0
            let debtAmount = direction == .lent ? amount : -amount

            // Calculate interest so far using centralised helper.
            // Only track vig for money that others owe me.
            let interestAmount: Decimal
            if debtAmount > 0 {
                interestAmount = InterestCalculator.interestSoFar(for: transaction, asOf: now)
            } else {
                interestAmount = 0
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
                // Combine notes (but not for items - those go in items array)
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
            // Include if they owe money OR have borrowed items
            guard data.principal != 0 || !data.items.isEmpty else { return nil }

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
                notes: data.notes,
                items: data.items
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
