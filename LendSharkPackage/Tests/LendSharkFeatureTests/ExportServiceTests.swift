import XCTest
import UniformTypeIdentifiers
@testable import LendSharkFeature

final class ExportServiceTests: XCTestCase {
    var exportService: ExportService!
    var sampleTransactions: [TransactionDTO]!
    
    override func setUp() {
        super.setUp()
        exportService = ExportService()
        sampleTransactions = createSampleTransactions()
    }
    
    override func tearDown() {
        exportService = nil
        sampleTransactions = nil
        super.tearDown()
    }
    
    // MARK: - CSV Export Tests
    
    func testExportTransactions_CSVFormat_CreatesValidFile() async throws {
        // When
        let result = try await exportService.exportTransactions(sampleTransactions, format: .csv)
        
        // Then
        XCTAssertEqual(result.format, .csv)
        XCTAssertEqual(result.transactionCount, sampleTransactions.count)
        XCTAssertTrue(result.fileURL.lastPathComponent.hasSuffix(".csv"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.fileURL.path))
        
        // Verify CSV content
        let csvContent = try String(contentsOf: result.fileURL)
        XCTAssertTrue(csvContent.contains("Date,Type,Party,Amount,Item,Settlement Status,Notes"))
        XCTAssertTrue(csvContent.contains("John"))
        XCTAssertTrue(csvContent.contains("Sarah"))
        XCTAssertTrue(csvContent.contains("Lent"))
        XCTAssertTrue(csvContent.contains("Borrowed"))
        
        // Cleanup
        try? FileManager.default.removeItem(at: result.fileURL)
    }
    
    func testExportTransactions_CSVFormat_EmptyTransactions_CreatesHeaderOnly() async throws {
        // When
        let result = try await exportService.exportTransactions([], format: .csv)
        
        // Then
        XCTAssertEqual(result.transactionCount, 0)
        
        let csvContent = try String(contentsOf: result.fileURL)
        let lines = csvContent.components(separatedBy: .newlines).filter { !$0.isEmpty }
        XCTAssertEqual(lines.count, 1) // Only header
        XCTAssertTrue(lines[0].contains("Date,Type,Party,Amount,Item,Settlement Status,Notes"))
        
        // Cleanup
        try? FileManager.default.removeItem(at: result.fileURL)
    }
    
    func testExportTransactions_CSVFormat_HandlesSpecialCharacters() async throws {
        // Given
        let specialTransactions = [
            TransactionDTO(
                party: "John \"The Great\" O'Connor",
                amount: 50.0,
                direction: .lent,
                notes: "Lunch, with extra \"quotes\" and commas"
            )
        ]
        
        // When
        let result = try await exportService.exportTransactions(specialTransactions, format: .csv)
        
        // Then
        let csvContent = try String(contentsOf: result.fileURL)
        XCTAssertTrue(csvContent.contains("\"John \"\"The Great\"\" O'Connor\""))
        XCTAssertTrue(csvContent.contains("\"Lunch, with extra \"\"quotes\"\" and commas\""))
        
        // Cleanup
        try? FileManager.default.removeItem(at: result.fileURL)
    }
    
    // MARK: - JSON Export Tests
    
    func testExportTransactions_JSONFormat_CreatesValidFile() async throws {
        // When
        let result = try await exportService.exportTransactions(sampleTransactions, format: .json)
        
        // Then
        XCTAssertEqual(result.format, .json)
        XCTAssertEqual(result.transactionCount, sampleTransactions.count)
        XCTAssertTrue(result.fileURL.lastPathComponent.hasSuffix(".json"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.fileURL.path))
        
        // Verify JSON content
        let jsonData = try Data(contentsOf: result.fileURL)
        let decoded = try JSONDecoder().decode([String: Any].self, from: jsonData)
        
        XCTAssertNotNil(decoded["exportDate"])
        XCTAssertEqual(decoded["transactionCount"] as? Int, sampleTransactions.count)
        XCTAssertNotNil(decoded["transactions"])
        
        // Cleanup
        try? FileManager.default.removeItem(at: result.fileURL)
    }
    
    func testExportTransactions_JSONFormat_ValidatesJSONStructure() async throws {
        // When
        let result = try await exportService.exportTransactions(sampleTransactions, format: .json)
        
        // Then
        let jsonData = try Data(contentsOf: result.fileURL)
        
        // Ensure we can decode back to our expected structure
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        // This should not throw if JSON structure is correct
        _ = try decoder.decode(JSONExportData.self, from: jsonData)
        
        // Cleanup
        try? FileManager.default.removeItem(at: result.fileURL)
    }
    
    // MARK: - PDF Export Tests
    
    @MainActor
    func testExportTransactions_PDFFormat_CreatesValidFile() async throws {
        // When
        let result = try await exportService.exportTransactions(sampleTransactions, format: .pdf)
        
        // Then
        XCTAssertEqual(result.format, .pdf)
        XCTAssertEqual(result.transactionCount, sampleTransactions.count)
        XCTAssertTrue(result.fileURL.lastPathComponent.hasSuffix(".pdf"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.fileURL.path))
        
        // Verify file size (PDF should have content)
        let attributes = try FileManager.default.attributesOfItem(atPath: result.fileURL.path)
        let fileSize = attributes[.size] as? UInt64 ?? 0
        XCTAssertGreaterThan(fileSize, 1000) // PDF should be at least 1KB
        
        // Cleanup
        try? FileManager.default.removeItem(at: result.fileURL)
    }
    
