import XCTest
@testable import LendSharkFeature

final class ParserServiceTests: XCTestCase {
    var parser: ParserService!
    var validationService: ValidationService!
    
    override func setUp() {
        super.setUp()
        validationService = ValidationService()
        parser = ParserService(validationService: validationService)
    }
    
    func testParseLentTransaction() {
        let result = parser.parse("lent 50 to john")
        
        switch result {
        case .success(let action):
            if case .add(let dto) = action {
                XCTAssertEqual(dto.party, "john")
                XCTAssertEqual(dto.amount, 50)
                XCTAssertEqual(dto.direction, .lent)
                XCTAssertFalse(dto.isItem)
            } else {
                XCTFail("Expected add action")
            }
        case .failure(let error):
            XCTFail("Parse failed: \(error)")
        }
    }
    
    func testParseBorrowedTransaction() {
        let result = parser.parse("borrowed 25.50 from sarah")
        
        switch result {
        case .success(let action):
            if case .add(let dto) = action {
                XCTAssertEqual(dto.party, "sarah")
                XCTAssertEqual(dto.amount, 25.50)
                XCTAssertEqual(dto.direction, .borrowed)
            } else {
                XCTFail("Expected add action")
            }
        case .failure(let error):
            XCTFail("Parse failed: \(error)")
        }
    }
    
    func testParseItemTransaction() {
        let result = parser.parse("lent my book to alice")
        
        switch result {
        case .success(let action):
            if case .add(let dto) = action {
                XCTAssertEqual(dto.party, "alice")
                XCTAssertTrue(dto.isItem)
                XCTAssertEqual(dto.item, "book")
                XCTAssertEqual(dto.direction, .lent)
            } else {
                XCTFail("Expected add action")
            }
        case .failure(let error):
            XCTFail("Parse failed: \(error)")
        }
    }
    
    func testParseSettlement() {
        let result = parser.parse("settle with bob")
        
        switch result {
        case .success(let action):
            if case .settle(let party) = action {
                XCTAssertEqual(party, "bob")
            } else {
                XCTFail("Expected settle action")
            }
        case .failure(let error):
            XCTFail("Parse failed: \(error)")
        }
    }
    
    func testParseWithNotes() {
        let result = parser.parse("lent 30 to mike note: for lunch")
        
        switch result {
        case .success(let action):
            if case .add(let dto) = action {
                XCTAssertEqual(dto.party, "mike")
                XCTAssertEqual(dto.amount, 30)
                XCTAssertEqual(dto.notes, "for lunch")
            } else {
                XCTFail("Expected add action")
            }
        case .failure:
            XCTFail("Parse should succeed")
        }
    }
    
    func testParseEmptyInput() {
        let result = parser.parse("")
        
        switch result {
        case .success:
            XCTFail("Should fail on empty input")
        case .failure(let error):
            XCTAssertTrue(error.localizedDescription.contains("empty"))
        }
    }
    
    func testParseInvalidFormat() {
        let result = parser.parse("random text without direction")
        
        switch result {
        case .success:
            XCTFail("Should fail on invalid format")
        case .failure(let error):
            XCTAssertTrue(error.localizedDescription.contains("determine"))
        }
    }
}
