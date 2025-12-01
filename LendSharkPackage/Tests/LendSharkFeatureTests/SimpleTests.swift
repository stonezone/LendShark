import XCTest
@testable import LendSharkFeature

/// Simple tests that work with the current architecture
/// Focus on testing public interfaces without complex setup
final class SimpleTests: XCTestCase {
    
    // MARK: - ValidationService Tests
    
    func testValidationService_ValidTransaction_Succeeds() {
        let validationService = ValidationService()
        let dto = TransactionDTO(party: "John Doe", amount: Decimal(50), direction: .lent)
        let result = validationService.validateTransaction(dto)
        
        switch result {
        case .success(let validatedDTO):
            XCTAssertEqual(validatedDTO.party, "John Doe")
            XCTAssertEqual(validatedDTO.amount, Decimal(50))
            XCTAssertEqual(validatedDTO.direction, .lent)
        case .failure(let error):
            XCTFail("Validation should succeed but failed with: \(error)")
        }
    }
    
    func testValidationService_EmptyPartyName_Fails() {
        let validationService = ValidationService()
        let dto = TransactionDTO(party: "", amount: Decimal(50), direction: .lent)
        let result = validationService.validateTransaction(dto)
        
        switch result {
        case .success:
            XCTFail("Validation should fail for empty party name")
        case .failure(let error):
            if case .invalidPartyName = error {
                // Expected
            } else {
                XCTFail("Expected invalidPartyName error but got: \(error)")
            }
        }
    }
    
    func testValidationService_NegativeAmount_Fails() {
        let validationService = ValidationService()
        let dto = TransactionDTO(party: "John Doe", amount: Decimal(-50), direction: .lent)
        let result = validationService.validateTransaction(dto)
        
        switch result {
        case .success:
            XCTFail("Validation should fail for negative amount")
        case .failure(let error):
            if case .invalidAmount = error {
                // Expected
            } else {
                XCTFail("Expected invalidAmount error but got: \(error)")
            }
        }
    }
    
    // MARK: - ParserService Tests
    
    func testParserService_LentTransaction_ParsesCorrectly() {
        let validationService = ValidationService()
        let parserService = ParserService(validationService: validationService)
        let input = "lent $50 to John"
        let result = parserService.parse(input)
        
        switch result {
        case .success(let action):
            if case .add(let dto) = action {
                XCTAssertEqual(dto.amount, Decimal(50))
                XCTAssertEqual(dto.party, "John")
                XCTAssertEqual(dto.direction, .lent)
            } else {
                XCTFail("Expected add action but got \(action)")
            }
        case .failure(let error):
            XCTFail("Parsing should succeed but failed with: \(error)")
        }
    }
    
    func testParserService_BorrowedTransaction_ParsesCorrectly() {
        let validationService = ValidationService()
        let parserService = ParserService(validationService: validationService)
        let input = "borrowed $25 from Jane"
        let result = parserService.parse(input)
        
        switch result {
        case .success(let action):
            if case .add(let dto) = action {
                XCTAssertEqual(dto.amount, Decimal(25))
                XCTAssertEqual(dto.party, "Jane")
                XCTAssertEqual(dto.direction, .borrowed)
            } else {
                XCTFail("Expected add action but got \(action)")
            }
        case .failure(let error):
            XCTFail("Parsing should succeed but failed with: \(error)")
        }
    }
    
    func testParserService_InvalidInput_Fails() {
        let validationService = ValidationService()
        let parserService = ParserService(validationService: validationService)
        let input = "invalid transaction text"
        let result = parserService.parse(input)
        
        switch result {
        case .success:
            XCTFail("Parsing should fail for invalid input")
        case .failure:
            // Expected
            break
        }
    }
    
