import XCTest
@testable import LendSharkFeature

final class ValidationServiceTests: XCTestCase {
    var validationService: ValidationService!
    
    override func setUp() {
        super.setUp()
        validationService = ValidationService()
    }
    
    func testValidTransaction() {
        let dto = TransactionDTO(
            party: "John Doe",
            amount: 50.0,
            direction: .lent
        )
        
        let result = validationService.validateTransaction(dto)
        
        switch result {
        case .success(let validated):
            XCTAssertEqual(validated.party, "John Doe")
            XCTAssertEqual(validated.amount, 50.0)
        case .failure(let error):
            XCTFail("Validation failed: \(error)")
        }
    }
    
    func testEmptyPartyName() {
        let dto = TransactionDTO(
            party: "",
            amount: 50.0,
            direction: .lent
        )
        
        let result = validationService.validateTransaction(dto)
        
        switch result {
        case .success:
            XCTFail("Should fail with empty party name")
        case .failure(let error):
            if case .invalidPartyName = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
    
    func testNegativeAmount() {
        let dto = TransactionDTO(
            party: "Jane",
            amount: -10.0,
            direction: .borrowed
        )
        
        let result = validationService.validateTransaction(dto)
        
        switch result {
        case .success:
            XCTFail("Should fail with negative amount")
        case .failure(let error):
            if case .invalidAmount = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
    
    func testSanitizePartyName() {
        let input = "John<script>alert('xss')</script>Doe"
        let sanitized = validationService.sanitizeInput(input, for: .partyName)
        
        XCTAssertEqual(sanitized, "JohnscriptalertxssscriptDoe")
        XCTAssertFalse(sanitized.contains("<"))
        XCTAssertFalse(sanitized.contains(">"))
    }
    
    func testSanitizeNotes() {
        let input = "This is a note with <script> tag"
        let sanitized = validationService.sanitizeInput(input, for: .notes)
        
        XCTAssertFalse(sanitized.contains("<script"))
        XCTAssertTrue(sanitized.contains("This is a note"))
    }
    
    func testExcessiveLength() {
        let longParty = String(repeating: "a", count: 200)
        let dto = TransactionDTO(
            party: longParty,
            amount: 50.0,
            direction: .lent
        )
        
        let result = validationService.validateTransaction(dto)
        
        switch result {
        case .success:
            XCTFail("Should fail with excessive length")
        case .failure(let error):
            if case .excessiveLength = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
    
    func testInjectionDetection() {
        let maliciousInput = "'; DROP TABLE transactions; --"
        let dto = TransactionDTO(
            party: maliciousInput,
            amount: 50.0,
            direction: .lent
        )
        
        let result = validationService.validateTransaction(dto)
        
        switch result {
        case .success:
            XCTFail("Should detect injection attempt")
        case .failure(let error):
            if case .injectionAttempt = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
}
