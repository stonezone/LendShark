import Foundation
import CoreData

/// Core Data stack with CloudKit integration
/// Following Single Responsibility principle - one purpose: data persistence
import Foundation
import CoreData

/// Core Data stack with programmatic model definition
/// Following Single Responsibility principle - one purpose: data persistence
import Foundation
import CoreData

/// Core Data stack with CloudKit integration
/// Following Single Responsibility principle - one purpose: data persistence
public final class PersistenceController: @unchecked Sendable {
    public static let shared = PersistenceController()
    
    public static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Add sample data for previews
        for i in 1...5 {
            let transaction = Transaction(context: viewContext)
            transaction.id = UUID()
            transaction.party = "Sample Person \(i)"
            transaction.amount = NSDecimalNumber(value: i * 10)
            transaction.direction = i % 2 == 0 ? 1 : -1
            transaction.settled = false
            transaction.isItem = false
            transaction.timestamp = Date()
        }
        
        try? viewContext.save()
        return result
    }()
    
    public let container: NSPersistentCloudKitContainer
    private(set) public var isDataStoreReady = false
    private(set) public var canSaveData = false
    
    public init(inMemory: Bool = false) {
        // Load the model from the bundle
        guard let modelURL = Bundle.module.url(forResource: "LendShark", withExtension: "momd") ??
                             Bundle.module.url(forResource: "LendShark", withExtension: "xcdatamodeld") else {
            fatalError("Failed to find Core Data model in bundle")
        }
        
        guard let model = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Failed to load Core Data model from URL: \(modelURL)")
        }
        
        container = NSPersistentCloudKitContainer(name: "LendShark", managedObjectModel: model)
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Configure for CloudKit with proper version validation
            container.persistentStoreDescriptions.forEach { storeDescription in
                storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
                storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            }
        }
        
        container.loadPersistentStores { [weak self] storeDescription, error in
            if let error = error {
                print("Core Data failed to load: \(error.localizedDescription)")
                // Continue anyway - the app can work without persistence
                self?.isDataStoreReady = false
                self?.canSaveData = false
            } else {
                print("Core Data loaded successfully")
                self?.isDataStoreReady = true
                self?.canSaveData = true
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    // MARK: - DTO Conversion Methods (Pure Functions)
    
    public func transactionToDTO(_ transaction: Transaction) -> TransactionDTO {
        TransactionDTO(
            id: transaction.id ?? UUID(),
            party: transaction.party ?? "",
            amount: transaction.amount as? Decimal,
            item: transaction.item,
            direction: TransactionDTO.TransactionDirection(rawValue: Int(transaction.direction)) ?? .lent,
            isItem: transaction.isItem,
            settled: transaction.settled,
            timestamp: transaction.timestamp ?? Date(),
            dueDate: transaction.dueDate,
            notes: transaction.notes,
            cloudKitRecordID: transaction.cloudKitRecordID
        )
    }
    
    public func dtoToTransaction(_ dto: TransactionDTO, context: NSManagedObjectContext) -> Transaction {
        let transaction = Transaction(context: context)
        transaction.id = dto.id
        transaction.party = dto.party
        transaction.amount = dto.amount as? NSDecimalNumber
        transaction.item = dto.item
        transaction.direction = Int16(dto.direction.rawValue)
        transaction.isItem = dto.isItem
        transaction.settled = dto.settled
        transaction.timestamp = dto.timestamp
        transaction.dueDate = dto.dueDate
        transaction.notes = dto.notes
        transaction.cloudKitRecordID = dto.cloudKitRecordID
        return transaction
    }
    
    // MARK: - Batch Operations
    
    public func saveContext() {
        let context = container.viewContext
        
        guard canSaveData else {
            print("Cannot save: Data store not ready")
            return
        }
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Failed to save context: \(error)")
            }
        }
    }
}