    func testParserService_SettleAction_ParsesCorrectly() {
        let validationService = ValidationService()
        let parserService = ParserService(validationService: validationService)
        let input = "settle with John"
        let result = parserService.parse(input)
        
        switch result {
        case .success(let action):
            if case .settle(let party) = action {
                XCTAssertEqual(party, "John")
            } else {
                XCTFail("Expected settle action but got \(action)")
            }
        case .failure(let error):
            XCTFail("Parsing should succeed but failed with: \(error)")
        }
    }
    
    // MARK: - TransactionDTO Tests
    
    func testTransactionDTO_Initialization_SetsDefaultValues() {
        let dto = TransactionDTO(party: "Test Party", direction: .lent)
        
        XCTAssertNotNil(dto.id)
        XCTAssertEqual(dto.party, "Test Party")
        XCTAssertEqual(dto.direction, .lent)
        XCTAssertFalse(dto.settled)
        XCTAssertFalse(dto.isItem)
        XCTAssertNotNil(dto.timestamp)
    }
    
    func testTransactionDTO_Codable_EncodesAndDecodes() throws {
        let originalDTO = TransactionDTO(
            party: "Test Party",
            amount: Decimal(100),
            item: "Test Item",
            direction: .borrowed,
            notes: "Test Notes"
        )
        
        let encoded = try JSONEncoder().encode(originalDTO)
        let decodedDTO = try JSONDecoder().decode(TransactionDTO.self, from: encoded)
        
        XCTAssertEqual(originalDTO.id, decodedDTO.id)
        XCTAssertEqual(originalDTO.party, decodedDTO.party)
        XCTAssertEqual(originalDTO.amount, decodedDTO.amount)
        XCTAssertEqual(originalDTO.item, decodedDTO.item)
        XCTAssertEqual(originalDTO.direction, decodedDTO.direction)
        XCTAssertEqual(originalDTO.notes, decodedDTO.notes)
    }
    
    func testTransactionDTO_Equality_WorksCorrectly() {
        let dto1 = TransactionDTO(id: UUID(), party: "John", amount: Decimal(50), direction: .lent)
        let dto2 = TransactionDTO(id: dto1.id, party: "John", amount: Decimal(50), direction: .lent, timestamp: dto1.timestamp)
        let dto3 = TransactionDTO(party: "Jane", amount: Decimal(50), direction: .lent)
        
        XCTAssertEqual(dto1, dto2)
        XCTAssertNotEqual(dto1, dto3)
    }
    
    // MARK: - Integration Test (Simplified)
    
    @MainActor
    func testParserValidationIntegration_ValidInput_Success() {
        let validationService = ValidationService()
        let parserService = ParserService(validationService: validationService)
        
        let input = "lent $75 to Alice for groceries"
        let parseResult = parserService.parse(input)
        
        guard case .success(let action) = parseResult,
              case .add(let dto) = action else {
            XCTFail("Failed to parse input")
            return
        }
        
        // Validate the parsed DTO
        let validationResult = validationService.validateTransaction(dto)
        
        switch validationResult {
        case .success(let validatedDTO):
            XCTAssertEqual(validatedDTO.party, "Alice")
            XCTAssertEqual(validatedDTO.amount, Decimal(75))
            XCTAssertEqual(validatedDTO.direction, .lent)
        case .failure(let error):
            XCTFail("Validation failed with: \(error)")
        }
    }
    
    // MARK: - Performance Tests
    
    func testValidationService_Performance() {
        let validationService = ValidationService()
        let dto = TransactionDTO(party: "Performance Test", amount: Decimal(100), direction: .lent)
        
        measure {
            for _ in 1...1000 {
                _ = validationService.validateTransaction(dto)
            }
        }
    }
    
    func testParserService_Performance() {
        let validationService = ValidationService()
        let parserService = ParserService(validationService: validationService)
        let inputs = [
            "lent $50 to John",
            "borrowed $25 from Jane",
            "owe $100 to Bob for dinner",
            "lent 75 to Alice for groceries"
        ]
        
        measure {
            for input in inputs {
                for _ in 1...100 {
                    _ = parserService.parse(input)
                }
            }
        }
    }
}