import Foundation
import UniformTypeIdentifiers

/// Export service for CSV, PDF, and JSON formats
/// Following Single Responsibility: handles all export operations
public final class ExportService: ExportServiceProtocol, Sendable {
    
    public init() {}
    
    public func exportTransactions(_ transactions: [TransactionDTO], format: ExportFormat) async throws -> ExportResultDTO {
        let fileURL: URL
        
        switch format {
        case .csv:
            fileURL = try await exportToCSV(transactions)
        case .pdf:
            fileURL = try await exportToPDF(transactions)
        case .json:
            fileURL = try await exportToJSON(transactions)
        }
        
        return ExportResultDTO(
            format: format,
            fileURL: fileURL,
            transactionCount: transactions.count
        )
    }
    
    public func getSupportedFormats() -> [ExportFormat] {
        return ExportFormat.allCases
    }
    
    // MARK: - Private Export Methods
    
    private func exportToCSV(_ transactions: [TransactionDTO]) async throws -> URL {
        var csvContent = "Date,Type,Party,Amount,Item,Settled,Notes\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        
        for transaction in transactions {
            let date = dateFormatter.string(from: transaction.timestamp)
            let type = transaction.direction == .lent ? "Lent" : "Borrowed"
            let party = escapeCSV(transaction.party)
            let amount = transaction.isItem ? "" : String(format: "%.2f", NSDecimalNumber(decimal: transaction.amount ?? 0).doubleValue)
            let item = escapeCSV(transaction.item ?? "")
            let settled = transaction.settled ? "Yes" : "No"
            let notes = escapeCSV(transaction.notes ?? "")
            
            csvContent += "\(date),\(type),\(party),\(amount),\(item),\(settled),\(notes)\n"
        }
        
        let fileName = "LendShark_Export_\(Date().timeIntervalSince1970).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        try csvContent.write(to: tempURL, atomically: true, encoding: .utf8)
        return tempURL
    }
    
    private func exportToJSON(_ transactions: [TransactionDTO]) async throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(transactions)
        
        let fileName = "LendShark_Export_\(Date().timeIntervalSince1970).json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        try data.write(to: tempURL)
        return tempURL
    }
    
    private func exportToPDF(_ transactions: [TransactionDTO]) async throws -> URL {
        // Simple HTML to PDF conversion
        var html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <title>LendShark Export</title>
            <style>
                body { font-family: -apple-system, sans-serif; margin: 20px; }
                h1 { color: #333; }
                table { width: 100%; border-collapse: collapse; margin-top: 20px; }
                th, td { padding: 8px; text-align: left; border-bottom: 1px solid #ddd; }
                th { background-color: #f2f2f2; font-weight: 600; }
                .lent { color: #22c55e; }
                .borrowed { color: #ef4444; }
                .settled { opacity: 0.6; }
                .summary { margin: 20px 0; padding: 15px; background-color: #f8f9fa; border-radius: 8px; }
            </style>
        </head>
        <body>
            <h1>LendShark Transaction Export</h1>
            <div class="summary">
                <p><strong>Export Date:</strong> \(DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .short))</p>
                <p><strong>Total Transactions:</strong> \(transactions.count)</p>
            </div>
            <table>
                <thead>
                    <tr>
                        <th>Date</th>
                        <th>Type</th>
                        <th>Party</th>
                        <th>Amount/Item</th>
                        <th>Status</th>
                        <th>Notes</th>
                    </tr>
                </thead>
                <tbody>
        """
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        
        for transaction in transactions {
            let date = dateFormatter.string(from: transaction.timestamp)
            let type = transaction.direction == .lent ? "Lent" : "Borrowed"
            let typeClass = transaction.direction == .lent ? "lent" : "borrowed"
            let party = escapeHTML(transaction.party)
            let amountOrItem = transaction.isItem ? 
                escapeHTML(transaction.item ?? "Item") : 
                "$\(String(format: "%.2f", NSDecimalNumber(decimal: transaction.amount ?? 0).doubleValue))"
            let status = transaction.settled ? "Settled" : "Open"
            let statusClass = transaction.settled ? "settled" : ""
            let notes = escapeHTML(transaction.notes ?? "")
            
            html += """
                <tr class="\(statusClass)">
                    <td>\(date)</td>
                    <td class="\(typeClass)">\(type)</td>
                    <td>\(party)</td>
                    <td>\(amountOrItem)</td>
                    <td>\(status)</td>
                    <td>\(notes)</td>
                </tr>
            """
        }
        
        html += """
                </tbody>
            </table>
        </body>
        </html>
        """
        
        let fileName = "LendShark_Export_\(Date().timeIntervalSince1970).html"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        try html.write(to: tempURL, atomically: true, encoding: .utf8)
        return tempURL
    }
    
    private func escapeCSV(_ string: String) -> String {
        if string.contains(",") || string.contains("\"") || string.contains("\n") {
            return "\"\(string.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return string
    }
    
    private func escapeHTML(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
