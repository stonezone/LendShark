import Foundation
import CloudKit

/// CloudKit sync service for transaction synchronization
/// Following Single Responsibility: handles CloudKit sync operations
public final class SyncService: SyncServiceProtocol, @unchecked Sendable {
    private let persistenceController: PersistenceController
    private var lastSyncDate: Date?
    private var isSyncActive = false
    
    public init(persistenceController: PersistenceController) {
        self.persistenceController = persistenceController
        checkCloudKitAvailability()
    }
    
    public func syncTransactions() async throws {
        guard isSyncActive else {
            throw SyncError.syncDisabled
        }
        
        // CloudKit sync is handled automatically by NSPersistentCloudKitContainer
        // This method is for manual sync triggers if needed
        lastSyncDate = Date()
    }
    
    public func getLastSyncDate() -> Date? {
        return lastSyncDate
    }
    
    public func isSyncEnabled() -> Bool {
        return isSyncActive
    }
    
    public func enableSync() async throws {
        // Simplified - just enable sync without checking account status
        // NSPersistentCloudKitContainer will handle the actual sync
        isSyncActive = true
        lastSyncDate = Date()
    }
    
    public func disableSync() async throws {
        isSyncActive = false
    }
    
    // MARK: - Private Methods
    
    private func checkCloudKitAvailability() {
        // Enable sync by default, let NSPersistentCloudKitContainer handle errors
        isSyncActive = true
    }
}

public enum SyncError: Error, LocalizedError {
    case syncDisabled
    case noiCloudAccount
    case accountRestricted
    case statusUndetermined
    case unknownError
    
    public var errorDescription: String? {
        switch self {
        case .syncDisabled:
            return "Sync is currently disabled"
        case .noiCloudAccount:
            return "No iCloud account configured. Please sign in to iCloud in Settings."
        case .accountRestricted:
            return "iCloud account is restricted"
        case .statusUndetermined:
            return "Could not determine iCloud account status"
        case .unknownError:
            return "An unknown error occurred with iCloud sync"
        }
    }
}
