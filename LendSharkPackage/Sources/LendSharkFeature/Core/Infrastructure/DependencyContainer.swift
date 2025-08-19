import Foundation

/// Dependency Injection Container following Dependency Injection principle
/// Single point of dependency resolution avoiding hard-wired imports
@MainActor
public final class DependencyContainer: @unchecked Sendable {
    public static let shared = DependencyContainer()
    
    // Service registrations
    private var transactionService: TransactionServiceProtocol?
    private var exportService: ExportServiceProtocol?
    private var syncService: SyncServiceProtocol?
    private var validationService: ValidationServiceProtocol?
    private var parserService: ParserServiceProtocol?
    
    private init() {}
    
    // MARK: - Registration
    
    public func register(transactionService: TransactionServiceProtocol) {
        self.transactionService = transactionService
    }
    
    public func register(exportService: ExportServiceProtocol) {
        self.exportService = exportService
    }
    
    public func register(syncService: SyncServiceProtocol) {
        self.syncService = syncService
    }
    
    public func register(validationService: ValidationServiceProtocol) {
        self.validationService = validationService
    }
    
    public func register(parserService: ParserServiceProtocol) {
        self.parserService = parserService
    }
    
    // MARK: - Resolution
    
    public func resolveTransactionService() throws -> TransactionServiceProtocol {
        guard let service = transactionService else {
            throw DependencyError.serviceNotRegistered("TransactionService")
        }
        return service
    }
    
    public func resolveExportService() throws -> ExportServiceProtocol {
        guard let service = exportService else {
            throw DependencyError.serviceNotRegistered("ExportService")
        }
        return service
    }
    
    public func resolveSyncService() throws -> SyncServiceProtocol {
        guard let service = syncService else {
            throw DependencyError.serviceNotRegistered("SyncService")
        }
        return service
    }
    
    public func resolveValidationService() throws -> ValidationServiceProtocol {
        guard let service = validationService else {
            throw DependencyError.serviceNotRegistered("ValidationService")
        }
        return service
    }
    
    public func resolveParserService() throws -> ParserServiceProtocol {
        guard let service = parserService else {
            throw DependencyError.serviceNotRegistered("ParserService")
        }
        return service
    }
    
    // MARK: - Setup
    
    public func setupDependencies(persistenceController: PersistenceController) {
        // Initialize all services with their dependencies
        let validationService = ValidationService()
        let parserService = ParserService(validationService: validationService)
        let transactionService = TransactionService(
            persistenceController: persistenceController,
            validationService: validationService
        )
        let exportService = ExportService()
        let syncService = SyncService(persistenceController: persistenceController)
        
        // Register services
        register(validationService: validationService)
        register(parserService: parserService)
        register(transactionService: transactionService)
        register(exportService: exportService)
        register(syncService: syncService)
    }
}

public enum DependencyError: Error, LocalizedError {
    case serviceNotRegistered(String)
    
    public var errorDescription: String? {
        switch self {
        case .serviceNotRegistered(let service):
            return "\(service) not registered in DependencyContainer"
        }
    }
}
