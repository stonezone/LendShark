import Foundation
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
import CoreText
#endif

/// Export service for CSV, PDF, and JSON formats.
public final class ExportService: Sendable {
    
    public init() {}
    
    public func exportTransactions(_ transactions: [TransactionDTO], format: ExportFormat) async throws -> ExportResultDTO {
        let fileURL: URL
        
        switch format {
        case .csv:
            fileURL = try await generateCSV(from: transactions)
        case .pdf:
            fileURL = try await generatePDF(from: transactions)
        case .json:
            fileURL = try await generateJSON(from: transactions)
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
    
    // MARK: - CSV Generation
    
    private func generateCSV(from transactions: [TransactionDTO]) async throws -> URL {
        var csvContent = "Date,Type,Party,Amount,Item,Settlement Status,Notes\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none
        
        for transaction in transactions {
            let date = dateFormatter.string(from: transaction.timestamp)
            let type = transaction.direction == .lent ? "Lent" : "Borrowed"
            let party = escapeCSV(transaction.party)
            let amount = transaction.isItem ? "" : formatDecimal(transaction.amount ?? 0)
            let item = escapeCSV(transaction.item ?? "")
            let settled = transaction.settled ? "Settled" : "Open"
            let notes = escapeCSV(transaction.notes ?? "")
            
            csvContent += "\(date),\(type),\(party),\(amount),\(item),\(settled),\(notes)\n"
        }
        
        let fileName = "LendShark_Export_\(formatDateForFileName(Date())).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        try csvContent.write(to: tempURL, atomically: true, encoding: .utf8)
        return tempURL
    }
    
    // MARK: - PDF Generation
    
    private func generatePDF(from transactions: [TransactionDTO]) async throws -> URL {
        let fileName = "LendShark_Export_\(formatDateForFileName(Date())).pdf"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        // Calculate summary statistics
        let (totalLent, totalBorrowed, totalOwedToMe, totalIOwe) = calculateSummary(transactions)
        
        // Generate HTML content for PDF
        let htmlContent = generatePDFHTMLContent(
            transactions: transactions,
            totalLent: totalLent,
            totalBorrowed: totalBorrowed,
            totalOwedToMe: totalOwedToMe,
            totalIOwe: totalIOwe
        )
        
        // Create PDF from HTML using UIGraphicsPDFRenderer
        let finalURL = try await generatePDFFromHTML(htmlContent: htmlContent, outputURL: tempURL)

        return finalURL
    }
    
    private func generatePDFHTMLContent(
        transactions: [TransactionDTO],
        totalLent: Decimal,
        totalBorrowed: Decimal,
        totalOwedToMe: Decimal,
        totalIOwe: Decimal
    ) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none
        
        var html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>LendShark Export Report</title>
            <style>
                body { 
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif; 
                    margin: 20px; 
                    color: #333;
                    line-height: 1.6;
                }
                .header {
                    text-align: center;
                    margin-bottom: 30px;
                    padding-bottom: 20px;
                    border-bottom: 2px solid #14b8a6;
                }
                .header h1 { 
                    color: #14b8a6; 
                    margin-bottom: 5px;
                    font-size: 28px;
                }
                .header .subtitle {
                    color: #666;
                    font-size: 14px;
                }
                .summary {
                    display: grid;
                    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
                    gap: 15px;
                    margin: 30px 0;
                    padding: 20px;
                    background-color: #f8f9fa;
                    border-radius: 10px;
                    border-left: 4px solid #14b8a6;
                }
                .summary-item {
                    text-align: center;
                }
                .summary-item .value {
                    font-size: 24px;
                    font-weight: 600;
                    margin-bottom: 5px;
                }
                .summary-item .label {
                    font-size: 12px;
                    color: #666;
                    text-transform: uppercase;
                    letter-spacing: 0.5px;
                }
                .lent { color: #22c55e; }
                .borrowed { color: #ef4444; }
                .net-positive { color: #22c55e; }
                .net-negative { color: #ef4444; }
                table { 
                    width: 100%; 
                    border-collapse: collapse; 
                    margin-top: 20px; 
                    font-size: 14px;
                }
                th, td { 
                    padding: 12px 8px; 
                    text-align: left; 
                    border-bottom: 1px solid #e5e7eb; 
                }
                th { 
                    background-color: #f3f4f6; 
                    font-weight: 600; 
                    font-size: 12px;
                    text-transform: uppercase;
                    letter-spacing: 0.5px;
                    color: #374151;
                }
                .transaction-row:nth-child(even) {
                    background-color: #fafafa;
                }
                .settled-row { 
                    opacity: 0.6; 
                    background-color: #f0f9f0 !important;
                }
                .amount-lent { 
                    color: #22c55e; 
                    font-weight: 600; 
                }
                .amount-borrowed { 
                    color: #ef4444; 
                    font-weight: 600; 
                }
                .status-settled {
                    background-color: #22c55e;
                    color: white;
                    padding: 2px 8px;
                    border-radius: 12px;
                    font-size: 11px;
                    font-weight: 600;
                }
                .status-open {
                    background-color: #f59e0b;
                    color: white;
                    padding: 2px 8px;
                    border-radius: 12px;
                    font-size: 11px;
                    font-weight: 600;
                }
                .footer {
                    margin-top: 40px;
                    text-align: center;
                    font-size: 12px;
                    color: #666;
                    border-top: 1px solid #e5e7eb;
                    padding-top: 20px;
                }
                @media print {
                    body { margin: 0; }
                    .header { page-break-after: avoid; }
                    .summary { page-break-inside: avoid; }
                    table { page-break-inside: avoid; }
                }
            </style>
        </head>
        <body>
            <div class="header">
                <h1>LendShark Export Report</h1>
                <div class="subtitle">Generated on \(DateFormatter.localizedString(from: Date(), dateStyle: .full, timeStyle: .short))</div>
            </div>
            
            <div class="summary">
                <div class="summary-item">
                    <div class="value lent">$\(formatDecimal(totalLent))</div>
                    <div class="label">Total Lent</div>
                </div>
                <div class="summary-item">
                    <div class="value borrowed">$\(formatDecimal(totalBorrowed))</div>
                    <div class="label">Total Borrowed</div>
                </div>
                <div class="summary-item">
                    <div class="value lent">$\(formatDecimal(totalOwedToMe))</div>
                    <div class="label">Owed to Me</div>
                </div>
                <div class="summary-item">
                    <div class="value borrowed">$\(formatDecimal(totalIOwe))</div>
                    <div class="label">I Owe</div>
                </div>
                <div class="summary-item">
                    <div class="value \(totalOwedToMe - totalIOwe >= 0 ? "net-positive" : "net-negative")">$\(formatDecimal(abs(totalOwedToMe - totalIOwe)))</div>
                    <div class="label">Net \(totalOwedToMe - totalIOwe >= 0 ? "Owed to Me" : "I Owe")</div>
                </div>
                <div class="summary-item">
                    <div class="value">\(transactions.count)</div>
                    <div class="label">Total Transactions</div>
                </div>
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
        
        for transaction in transactions {
            let date = dateFormatter.string(from: transaction.timestamp)
            let type = transaction.direction == .lent ? "Lent" : "Borrowed"
            let typeClass = transaction.direction == .lent ? "lent" : "borrowed"
            let party = escapeHTML(transaction.party)
            let amountOrItem = transaction.isItem ? 
                escapeHTML(transaction.item ?? "Item") : 
                "$\(formatDecimal(transaction.amount ?? 0))"
            let amountClass = transaction.direction == .lent ? "amount-lent" : "amount-borrowed"
            let status = transaction.settled ? "Settled" : "Open"
            let statusClass = transaction.settled ? "status-settled" : "status-open"
            let rowClass = transaction.settled ? "transaction-row settled-row" : "transaction-row"
            let notes = escapeHTML(transaction.notes ?? "")
            
            html += """
                <tr class="\(rowClass)">
                    <td>\(date)</td>
                    <td class="\(typeClass)">\(type)</td>
                    <td>\(party)</td>
                    <td class="\(amountClass)">\(amountOrItem)</td>
                    <td><span class="\(statusClass)">\(status)</span></td>
                    <td>\(notes)</td>
                </tr>
            """
        }
        
        html += """
                </tbody>
            </table>
            
            <div class="footer">
                <p>This report contains \(transactions.count) transaction(s) • Generated by LendShark</p>
            </div>
        </body>
        </html>
        """
        
        return html
    }
    
    @MainActor
    private func generatePDFFromHTML(htmlContent: String, outputURL: URL) async throws -> URL {
        #if canImport(UIKit)
        // Create PDF using UIGraphicsPDFRenderer with better pagination
        let pageSize = CGSize(width: 612, height: 792) // Standard 8.5x11 inch page
        let pageMargins = UIEdgeInsets(top: 50, left: 50, bottom: 50, right: 50)
        let contentSize = CGSize(
            width: pageSize.width - pageMargins.left - pageMargins.right,
            height: pageSize.height - pageMargins.top - pageMargins.bottom
        )
        
        // Convert HTML to attributed string
        guard let htmlData = htmlContent.data(using: .utf8) else {
            throw NSError(domain: "ExportService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert HTML to data"])
        }
        
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        
        let attributedString: NSAttributedString
        do {
            attributedString = try NSAttributedString(data: htmlData, options: options, documentAttributes: nil)
        } catch {
            throw NSError(domain: "ExportService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to parse HTML content: \(error.localizedDescription)"])
        }
        
        // Create PDF renderer
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        
        let pdfData = pdfRenderer.pdfData { context in
            // Setup text storage and layout manager for proper text flow
            let textStorage = NSTextStorage(attributedString: attributedString)
            let layoutManager = NSLayoutManager()
            textStorage.addLayoutManager(layoutManager)
            
            // Track current position
            var currentOffset = 0
            let totalLength = attributedString.length
            
            while currentOffset < totalLength {
                // Start new page
                context.beginPage()
                
                // Create text container for this page
                let textContainer = NSTextContainer(size: contentSize)
                textContainer.lineFragmentPadding = 0
                layoutManager.addTextContainer(textContainer)
                
                // Calculate glyph range for this container
                let glyphRange = layoutManager.glyphRange(for: textContainer)
                
                // Draw the text
                let drawingRect = CGRect(
                    x: pageMargins.left,
                    y: pageMargins.top,
                    width: contentSize.width,
                    height: contentSize.height
                )
                
                // Create substring for this page
                let rangeForPage = NSRange(
                    location: currentOffset,
                    length: min(glyphRange.length, totalLength - currentOffset)
                )
                
                if rangeForPage.length > 0 {
                    let pageText = attributedString.attributedSubstring(from: rangeForPage)
                    
                    // Apply consistent formatting
                    let mutablePageText = NSMutableAttributedString(attributedString: pageText)
                    let fullRange = NSRange(location: 0, length: mutablePageText.length)
                    
                    // Set default font if not specified
                    mutablePageText.enumerateAttribute(.font, in: fullRange, options: []) { value, range, _ in
                        if value == nil {
                            mutablePageText.addAttribute(.font, 
                                                       value: UIFont.systemFont(ofSize: 12), 
                                                       range: range)
                        }
                    }
                    
                    // Draw with proper word wrapping
                    let framesetter = CTFramesetterCreateWithAttributedString(mutablePageText as CFAttributedString)
                    let framePath = CGPath(rect: drawingRect, transform: nil)
                    let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, mutablePageText.length), framePath, nil)
                    
                    let graphicsContext = UIGraphicsGetCurrentContext()!
                    graphicsContext.saveGState()
                    graphicsContext.translateBy(x: 0, y: pageSize.height)
                    graphicsContext.scaleBy(x: 1.0, y: -1.0)
                    
                    CTFrameDraw(frame, graphicsContext)
                    graphicsContext.restoreGState()
                    
                    // Update offset for next page
                    let visibleRange = CTFrameGetVisibleStringRange(frame)
                    currentOffset += visibleRange.length
                } else {
                    break
                }
                
                // Remove the text container for next iteration
                layoutManager.removeTextContainer(at: layoutManager.textContainers.count - 1)
            }
        }
        
        // Write PDF data to file
        do {
            try pdfData.write(to: outputURL)
        } catch {
            throw NSError(domain: "ExportService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to write PDF to file: \(error.localizedDescription)"])
        }
        return outputURL
        #else
        // Fallback for platforms without UIKit - save as HTML (honest about format)
        let htmlURL = outputURL.deletingPathExtension().appendingPathExtension("html")
        try htmlContent.write(to: htmlURL, atomically: true, encoding: .utf8)
        return htmlURL
        #endif
    }
    
