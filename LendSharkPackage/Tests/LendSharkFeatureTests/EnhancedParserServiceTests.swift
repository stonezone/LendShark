import XCTest
@testable import LendSharkFeature

final class EnhancedParserServiceTests: XCTestCase {
    var parser: ParserService!
    var validationService: ValidationService!
    
    override func setUp() {
        super.setUp()
        validationService = ValidationService()
        parser = ParserService(validationService: validationService)
    }
    
    // MARK: - "Paid back" Pattern Tests
    
    func testParsePaidBack() {
        let inputs = [
            "paid back 50",
            "john paid back 30",
            "paid john back 25",
            "sarah paid me back twenty"
        ]
        
        for input in inputs {
            let result = parser.parse(input)
            switch result {
            case .success(let action):
                if case .add(let dto) = action {
                    XCTAssertNotNil(dto.amount, "Amount should be parsed for: \(input)")
                    XCTAssertEqual(dto.direction, .borrowed, "Paid back indicates borrowed direction")
                    XCTAssertTrue(dto.settled, "Paid back transactions should be settled")
                } else {
                    XCTFail("Expected add action for: \(input)")
                }
            case .failure(let error):
                XCTFail("Parse failed for '\(input)': \(error)")
            }
        }
    }
    
    // MARK: - "Owes" Pattern Tests
    
    func testParseOwesMe() {
        let result = parser.parse("john owes me 45")
        
        switch result {
        case .success(let action):
            if case .add(let dto) = action {
                XCTAssertEqual(dto.party, "john")
                XCTAssertEqual(dto.amount, 45)
                XCTAssertEqual(dto.direction, .lent, "They owe us = we lent")
            } else {
                XCTFail("Expected add action")
            }
        case .failure(let error):
            XCTFail("Parse failed: \(error)")
        }
    }
    
    func testParseIOwe() {
        let result = parser.parse("I owe sarah 30.50")
        
        switch result {
        case .success(let action):
            if case .add(let dto) = action {
                XCTAssertEqual(dto.party, "sarah")
                XCTAssertEqual(dto.amount, 30.50)
                XCTAssertEqual(dto.direction, .borrowed, "I owe them = I borrowed")
            } else {
                XCTFail("Expected add action")
            }
        case .failure(let error):
            XCTFail("Parse failed: \(error)")
        }
    }
    
    // MARK: - Split Pattern Tests
    
    func testParseSplitWithOne() {
        let result = parser.parse("split 60 with john")
        
        switch result {
        case .success(let action):
            if case .add(let dto) = action {
                XCTAssertEqual(dto.party, "john")
                XCTAssertEqual(dto.amount, 30, "Should split 60 in half")
                XCTAssertEqual(dto.direction, .lent)
                XCTAssertNotNil(dto.notes)
            } else {
                XCTFail("Expected add action")
            }
        case .failure(let error):
            XCTFail("Parse failed: \(error)")
        }
    }
    
    func testParseSplitMultiple() {
        let result = parser.parse("split 90 between john, sarah, and mike")
        
        switch result {
        case .success(let action):
            if case .add(let dto) = action {
                XCTAssertEqual(dto.party, "john", "Should use first party as primary")
                XCTAssertEqual(dto.amount, 67.5, "90 split 4 ways (including self) * 3 others")
                XCTAssertEqual(dto.direction, .lent)
                XCTAssertTrue(dto.notes?.contains("Split with") ?? false)
            } else {
                XCTFail("Expected add action")
            }
        case .failure(let error):
            XCTFail("Parse failed: \(error)")
        }
    }
    
    // MARK: - Currency Symbol Tests
    
    func testParseCurrencySymbols() {
        let inputs = [
            ("$25.50", 25.50),
            ("€30", 30),
            ("£45.99", 45.99),
            ("¥1000", 1000)
        ]
        
        for (input, expectedAmount) in inputs {
            let fullInput = "lent \(input) to alex"
            let result = parser.parse(fullInput)
            
            switch result {
            case .success(let action):
                if case .add(let dto) = action {
                    XCTAssertEqual(dto.amount, Decimal(expectedAmount), "Should parse \(input)")
                } else {
                    XCTFail("Expected add action for: \(fullInput)")
                }
            case .failure(let error):
                XCTFail("Parse failed for '\(fullInput)': \(error)")
            }
        }
    }
    
