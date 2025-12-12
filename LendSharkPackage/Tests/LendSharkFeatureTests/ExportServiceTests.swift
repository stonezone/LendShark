import XCTest
@testable import LendSharkFeature

final class ExportServiceTests: XCTestCase {
    private var exportService: ExportService!

    override func setUp() {
        super.setUp()
        exportService = ExportService()
    }

    override func tearDown() {
        exportService = nil
        super.tearDown()
    }

    func testExportCSV_WritesFileWithHeader() async throws {
        let result = try await exportService.exportTransactions(sampleTransactions(), format: .csv)
        defer { try? FileManager.default.removeItem(at: result.fileURL) }

        XCTAssertEqual(result.format, .csv)
        XCTAssertEqual(result.transactionCount, 2)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.fileURL.path))

        let csv = try String(contentsOf: result.fileURL, encoding: .utf8)
        XCTAssertTrue(csv.contains("Date,Type,Party,Amount,Item,Settlement Status,Notes"))
        XCTAssertTrue(csv.contains("John"))
        XCTAssertTrue(csv.contains("Sarah"))
    }

    func testExportJSON_WritesDecodablePayload() async throws {
        let result = try await exportService.exportTransactions(sampleTransactions(), format: .json)
        defer { try? FileManager.default.removeItem(at: result.fileURL) }

        XCTAssertEqual(result.format, .json)
        XCTAssertEqual(result.transactionCount, 2)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.fileURL.path))

        let data = try Data(contentsOf: result.fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(JSONExportData.self, from: data)

        XCTAssertEqual(decoded.transactionCount, 2)
        XCTAssertEqual(decoded.transactions.count, 2)
        XCTAssertFalse(decoded.exportDate.timeIntervalSinceNow.isNaN)
    }

    @MainActor
    func testExportPDF_WritesPDFOrHTMLDependingOnPlatform() async throws {
        let result = try await exportService.exportTransactions(sampleTransactions(), format: .pdf)
        defer { try? FileManager.default.removeItem(at: result.fileURL) }

        XCTAssertEqual(result.format, .pdf)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.fileURL.path))

        #if canImport(UIKit)
        XCTAssertEqual(result.fileURL.pathExtension.lowercased(), "pdf")
        #else
        XCTAssertEqual(result.fileURL.pathExtension.lowercased(), "html")
        #endif
    }

    private func sampleTransactions() -> [TransactionDTO] {
        [
            TransactionDTO(party: "John", amount: 50, direction: .lent, notes: "Lunch"),
            TransactionDTO(party: "Sarah", amount: 25.5, direction: .borrowed, notes: "Gas")
        ]
    }
}

private struct JSONExportData: Codable {
    let exportDate: Date
    let transactionCount: Int
    let transactions: [TransactionDTO]
}

