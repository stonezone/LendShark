import XCTest
@testable import LendSharkFeature

final class TransactionDTOTests: XCTestCase {
    
    func testDTOCreation() {
        let dto = TransactionDTO(
            party: "John Doe",
            amount: 50.0,
            direction: .lent
        )
        
        XCTAssertEqual(dto.party, "John Doe")
        XCTAssertEqual(dto.amount, 50.0)
        XCTAssertEqual(dto.direction, .lent)
        XCTAssertFalse(dto.isItem)
        XCTAssertFalse(dto.settled)
    }
    
    func testDTOEquality() {
        let id = UUID()
        let dto1 = TransactionDTO(
            id: id,
            party: "Jane",
            amount: 25.0,
            direction: .borrowed
        )
        
        let dto2 = TransactionDTO(
            id: id,
            party: "Jane",
            amount: 25.0,
            direction: .borrowed
        )
        
        XCTAssertEqual(dto1, dto2)
    }
    
    func testDTOCodable() throws {
        let dto = TransactionDTO(
            party: "Test User",
            amount: 100.0,
            direction: .lent,
            notes: "Test notes"
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(dto)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TransactionDTO.self, from: data)
        
        XCTAssertEqual(decoded.party, dto.party)
        XCTAssertEqual(decoded.amount, dto.amount)
        XCTAssertEqual(decoded.notes, dto.notes)
    }
    
    func testVersionConstant() {
        XCTAssertEqual(TransactionDTO.version, "1.0.0")
    }
}