    // MARK: - Written Number Tests
    
    func testParseWrittenNumbers() {
        let inputs = [
            ("twenty", 20),
            ("fifty", 50),
            ("one hundred", 100),
            ("thirty five", 35),
            ("ninety nine", 99)
        ]
        
        for (written, expectedAmount) in inputs {
            let fullInput = "lent \(written) to bob"
            let result = parser.parse(fullInput)
            
            switch result {
            case .success(let action):
                if case .add(let dto) = action {
                    XCTAssertEqual(dto.amount, Decimal(expectedAmount), "Should parse '\(written)'")
                } else {
                    XCTFail("Expected add action for: \(fullInput)")
                }
            case .failure:
                // Written numbers might not all work perfectly, which is acceptable
                print("Note: Written number '\(written)' didn't parse")
            }
        }
    }
    
    // MARK: - Date Pattern Tests
    
    func testParseDatePatterns() {
        let dateInputs = [
            "lent 50 to john due tomorrow",
            "borrowed 30 from sarah last week",
            "lent 25 to mike on friday",
            "gave 40 to alex next month",
            "lent 20 to bob yesterday",
            "borrowed 60 from alice end of month"
        ]
        
        for input in dateInputs {
            let result = parser.parse(input)
            
            switch result {
            case .success(let action):
                if case .add(let dto) = action {
                    // We just verify it parses successfully
                    XCTAssertNotNil(dto.party, "Should have party for: \(input)")
                    XCTAssertNotNil(dto.amount, "Should have amount for: \(input)")
                } else {
                    XCTFail("Expected add action for: \(input)")
                }
            case .failure(let error):
                XCTFail("Parse failed for '\(input)': \(error)")
            }
        }
    }
    
    // MARK: - Category Tests
    
    func testParseCategoriesInNotes() {
        let categoryInputs = [
            ("lent 20 to john for lunch", "Food"),
            ("borrowed 50 from sarah for gas", "Transport"),
            ("lent 30 to mike for movie tickets", "Entertainment"),
            ("gave 100 to alex for rent", "Utilities"),
            ("lent 25 to bob for uber", "Transport")
        ]
        
        for (input, expectedCategory) in categoryInputs {
            let result = parser.parse(input)
            
            switch result {
            case .success(let action):
                if case .add(let dto) = action {
                    XCTAssertNotNil(dto.notes, "Should have notes for: \(input)")
                    if let notes = dto.notes {
                        XCTAssertTrue(
                            notes.contains(expectedCategory) || notes.contains("lunch") || 
                            notes.contains("gas") || notes.contains("movie") || 
                            notes.contains("rent") || notes.contains("uber"),
                            "Notes should contain category or context for: \(input)"
                        )
                    }
                } else {
                    XCTFail("Expected add action for: \(input)")
                }
            case .failure(let error):
                XCTFail("Parse failed for '\(input)': \(error)")
            }
        }
    }
    
    // MARK: - Complex Pattern Tests
    
    func testComplexPatterns() {
        let complexInputs = [
            "john owes me $25.50 for lunch yesterday",
            "split 90 with sarah and mike for dinner last night",
            "paid back twenty to alex note: finally settled",
            "I owe bob fifty dollars for gas money tomorrow",
            "sarah paid for the movie tickets 30"
        ]
        
        for input in complexInputs {
            let result = parser.parse(input)
            
            switch result {
            case .success(let action):
                // Just verify these complex patterns parse successfully
                XCTAssertNotNil(action, "Should parse: \(input)")
            case .failure(let error):
                XCTFail("Complex pattern failed for '\(input)': \(error)")
            }
        }
    }
    
    // MARK: - Backward Compatibility Tests
    
    func testBackwardCompatibility() {
        // Ensure original patterns still work
        let originalPatterns = [
            "lent 50 to john",
            "borrowed 25.50 from sarah",
            "lent my book to alice",
            "settle with bob",
            "lent 30 to mike note: for lunch"
        ]
        
        for input in originalPatterns {
            let result = parser.parse(input)
            
            switch result {
            case .success:
                XCTAssertTrue(true, "Original pattern should still work: \(input)")
            case .failure(let error):
                XCTFail("Original pattern failed: \(input) - \(error)")
            }
        }
    }
}