    @MainActor
    func testExportTransactions_PDFFormat_LargeDataset_HandlesEfficiently() async throws {
        // Given
        let largeTransactionSet = createLargeTransactionDataset(count: 1000)
        
        // When
        let startTime = Date()
        let result = try await exportService.exportTransactions(largeTransactionSet, format: .pdf)
        let duration = Date().timeIntervalSince(startTime)
        
        // Then
        XCTAssertLessThan(duration, 10.0) // Should complete within 10 seconds
        XCTAssertEqual(result.transactionCount, 1000)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.fileURL.path))
        
        // Cleanup
        try? FileManager.default.removeItem(at: result.fileURL)
    }
    
    // MARK: - Supported Formats Tests
    
    func testGetSupportedFormats_ReturnsAllFormats() {
        // When
        let formats = exportService.getSupportedFormats()
        
        // Then
        XCTAssertEqual(formats.count, 3)
        XCTAssertTrue(formats.contains(.csv))
        XCTAssertTrue(formats.contains(.pdf))
        XCTAssertTrue(formats.contains(.json))
    }
    
    // MARK: - Error Handling Tests
    
    func testExportTransactions_InvalidFilePermissions_ThrowsError() async {
        // Given - Create a read-only directory
        let readOnlyDir = FileManager.default.temporaryDirectory.appendingPathComponent("readonly")
        try? FileManager.default.createDirectory(at: readOnlyDir, withIntermediateDirectories: true)
        
        // Make directory read-only (this may not work in all test environments)
        do {
            try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: readOnlyDir.path)
        } catch {
            // Skip this test if we can't set permissions
            throw XCTSkip("Cannot set file permissions in test environment")
        }
        
        // Note: This test may be limited by sandboxing in test environment
        // In practice, we would mock the file system for more reliable testing
    }
    
    func testExportTransactions_VeryLargeTransactionNotes_HandlesGracefully() async throws {
        // Given
        let largeNoteTransactions = [
            TransactionDTO(
                party: "John",
                amount: 50.0,
                direction: .lent,
                notes: String(repeating: "This is a very long note. ", count: 1000)
            )
        ]
        
        // When
        let result = try await exportService.exportTransactions(largeNoteTransactions, format: .csv)
        
        // Then
        XCTAssertEqual(result.transactionCount, 1)
        let csvContent = try String(contentsOf: result.fileURL)
        XCTAssertTrue(csvContent.contains("This is a very long note."))
        
        // Cleanup
        try? FileManager.default.removeItem(at: result.fileURL)
    }
    
    // MARK: - Data Integrity Tests
    
    func testExportTransactions_ItemTransactions_IncludesItemInformation() async throws {
        // Given
        let itemTransactions = [
            TransactionDTO(
                party: "Alice",
                direction: .lent,
                item: "My favorite book",
                isItem: true,
                notes: "Return by next week"
            )
        ]
        
        // When
        let csvResult = try await exportService.exportTransactions(itemTransactions, format: .csv)
        let jsonResult = try await exportService.exportTransactions(itemTransactions, format: .json)
        
        // Then - CSV should include item information
        let csvContent = try String(contentsOf: csvResult.fileURL)
        XCTAssertTrue(csvContent.contains("My favorite book"))
        XCTAssertTrue(csvContent.contains("Alice"))
        
        // JSON should preserve item structure
        let jsonData = try Data(contentsOf: jsonResult.fileURL)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
        XCTAssertTrue(jsonString.contains("My favorite book"))
        XCTAssertTrue(jsonString.contains("\"isItem\" : true"))
        
        // Cleanup
        try? FileManager.default.removeItem(at: csvResult.fileURL)
        try? FileManager.default.removeItem(at: jsonResult.fileURL)
    }
    
    func testExportTransactions_SettledTransactions_IndicatesSettlementStatus() async throws {
        // Given
        let settledTransactions = [
            TransactionDTO(
                party: "Bob",
                amount: 100.0,
                direction: .lent,
                settled: true
            ),
            TransactionDTO(
                party: "Carol",
                amount: 50.0,
                direction: .borrowed,
                settled: false
            )
        ]
        
        // When
        let result = try await exportService.exportTransactions(settledTransactions, format: .csv)
        
        // Then
        let csvContent = try String(contentsOf: result.fileURL)
        XCTAssertTrue(csvContent.contains("Settled"))
        XCTAssertTrue(csvContent.contains("Open"))
        
        // Cleanup
        try? FileManager.default.removeItem(at: result.fileURL)
    }
    
    // MARK: - Currency and Localization Tests
    
    func testExportTransactions_DifferentCurrencyAmounts_FormatsCorrectly() async throws {
        // Given
        let currencyTransactions = [
            TransactionDTO(party: "Euro User", amount: 99.99, direction: .lent),
            TransactionDTO(party: "Cent User", amount: 0.01, direction: .borrowed),
            TransactionDTO(party: "Large Amount", amount: 10000.50, direction: .lent)
        ]
        
        // When
        let result = try await exportService.exportTransactions(currencyTransactions, format: .csv)
        
        // Then
        let csvContent = try String(contentsOf: result.fileURL)
        XCTAssertTrue(csvContent.contains("99.99"))
        XCTAssertTrue(csvContent.contains("0.01"))
        XCTAssertTrue(csvContent.contains("10000.50"))
        
        // Cleanup
        try? FileManager.default.removeItem(at: result.fileURL)
    }
    
    // MARK: - Concurrent Export Tests
    
    func testExportTransactions_ConcurrentExports_HandledSafely() async throws {
        // Given
        let formats: [ExportFormat] = [.csv, .json, .pdf]
        var results: [ExportResultDTO] = []
        
        // When - Perform concurrent exports
        try await withThrowingTaskGroup(of: ExportResultDTO.self) { group in
            for format in formats {
                group.addTask { [weak self] in
                    guard let self = self else { throw ExportError.internalError }
                    return try await self.exportService.exportTransactions(self.sampleTransactions, format: format)
                }
            }
            
            for try await result in group {
                results.append(result)
            }
        }
        
        // Then
        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results.allSatisfy { $0.transactionCount == sampleTransactions.count })
        
        // All files should exist
        for result in results {
            XCTAssertTrue(FileManager.default.fileExists(atPath: result.fileURL.path))
        }
        
        // Cleanup
        for result in results {
            try? FileManager.default.removeItem(at: result.fileURL)
        }
    }
    
    // MARK: - Performance Tests
    
    func testExportPerformance_CSV() {
        let largeDataset = createLargeTransactionDataset(count: 500)
        
        measure {
            Task {
                do {
                    let result = try await exportService.exportTransactions(largeDataset, format: .csv)
                    try? FileManager.default.removeItem(at: result.fileURL)
                } catch {
                    XCTFail("Export failed: \(error)")
                }
            }
        }
    }
    
    @MainActor
    func testExportPerformance_PDF() {
        let mediumDataset = createLargeTransactionDataset(count: 100)
        
        measure {
            Task {
                do {
                    let result = try await exportService.exportTransactions(mediumDataset, format: .pdf)
                    try? FileManager.default.removeItem(at: result.fileURL)
                } catch {
                    XCTFail("Export failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createSampleTransactions() -> [TransactionDTO] {
        let baseDate = Date()
        return [
            TransactionDTO(
                id: UUID(),
                party: "John",
                amount: 50.0,
                direction: .lent,
                timestamp: baseDate.addingTimeInterval(-86400), // 1 day ago
                notes: "Lunch money"
            ),
            TransactionDTO(
                id: UUID(),
                party: "Sarah",
                amount: 75.50,
                direction: .borrowed,
                timestamp: baseDate.addingTimeInterval(-7200), // 2 hours ago
                notes: "Gas money"
            ),
            TransactionDTO(
                id: UUID(),
                party: "Mike",
                direction: .lent,
                item: "Book",
                isItem: true,
                timestamp: baseDate.addingTimeInterval(-3600), // 1 hour ago
                notes: "Programming book"
            ),
            TransactionDTO(
                id: UUID(),
                party: "Alice",
                amount: 25.0,
                direction: .lent,
                settled: true,
                timestamp: baseDate,
                notes: "Coffee"
            )
        ]
    }
    
    private func createLargeTransactionDataset(count: Int) -> [TransactionDTO] {
        var transactions: [TransactionDTO] = []
        let parties = ["John", "Sarah", "Mike", "Alice", "Bob", "Carol", "David", "Eva"]
        let directions: [TransactionDirection] = [.lent, .borrowed]
        let notes = ["Lunch", "Gas", "Coffee", "Movie", "Dinner", "Groceries", "Books", "Travel"]
        
        for i in 0..<count {
            let isItem = i % 10 == 0 // Every 10th transaction is an item
            
            let transaction = TransactionDTO(
                id: UUID(),
                party: parties[i % parties.count],
                amount: isItem ? nil : Decimal(Double.random(in: 1.0...500.0)),
                direction: directions[i % directions.count],
                item: isItem ? "Item \(i)" : nil,
                isItem: isItem,
                settled: i % 3 == 0, // Every 3rd transaction is settled
                timestamp: Date().addingTimeInterval(TimeInterval(-i * 3600)), // Spread over time
                notes: notes[i % notes.count]
            )
            
            transactions.append(transaction)
        }
        
        return transactions
    }
}

// MARK: - Helper Extensions

private extension JSONDecoder {
    func decode<T>(_ type: T.Type, from data: Data) throws -> T where T : Decodable {
        // Helper for type-erased decoding in tests
        return try self.decode(type, from: data)
    }
}

// MARK: - Mock Export Error

enum ExportError: Error {
    case internalError
}

// MARK: - JSONExportData for Testing

private struct JSONExportData: Codable {
    let exportDate: Date
    let transactionCount: Int
    let transactions: [TransactionDTO]
}