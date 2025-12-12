import Foundation
import CoreData
import os

/// Core Data stack (CloudKit removed/disabled)
private let logger = AppLogger.persistence

public final class PersistenceController: Sendable {
    // Load the Core Data model from Bundle.module
    nonisolated(unsafe) private static let managedObjectModel: NSManagedObjectModel = {
        let bundles = [Bundle.module, Bundle(for: PersistenceController.self), Bundle.main]

        // Prefer compiled models when present (Xcode builds).
        for bundle in bundles {
            if let modelURL = bundle.url(forResource: "LendShark", withExtension: "momd"),
               let model = NSManagedObjectModel(contentsOf: modelURL),
               !model.entities.isEmpty {
                logger.info("Loaded Core Data model (momd) from \(bundle.bundleIdentifier ?? "unknown bundle")")
                return model
            }

            if let modelURL = bundle.url(forResource: "LendShark", withExtension: "mom"),
               let model = NSManagedObjectModel(contentsOf: modelURL),
               !model.entities.isEmpty {
                logger.info("Loaded Core Data model (mom) from \(bundle.bundleIdentifier ?? "unknown bundle")")
                return model
            }
        }

        // Fall back to merged model if a compiled model exists under a different name.
        if let merged = NSManagedObjectModel.mergedModel(from: bundles), !merged.entities.isEmpty {
            logger.info("Loaded merged Core Data model from available bundles")
            return merged
        }

        logger.critical("Failed to find a compiled Core Data model - falling back to programmatic model")
        let model = NSManagedObjectModel()
        
        // Create Transaction entity programmatically as fallback
        let transactionEntity = NSEntityDescription()
        transactionEntity.name = "Transaction"
        transactionEntity.managedObjectClassName = "Transaction"
        
        // Add attributes (must match Core/Infrastructure/LendShark.xcdatamodeld schema)
        let idAttribute = NSAttributeDescription()
        idAttribute.name = "id"
        idAttribute.attributeType = .UUIDAttributeType
        idAttribute.isOptional = true
        
        let partyAttribute = NSAttributeDescription()
        partyAttribute.name = "party"
        partyAttribute.attributeType = .stringAttributeType
        partyAttribute.isOptional = false
        partyAttribute.defaultValue = "Unknown"
        
        let amountAttribute = NSAttributeDescription()
        amountAttribute.name = "amount"
        amountAttribute.attributeType = .decimalAttributeType
        amountAttribute.isOptional = true
        amountAttribute.defaultValue = NSDecimalNumber(string: "0.0")
        
        let timestampAttribute = NSAttributeDescription()
        timestampAttribute.name = "timestamp"
        timestampAttribute.attributeType = .dateAttributeType
        timestampAttribute.isOptional = true
        
        let directionAttribute = NSAttributeDescription()
        directionAttribute.name = "direction"
        directionAttribute.attributeType = .integer16AttributeType
        directionAttribute.isOptional = false
        directionAttribute.defaultValue = Int16(1)
        
        let settledAttribute = NSAttributeDescription()
        settledAttribute.name = "settled"
        settledAttribute.attributeType = .booleanAttributeType
        settledAttribute.isOptional = false
        settledAttribute.defaultValue = false
        
        let isItemAttribute = NSAttributeDescription()
        isItemAttribute.name = "isItem"
        isItemAttribute.attributeType = .booleanAttributeType
        isItemAttribute.isOptional = false
        isItemAttribute.defaultValue = false
        
        let itemAttribute = NSAttributeDescription()
        itemAttribute.name = "item"
        itemAttribute.attributeType = .stringAttributeType
        itemAttribute.isOptional = true
        
        let dueDateAttribute = NSAttributeDescription()
        dueDateAttribute.name = "dueDate"
        dueDateAttribute.attributeType = .dateAttributeType
        dueDateAttribute.isOptional = true

        let interestRateAttribute = NSAttributeDescription()
        interestRateAttribute.name = "interestRate"
        interestRateAttribute.attributeType = .decimalAttributeType
        interestRateAttribute.isOptional = true
        interestRateAttribute.defaultValue = NSDecimalNumber(string: "0.0")
        
        let notesAttribute = NSAttributeDescription()
        notesAttribute.name = "notes"
        notesAttribute.attributeType = .stringAttributeType
        notesAttribute.isOptional = true

        let phoneNumberAttribute = NSAttributeDescription()
        phoneNumberAttribute.name = "phoneNumber"
        phoneNumberAttribute.attributeType = .stringAttributeType
        phoneNumberAttribute.isOptional = true
        
        let cloudKitRecordIDAttribute = NSAttributeDescription()
        cloudKitRecordIDAttribute.name = "cloudKitRecordID"
        cloudKitRecordIDAttribute.attributeType = .stringAttributeType
        cloudKitRecordIDAttribute.isOptional = true
        
        transactionEntity.properties = [
            idAttribute, partyAttribute, amountAttribute, timestampAttribute,
            directionAttribute, settledAttribute, isItemAttribute, itemAttribute,
            dueDateAttribute, interestRateAttribute, notesAttribute, phoneNumberAttribute, cloudKitRecordIDAttribute
        ]
        model.entities = [transactionEntity]
        
        return model
    }()

