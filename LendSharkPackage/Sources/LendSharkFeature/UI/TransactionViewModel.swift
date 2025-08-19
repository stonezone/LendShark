import Foundation
import CoreData
import SwiftUI

/// View Model coordinating UI and business logic
/// Following MVVM pattern with proper separation
@MainActor
public final class TransactionViewModel: ObservableObject {
    @Published var parsePreview: String?
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var isExporting = false
    
    private var transactionService: TransactionServiceProtocol?
    private var parserService: ParserServiceProtocol?
    private var exportService: ExportServiceProtocol?
    private var syncService: SyncServiceProtocol?
    
    public init() {}
    
    // MARK: - Initialization
    
    public func initializeServices() async {
        do {
            let container = DependencyContainer.shared
            container.setupDependencies(persistenceController: PersistenceController.shared)
            
            transactionService = try container.resolveTransactionService()
            parserService = try container.resolveParserService()
            exportService = try container.resolveExportService()
            syncService = try container.resolveSyncService()
            
            // Enable sync if available
            if let syncService = syncService {
                try? await syncService.enableSync()
            }
        } catch {
            showError(message: "Failed to initialize services: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Transaction Operations
    
    public func parseAndAddTransaction(_ input: String, context: NSManagedObjectContext) async -> Bool {
        guard let parserService = parserService,
              let transactionService = transactionService else {
            showError(message: "Services not initialized")
            return false
        }
        
        // Clear previous error
        clearError()
        
        // Parse input
        let result = parserService.parse(input)
        
        switch result {
        case .success(let action):
            switch action {
            case .add(let dto):
                // Add transaction
                do {
                    _ = try await transactionService.addTransaction(dto)
                    parsePreview = nil
                    
                    // Trigger sync if enabled
                    if let syncService = syncService, syncService.isSyncEnabled() {
                        try? await syncService.syncTransactions()
                    }
                    return true
                } catch {
                    showError(message: error.localizedDescription)
                    return false
                }
                
            case .settle(let party):
                do {
                    let count = try await transactionService.settleTransactions(for: party)
                    if count == 0 {
                        showError(message: "No unsettled transactions found for \(party)")
                        return false
                    } else {
                        parsePreview = "Successfully settled \(count) transaction(s) with \(party)"
                        // Clear after a delay to show the success message
                        Task {
                            try? await Task.sleep(nanoseconds: 2_000_000_000)
                            parsePreview = nil
                        }
                        return true
                    }
                } catch {
                    showError(message: error.localizedDescription)
                    return false
                }
            }
            
        case .failure(let error):
            showError(message: error.localizedDescription)
            parsePreview = nil
            return false
        }
    }
    
    // MARK: - Export Operations
    
    public func exportTransactions(_ transactions: [TransactionDTO], format: ExportFormat) async {
        guard let exportService = exportService else {
            showError(message: "Export service not initialized")
            return
        }
        
        isExporting = true
        
        do {
            let result = try await exportService.exportTransactions(transactions, format: format)
            
            // Share the exported file
            await MainActor.run {
                shareFile(url: result.fileURL)
            }
        } catch {
            showError(message: "Export failed: \(error.localizedDescription)")
        }
        
        isExporting = false
    }
    
    // MARK: - Balance Calculations
    
    public func calculateOwedToMe(from transactions: FetchedResults<Transaction>) -> Decimal {
        transactions
            .filter { $0.direction > 0 && !$0.settled }
            .compactMap { $0.amount as? Decimal }
            .reduce(0, +)
    }
    
    public func calculateIOwe(from transactions: FetchedResults<Transaction>) -> Decimal {
        transactions
            .filter { $0.direction < 0 && !$0.settled }
            .compactMap { $0.amount as? Decimal }
            .reduce(0, +)
    }
    
    // MARK: - DTO Conversion
    
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
    
    // MARK: - Helper Methods
    
    private func formatPreview(_ dto: TransactionDTO) -> String {
        let action = dto.direction == .lent ? "Lend" : "Borrow"
        let amountOrItem = dto.isItem ? 
            (dto.item ?? "item") : 
            "$\(NSDecimalNumber(decimal: dto.amount ?? 0).doubleValue)"
        let preposition = dto.direction == .lent ? "to" : "from"
        
        return "\(action) \(amountOrItem) \(preposition) \(dto.party)"
    }
    
    public func updateParsePreview(_ input: String) async {
        guard !input.isEmpty else {
            parsePreview = nil
            return
        }
        
        guard let parserService = parserService else {
            parsePreview = nil
            return
        }
        
        let result = parserService.parse(input)
        
        switch result {
        case .success(let action):
            switch action {
            case .add(let dto):
                parsePreview = formatPreview(dto)
            case .settle(let party):
                parsePreview = "Will settle all transactions with \(party)"
            }
        case .failure:
            parsePreview = nil
        }
    }
    
    public func showError(message: String) {
        errorMessage = message
        showError = true
    }
    
    public func clearError() {
        errorMessage = nil
        showError = false
    }
    
    private func shareFile(url: URL) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            return
        }
        
        let activityViewController = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = window
            popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        rootViewController.present(activityViewController, animated: true)
    }
}