    // MARK: - JSON Generation
    
    private func generateJSON(from transactions: [TransactionDTO]) async throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let exportData = JSONExportData(
            exportDate: Date(),
            transactionCount: transactions.count,
            transactions: transactions
        )
        
        let data = try encoder.encode(exportData)
        
        let fileName = "LendShark_Export_\(formatDateForFileName(Date())).json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        try data.write(to: tempURL)
        return tempURL
    }
    
    // MARK: - Helper Methods
    
    private func calculateSummary(_ transactions: [TransactionDTO]) -> (totalLent: Decimal, totalBorrowed: Decimal, totalOwedToMe: Decimal, totalIOwe: Decimal) {
        var totalLent: Decimal = 0
        var totalBorrowed: Decimal = 0
        var totalOwedToMe: Decimal = 0
        var totalIOwe: Decimal = 0
        
        for transaction in transactions {
            guard !transaction.isItem, let amount = transaction.amount else { continue }
            
            if transaction.direction == .lent {
                totalLent += amount
                if !transaction.settled {
                    totalOwedToMe += amount
                }
            } else {
                totalBorrowed += amount
                if !transaction.settled {
                    totalIOwe += amount
                }
            }
        }
        
        return (totalLent, totalBorrowed, totalOwedToMe, totalIOwe)
    }
    
    private func formatDecimal(_ decimal: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: decimal)) ?? "0.00"
    }
    
    private func formatDateForFileName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter.string(from: date)
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

// MARK: - Supporting Types

private struct JSONExportData: Codable {
    let exportDate: Date
    let transactionCount: Int
    let transactions: [TransactionDTO]
}