    // Preview instance for SwiftUI previews - in-memory store
    @MainActor
    public static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
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

    public let container: NSPersistentContainer
    private let _isDataStoreReady = OSAllocatedUnfairLock(initialState: false)
    private let _canSaveData = OSAllocatedUnfairLock(initialState: false)

    public var isDataStoreReady: Bool { _isDataStoreReady.withLock { $0 } }
    public var canSaveData: Bool { _canSaveData.withLock { $0 } }

    public init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "LendShark", managedObjectModel: Self.managedObjectModel)

        if inMemory {
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [description]
        }

        container.loadPersistentStores { [weak self] _, error in
            if let error = error {
                logger.error("Core Data failed to load", error: error)
                self?._isDataStoreReady.withLock { $0 = false }
                self?._canSaveData.withLock { $0 = false }
            } else {
                logger.info("Core Data loaded successfully")
                self?._isDataStoreReady.withLock { $0 = true }
                self?._canSaveData.withLock { $0 = true }
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        // Use Swift-friendly merge policy constant to avoid symbol resolution issues.
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    }

    // MARK: - DTO Conversion (Pure Functions)

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
            interestRate: transaction.interestRate as? Decimal,
            notes: transaction.notes,
            phoneNumber: transaction.phoneNumber,
            cloudKitRecordID: transaction.cloudKitRecordID
        )
    }

    public func dtoToTransaction(_ dto: TransactionDTO, context: NSManagedObjectContext) -> Transaction {
        let transaction = Transaction(context: context)
        transaction.id = dto.id
        transaction.party = dto.party
        transaction.amount = dto.amount.map { NSDecimalNumber(decimal: $0) }
        transaction.item = dto.item
        transaction.direction = Int16(dto.direction.rawValue)
        transaction.isItem = dto.isItem
        transaction.settled = dto.settled
        transaction.timestamp = dto.timestamp
        transaction.dueDate = dto.dueDate
        transaction.interestRate = dto.interestRate.map { NSDecimalNumber(decimal: $0) }
        transaction.notes = dto.notes
        transaction.phoneNumber = dto.phoneNumber
        transaction.cloudKitRecordID = dto.cloudKitRecordID
        return transaction
    }

    // MARK: - Batch Operations

    @MainActor
    public func saveContext() {
        let context = container.viewContext
        guard canSaveData else {
            logger.warning("Cannot save: Data store not ready")
            return
        }
        if context.hasChanges {
            do {
                try context.save()
                logger.debug("Context saved successfully")
            } catch {
                logger.error("Failed to save context", error: error)
                if let saveError = error as NSError? {
                    logger.error("Save error details: \(saveError.userInfo)")
                }
            }
        }
    }
}
