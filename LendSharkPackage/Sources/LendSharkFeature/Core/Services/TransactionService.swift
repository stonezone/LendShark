import Foundation
import CoreData

/// Simplified Transaction Service - handles all transaction operations
/// Following Single Responsibility: manages transaction business logic
public final class TransactionService: TransactionServiceProtocol, @unchecked Sendable {
    private let persistenceController: PersistenceController
    private let validationService: ValidationServiceProtocol
    
    public init(persistenceController: PersistenceController, validationService: ValidationServiceProtocol) {
        self.persistenceController = persistenceController
        self.validationService = validationService
    }
    
    public func addTransaction(_ dto: TransactionDTO) async throws -> TransactionDTO {
        let validatedDTO = try validationService.validateTransaction(dto).get()
        
        let context = persistenceController.container.viewContext
        let transaction = persistenceController.dtoToTransaction(validatedDTO, context: context)
        
        try context.save()
        return persistenceController.transactionToDTO(transaction)
    }
    
    public func updateTransaction(_ dto: TransactionDTO) async throws -> TransactionDTO {
        let validatedDTO = try validationService.validateTransaction(dto).get()
        
        let context = persistenceController.container.viewContext
        let request = Transaction.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", validatedDTO.id as CVarArg)
        
        guard let transaction = try context.fetch(request).first else {
            throw TransactionError.notFound
        }
        
        // Update fields
        transaction.party = validatedDTO.party
        transaction.amount = validatedDTO.amount as? NSDecimalNumber
        transaction.item = validatedDTO.item
        transaction.direction = Int16(validatedDTO.direction.rawValue)
        transaction.isItem = validatedDTO.isItem
        transaction.settled = validatedDTO.settled
        transaction.dueDate = validatedDTO.dueDate
        transaction.notes = validatedDTO.notes
        
        try context.save()
        return persistenceController.transactionToDTO(transaction)
    }
    
    public func deleteTransaction(id: UUID) async throws {
        let context = persistenceController.container.viewContext
        let request = Transaction.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        guard let transaction = try context.fetch(request).first else {
            throw TransactionError.notFound
        }
        
        context.delete(transaction)
        try context.save()
    }
    
    public func getTransaction(id: UUID) async throws -> TransactionDTO? {
        let context = persistenceController.container.viewContext
        let request = Transaction.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        guard let transaction = try context.fetch(request).first else {
            return nil
        }
        
        return persistenceController.transactionToDTO(transaction)
    }
    
    public func getAllTransactions() async throws -> [TransactionDTO] {
        let context = persistenceController.container.viewContext
        let request = Transaction.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        let transactions = try context.fetch(request)
        return transactions.map { persistenceController.transactionToDTO($0) }
    }
    
    public func getTransactions(for party: String) async throws -> [TransactionDTO] {
        let context = persistenceController.container.viewContext
        let request = Transaction.fetchRequest()
        request.predicate = NSPredicate(format: "party ==[c] %@", party)
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        let transactions = try context.fetch(request)
        return transactions.map { persistenceController.transactionToDTO($0) }
    }
    
    public func settleTransactions(for party: String) async throws -> Int {
        let context = persistenceController.container.viewContext
        let request = Transaction.fetchRequest()
        request.predicate = NSPredicate(format: "party ==[c] %@ AND settled == NO", party)
        
        let transactions = try context.fetch(request)
        for transaction in transactions {
            transaction.settled = true
        }
        
        if !transactions.isEmpty {
            try context.save()
        }
        
        return transactions.count
    }
}

public enum TransactionError: Error, LocalizedError {
    case notFound
    case saveFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .notFound:
            return "Transaction not found"
        case .saveFailed(let reason):
            return "Failed to save transaction: \(reason)"
        }
    }
}
