import XCTest
@testable import LendSharkFeature

/// Basic integration tests that work with the current architecture
/// Focus on testing public interfaces without complex mocking
@MainActor
final class BasicServiceTests: XCTestCase {
    
    var persistenceController: PersistenceController!
    var transactionService: TransactionService!
    var validationService: ValidationService!
    var parserService: ParserService!
    
    override func setUp() {
        super.setUp()
        
        // Use in-memory Core Data for testing
        persistenceController = PersistenceController(inMemory: true)
        validationService = ValidationService()
        parserService = ParserService(validationService: validationService)
        transactionService = TransactionService(
            persistenceController: persistenceController,
            validationService: validationService
        )
        
        // Wait for data store to be ready synchronously
        let timeout = 5.0
        let startTime = CFAbsoluteTimeGetCurrent()
        while !persistenceController.isDataStoreReady && CFAbsoluteTimeGetCurrent() - startTime < timeout {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        }
        
        XCTAssertTrue(persistenceController.isDataStoreReady, "Data store should be ready for testing")
    }
    
    override func tearDown() {
        persistenceController = nil
        transactionService = nil
        validationService = nil
        parserService = nil
        super.tearDown()
    }
    
    // MARK: - ValidationService Tests
    
    func testValidationService_ValidTransaction_Succeeds() {
        let dto = TransactionDTO(party: "John Doe", amount: 50.0, direction: .lent)
        let result = validationService.validateTransaction(dto)
        
        switch result {
        case .success(let validatedDTO):
            XCTAssertEqual(validatedDTO.party, "John Doe")
            XCTAssertEqual(validatedDTO.amount, 50.0)
            XCTAssertEqual(validatedDTO.direction, .lent)
        case .failure(let error):
            XCTFail("Validation should succeed but failed with: \(error)")
        }
    }
    
    func testValidationService_EmptyPartyName_Fails() {
        let dto = TransactionDTO(party: "", amount: 50.0, direction: .lent)
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
        let dto = TransactionDTO(party: "John Doe", amount: -50.0, direction: .lent)
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
    
    // MARK: - TransactionService Integration Tests
    
    func testTransactionService_AddTransaction_Succeeds() async throws {
        let dto = TransactionDTO(party: "John Doe", amount: Decimal(100), direction: .lent)
        
        let result = try await transactionService.addTransaction(dto)
        
        XCTAssertEqual(result.party, "John Doe")
        XCTAssertEqual(result.amount, Decimal(100))
        XCTAssertEqual(result.direction, .lent)
        XCTAssertNotNil(result.timestamp)
    }
    
    func testTransactionService_GetAllTransactions_ReturnsTransactions() async throws {
        // Add some test transactions
        let dto1 = TransactionDTO(party: "Alice", amount: Decimal(50), direction: .lent)
        let dto2 = TransactionDTO(party: "Bob", amount: Decimal(75), direction: .borrowed)
        
        _ = try await transactionService.addTransaction(dto1)
        _ = try await transactionService.addTransaction(dto2)
        
        let transactions = try await transactionService.getAllTransactions()
        
        XCTAssertGreaterThanOrEqual(transactions.count, 2)
        XCTAssertTrue(transactions.contains { $0.party == "Alice" && $0.amount == Decimal(50) })
        XCTAssertTrue(transactions.contains { $0.party == "Bob" && $0.amount == Decimal(75) })
    }
    
    func testTransactionService_BalanceCalculation_Correct() async throws {
        // Add test transactions
        let lentDTO = TransactionDTO(party: "Alice", amount: Decimal(100), direction: .lent)
        let borrowedDTO = TransactionDTO(party: "Bob", amount: Decimal(50), direction: .borrowed)
        
        _ = try await transactionService.addTransaction(lentDTO)
        _ = try await transactionService.addTransaction(borrowedDTO)
        
        let owedToMe = try await transactionService.calculateOwedToMe()
        let iOwe = try await transactionService.calculateIOwe()
        
        XCTAssertGreaterThanOrEqual(owedToMe, Decimal(100))
        XCTAssertGreaterThanOrEqual(iOwe, Decimal(50))
    }
    
    func testTransactionService_UpdateTransaction_Succeeds() async throws {
        // Add a transaction first
        let originalDTO = TransactionDTO(party: "Charlie", amount: Decimal(200), direction: .lent)
        let addedTransaction = try await transactionService.addTransaction(originalDTO)
        
        // Create updated DTO (TransactionDTO is immutable, so create new one)
        let updatedDTO = TransactionDTO(
            id: addedTransaction.id,
            party: addedTransaction.party,
            amount: Decimal(250),
            item: "Updated item",
            direction: addedTransaction.direction,
            isItem: addedTransaction.isItem,
            settled: addedTransaction.settled,
            timestamp: addedTransaction.timestamp,
            dueDate: addedTransaction.dueDate,
            notes: addedTransaction.notes,
            cloudKitRecordID: addedTransaction.cloudKitRecordID
        )
        
        let result = try await transactionService.updateTransaction(updatedDTO)
        
        XCTAssertEqual(result.id, addedTransaction.id)
        XCTAssertEqual(result.amount, Decimal(250))
        XCTAssertEqual(result.item, "Updated item")
        XCTAssertEqual(result.party, "Charlie")
    }
    
    func testTransactionService_DeleteTransaction_Succeeds() async throws {
        // Add a transaction first
        let dto = TransactionDTO(party: "Dave", amount: Decimal(150), direction: .borrowed)
        let addedTransaction = try await transactionService.addTransaction(dto)
        
        // Delete it
        try await transactionService.deleteTransaction(id: addedTransaction.id)
        
        // Verify it's gone
        do {
            _ = try await transactionService.getTransaction(id: addedTransaction.id)
            XCTFail("Should not find deleted transaction")
        } catch TransactionError.notFound {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Performance Tests
    
    func testTransactionService_AddManyTransactions_Performance() async throws {
        let transactionCount = 10 // Reduced for test performance
        
        measure {
            Task {
                for i in 1...transactionCount {
                    let dto = TransactionDTO(party: "Person \(i)", amount: Decimal(exactly: i), direction: .lent)
                    _ = try await transactionService.addTransaction(dto)
                }
            }
        }
    }
    
    func testParserService_ParseManyInputs_Performance() {
        let inputs = [
            "lent $50 to John",
            "borrowed $25 from Jane", 
            "owe $100 to Bob for dinner",
            "lent 75 to Alice for groceries",
            "borrowed 200 from Charlie"
        ]
        
        measure {
            for input in inputs {
                for _ in 1...20 { // Parse each 20 times
                    _ = parserService.parse(input)
                }
            }
        }
    }
}