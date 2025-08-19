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
    @NSManaged public var notes: String?
    @NSManaged public var cloudKitRecordID: String?
}

extension Transaction {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Transaction> {
        return NSFetchRequest<Transaction>(entityName: "Transaction")
    }
}
