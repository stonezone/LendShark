import XCTest
@testable import LendSharkFeature

final class ParserServiceTests: XCTestCase {
    private var parser: ParserService!

    override func setUp() {
        super.setUp()
        parser = ParserService()
    }

    override func tearDown() {
        parser = nil
        super.tearDown()
    }

    func testParseOwes_WithAbbreviation() {
        let result = parser.parse("john owes me 2 notes")

        switch result {
        case .failure(let error):
            XCTFail("Parse failed: \(error)")
        case .success(let action):
            guard case .add(let dto) = action else {
                return XCTFail("Expected add action")
            }
            XCTAssertEqual(dto.party, "John")
            XCTAssertEqual(dto.amount, 200)
            XCTAssertEqual(dto.direction, .lent)
        }
    }

    func testParseIOwe_ParsesBorrowedDirection() {
        let result = parser.parse("i owe sarah 30.50")

        switch result {
        case .failure(let error):
            XCTFail("Parse failed: \(error)")
        case .success(let action):
            guard case .add(let dto) = action else {
                return XCTFail("Expected add action")
            }
            XCTAssertEqual(dto.party, "Sarah")
            XCTAssertEqual(dto.amount, 30.50)
            XCTAssertEqual(dto.direction, .borrowed)
        }
    }

    func testParsePaid_CreatesPartialPaymentDTO() {
        let result = parser.parse("john paid 50")

        switch result {
        case .failure(let error):
            XCTFail("Parse failed: \(error)")
        case .success(let action):
            guard case .add(let dto) = action else {
                return XCTFail("Expected add action")
            }
            XCTAssertEqual(dto.party, "John")
            XCTAssertEqual(dto.amount, 50)
            XCTAssertEqual(dto.direction, .borrowed)
            XCTAssertEqual(dto.notes, "Partial payment")
            XCTAssertFalse(dto.settled)
        }
    }

    func testParseSettle() {
        let result = parser.parse("settle with bob")

        switch result {
        case .failure(let error):
            XCTFail("Parse failed: \(error)")
        case .success(let action):
            guard case .settle(let name) = action else {
                return XCTFail("Expected settle action")
            }
            XCTAssertEqual(name, "Bob")
        }
    }

    func testParseItemBorrow_SetsIsItemAndDueDate() {
        let result = parser.parse("john borrowed my drill for 3 days")

        switch result {
        case .failure(let error):
            XCTFail("Parse failed: \(error)")
        case .success(let action):
            guard case .add(let dto) = action else {
                return XCTFail("Expected add action")
            }
            XCTAssertEqual(dto.party, "John")
            XCTAssertTrue(dto.isItem)
            XCTAssertEqual(dto.notes, "drill")
            XCTAssertNotNil(dto.dueDate)

            if let dueDate = dto.dueDate {
                let calendar = Calendar.current
                let days = calendar.dateComponents(
                    [.day],
                    from: calendar.startOfDay(for: Date()),
                    to: calendar.startOfDay(for: dueDate)
                ).day ?? 0
                XCTAssertEqual(days, 3)
            }
        }
    }

    func testParseModifiers_DueInterestNotesPhone() {
        let input = "john owes me 50 due 2 weeks at 10% (has my watch) 555-123-4567"
        let result = parser.parse(input)

        switch result {
        case .failure(let error):
            XCTFail("Parse failed: \(error)")
        case .success(let action):
            guard case .add(let dto) = action else {
                return XCTFail("Expected add action")
            }

            XCTAssertEqual(dto.party, "John")
            XCTAssertEqual(dto.amount, 50)
            XCTAssertNotNil(dto.dueDate)
            XCTAssertEqual(dto.interestRate, 0.10)
            XCTAssertEqual(dto.notes, "has my watch")
            XCTAssertEqual(dto.phoneNumber, "(555) 123-4567")
        }
    }
}

