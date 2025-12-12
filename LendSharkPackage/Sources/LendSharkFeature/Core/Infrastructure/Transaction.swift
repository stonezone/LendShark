import Foundation
import CoreData

/// Simple Core Data entity for Transaction
/// No complex logic - just data storage
@objc(Transaction)
public class Transaction: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID?
    @NSManaged public var party: String?
    @NSManaged public var amount: NSDecimalNumber?
    @NSManaged public var item: String?
    @NSManaged public var direction: Int16
    @NSManaged public var isItem: Bool
    @NSManaged public var settled: Bool
    @NSManaged public var timestamp: Date?
    @NSManaged public var dueDate: Date?
    @NSManaged public var interestRate: NSDecimalNumber?
    @NSManaged public var notes: String?
    @NSManaged public var phoneNumber: String?
    @NSManaged public var cloudKitRecordID: String?
}

extension Transaction {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Transaction> {
        return NSFetchRequest<Transaction>(entityName: "Transaction")
    }
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        
        // Set default values
        if id == nil {
            id = UUID()
        }
        if timestamp == nil {
            timestamp = Date()
        }
    }
}

// MARK: - Settlement Actions (Loan Shark Style)
extension Transaction {
    
    /// Settle ALL unsettled transactions with a specific person
    /// Like marking the slate clean
    static func settleAll(with person: String, in context: NSManagedObjectContext) throws {
        let normalizedPerson = person.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedPerson.isEmpty else { return }

        let request: NSFetchRequest<Transaction> = Transaction.fetchRequest()
        request.predicate = NSPredicate(format: "party ==[c] %@ AND settled == false", normalizedPerson)
        
        let transactions = try context.fetch(request)
        for transaction in transactions {
            transaction.settled = true
        }
        
        try context.save()
        print("🏁 Settled \(transactions.count) transactions with \(person)")
    }
    
    /// Record a partial payment - creates a new settlement transaction
    /// Doesn't modify original debt, adds a counter-transaction
    static func recordPartialPayment(
        person: String, 
        amount: Decimal, 
        in context: NSManagedObjectContext
    ) throws {
        let settlement = Transaction(context: context)
        settlement.id = UUID()
        settlement.party = person
        settlement.amount = NSDecimalNumber(decimal: amount)
        settlement.direction = -1 // Payment TO me (reduces their debt)
        settlement.isItem = false
        settlement.settled = false // Must be false so DebtLedger includes it in calculations!
        settlement.timestamp = Date()
        settlement.notes = "Partial payment"
        
        try context.save()
        print("💰 Recorded $\(amount) payment from \(person)")
    }
    
    /// Mark all debts with person as defaulted (won't pay)
    /// Adds a note and effectively writes them off
    static func markAsDefaulted(person: String, in context: NSManagedObjectContext) throws {
        let normalizedPerson = person.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedPerson.isEmpty else { return }

        let request: NSFetchRequest<Transaction> = Transaction.fetchRequest()
        request.predicate = NSPredicate(format: "party ==[c] %@ AND settled == false AND direction == 1", normalizedPerson)
        
        let transactions = try context.fetch(request)
        for transaction in transactions {
            transaction.notes = (transaction.notes ?? "") + " [DEFAULTED - WON'T PAY]"
            transaction.settled = true // Remove from active ledger
        }
        
        try context.save()
        print("❌ Marked \(transactions.count) transactions with \(person) as defaulted")
    }
    
    /// Quick settlement of a single transaction
    func markSettled() throws {
        guard let context = self.managedObjectContext else {
            throw NSError(domain: "Transaction", code: 1, userInfo: [NSLocalizedDescriptionKey: "No context"])
        }
        
        self.settled = true
        try context.save()
    }
    
    /// Get total amount owed by a specific person (unsettled only)
    static func totalOwed(by person: String, in context: NSManagedObjectContext) -> Decimal {
        let normalizedPerson = person.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedPerson.isEmpty else { return 0 }

        let request: NSFetchRequest<Transaction> = Transaction.fetchRequest()
        request.predicate = NSPredicate(format: "party ==[c] %@ AND settled == false", normalizedPerson)
        
        do {
            let transactions = try context.fetch(request)
            return transactions.reduce(Decimal.zero) { total, transaction in
                let amount = transaction.amount?.decimalValue ?? 0
                let direction = transaction.direction == 1 ? 1 : -1
                return total + (amount * Decimal(direction))
            }
        } catch {
            print("Error calculating total owed: \(error)")
            return 0
        }
    }
}
