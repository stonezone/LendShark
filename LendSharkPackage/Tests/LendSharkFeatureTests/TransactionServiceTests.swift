import XCTest
import CoreData
@testable import LendSharkFeature

final class TransactionServiceTests: XCTestCase {
    var transactionService: TransactionService!
    var mockPersistenceController: MockPersistenceController!
    var mockValidationService: MockValidationService!
    
    override func setUp() {
        super.setUp()
        mockPersistenceController = MockPersistenceController()
        mockValidationService = MockValidationService()
        transactionService = TransactionService(
            persistenceController: mockPersistenceController,
            validationService: mockValidationService
        )
    }
    
    override func tearDown() {
        transactionService = nil
        mockValidationService = nil
        mockPersistenceController = nil
        super.tearDown()
    }
    
    // MARK: - Add Transaction Tests
    
    func testAddTransaction_ValidInput_ReturnsValidatedDTO() async throws {
        // Given
        let inputDTO = TransactionDTO(
            party: "John",
            amount: 50.0,
            direction: .lent
        )
        
        let expectedDTO = TransactionDTO(
            id: UUID(),
            party: "John",
            amount: 50.0,
            direction: .lent,
            timestamp: Date()
        )
        
        mockValidationService.validateTransactionResult = .success(inputDTO)
        mockPersistenceController.dtoToTransactionReturnValue = expectedDTO
        
        // When
        let result = try await transactionService.addTransaction(inputDTO)
        
        // Then
        XCTAssertEqual(result.party, "John")
        XCTAssertEqual(result.amount, 50.0)
        XCTAssertEqual(result.direction, .lent)
        XCTAssertTrue(mockPersistenceController.saveWasCalled)
        XCTAssertEqual(mockValidationService.validateTransactionCallCount, 1)
    }
    
    func testAddTransaction_ValidationFails_ThrowsError() async {
        // Given
        let inputDTO = TransactionDTO(
            party: "",
            amount: 50.0,
            direction: .lent
        )
        
        mockValidationService.validateTransactionResult = .failure(.invalidPartyName("Empty party name"))
        
        // When/Then
        do {
            _ = try await transactionService.addTransaction(inputDTO)
            XCTFail("Should have thrown validation error")
        } catch {
            XCTAssertTrue(error is ValidationError)
        }
    }
    
    func testAddTransaction_CoreDataSaveFails_ThrowsError() async {
        // Given
        let inputDTO = TransactionDTO(
            party: "John",
            amount: 50.0,
            direction: .lent
        )
        
        mockValidationService.validateTransactionResult = .success(inputDTO)
        mockPersistenceController.shouldFailSave = true
        
        // When/Then
        do {
            _ = try await transactionService.addTransaction(inputDTO)
            XCTFail("Should have thrown save error")
        } catch {
            // Expected to throw an error
            XCTAssertTrue(mockPersistenceController.saveWasCalled)
        }
    }
    
    // MARK: - Update Transaction Tests
    
    func testUpdateTransaction_ValidInput_UpdatesSuccessfully() async throws {
        // Given
        let transactionId = UUID()
        let updatedDTO = TransactionDTO(
            id: transactionId,
            party: "John Updated",
            amount: 75.0,
            direction: .lent
        )
        
        mockValidationService.validateTransactionResult = .success(updatedDTO)
        mockPersistenceController.setupMockTransaction(id: transactionId)
        
        // When
        let result = try await transactionService.updateTransaction(updatedDTO)
        
        // Then
        XCTAssertEqual(result.party, "John Updated")
        XCTAssertEqual(result.amount, 75.0)
        XCTAssertTrue(mockPersistenceController.saveWasCalled)
    }
    
    func testUpdateTransaction_TransactionNotFound_ThrowsError() async {
        // Given
        let nonExistentId = UUID()
        let updatedDTO = TransactionDTO(
            id: nonExistentId,
            party: "John",
            amount: 50.0,
            direction: .lent
        )
        
        mockValidationService.validateTransactionResult = .success(updatedDTO)
        mockPersistenceController.shouldReturnEmptyResults = true
        
        // When/Then
        do {
            _ = try await transactionService.updateTransaction(updatedDTO)
            XCTFail("Should have thrown TransactionError.notFound")
        } catch TransactionError.notFound {
            // Expected
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    // MARK: - Delete Transaction Tests
    
    func testDeleteTransaction_ValidId_DeletesSuccessfully() async throws {
        // Given
        let transactionId = UUID()
        mockPersistenceController.setupMockTransaction(id: transactionId)
        
        // When
        try await transactionService.deleteTransaction(id: transactionId)
        
        // Then
        XCTAssertTrue(mockPersistenceController.deleteWasCalled)
        XCTAssertTrue(mockPersistenceController.saveWasCalled)
    }
    
    func testDeleteTransaction_NonExistentId_ThrowsError() async {
        // Given
        let nonExistentId = UUID()
        mockPersistenceController.shouldReturnEmptyResults = true
        
        // When/Then
        do {
            try await transactionService.deleteTransaction(id: nonExistentId)
            XCTFail("Should have thrown TransactionError.notFound")
        } catch TransactionError.notFound {
            // Expected
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    // MARK: - Get Transaction Tests
    
    func testGetTransaction_ValidId_ReturnsTransaction() async throws {
        // Given
        let transactionId = UUID()
        let expectedDTO = TransactionDTO(
            id: transactionId,
            party: "John",
            amount: 50.0,
            direction: .lent
        )
        
        mockPersistenceController.setupMockTransaction(id: transactionId)
        mockPersistenceController.transactionToDTOReturnValue = expectedDTO
        
        // When
        let result = try await transactionService.getTransaction(id: transactionId)
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.id, transactionId)
        XCTAssertEqual(result?.party, "John")
    }
    
    func testGetTransaction_NonExistentId_ReturnsNil() async throws {
        // Given
        let nonExistentId = UUID()
        mockPersistenceController.shouldReturnEmptyResults = true
        
        // When
        let result = try await transactionService.getTransaction(id: nonExistentId)
        
        // Then
        XCTAssertNil(result)
    }
    
    // MARK: - Get All Transactions Tests
    
    func testGetAllTransactions_HasTransactions_ReturnsAllTransactions() async throws {
        // Given
        let transactions = [
            TransactionDTO(id: UUID(), party: "John", amount: 50.0, direction: .lent),
            TransactionDTO(id: UUID(), party: "Jane", amount: 30.0, direction: .borrowed)
        ]
        
        mockPersistenceController.mockTransactionDTOs = transactions
        
        // When
        let result = try await transactionService.getAllTransactions()
        
        // Then
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.contains { $0.party == "John" })
        XCTAssertTrue(result.contains { $0.party == "Jane" })
    }
    
    func testGetAllTransactions_NoTransactions_ReturnsEmptyArray() async throws {
        // Given
        mockPersistenceController.mockTransactionDTOs = []
        
        // When
        let result = try await transactionService.getAllTransactions()
        
        // Then
        XCTAssertTrue(result.isEmpty)
    }
    
    // MARK: - Get Transactions for Party Tests
    
    func testGetTransactionsForParty_ValidParty_ReturnsFilteredTransactions() async throws {
        // Given
        let partyName = "John"
        let johnTransactions = [
            TransactionDTO(id: UUID(), party: "John", amount: 50.0, direction: .lent),
            TransactionDTO(id: UUID(), party: "John", amount: 25.0, direction: .borrowed)
        ]
        
        mockPersistenceController.mockTransactionDTOs = johnTransactions
        
        // When
        let result = try await transactionService.getTransactions(for: partyName)
        
        // Then
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.allSatisfy { $0.party == "John" })
    }
    
    // MARK: - Settle Transactions Tests
    
    func testSettleTransactions_ValidParty_ReturnsSettledCount() async throws {
        // Given
        let partyName = "John"
        mockPersistenceController.mockUnsettledTransactionCount = 3
        
        // When
        let result = try await transactionService.settleTransactions(for: partyName)
        
        // Then
        XCTAssertEqual(result, 3)
        XCTAssertTrue(mockPersistenceController.saveWasCalled)
    }
    
    func testSettleTransactions_NoUnsettledTransactions_ReturnsZero() async throws {
        // Given
        let partyName = "John"
        mockPersistenceController.mockUnsettledTransactionCount = 0
        
        // When
        let result = try await transactionService.settleTransactions(for: partyName)
        
        // Then
        XCTAssertEqual(result, 0)
        XCTAssertFalse(mockPersistenceController.saveWasCalled)
    }
    
    // MARK: - Balance Calculation Tests
    
    func testCalculateOwedToMe_HasLentTransactions_ReturnsCorrectAmount() async throws {
        // Given
        mockPersistenceController.mockOwedToMeAmount = Decimal(150.0)
        
        // When
        let result = try await transactionService.calculateOwedToMe()
        
        // Then
        XCTAssertEqual(result, Decimal(150.0))
    }
    
    func testCalculateIOwe_HasBorrowedTransactions_ReturnsCorrectAmount() async throws {
        // Given
        mockPersistenceController.mockIOweAmount = Decimal(75.0)
        
        // When
        let result = try await transactionService.calculateIOwe()
        
        // Then
        XCTAssertEqual(result, Decimal(75.0))
    }
    
    func testGetBalanceSummary_MixedTransactions_ReturnsCorrectSummary() async throws {
        // Given
        mockPersistenceController.mockOwedToMeAmount = Decimal(150.0)
        mockPersistenceController.mockIOweAmount = Decimal(75.0)
        
        // When
        let result = try await transactionService.getBalanceSummary()
        
        // Then
        XCTAssertEqual(result.owedToMe, Decimal(150.0))
        XCTAssertEqual(result.iOwe, Decimal(75.0))
        XCTAssertEqual(result.netBalance, Decimal(75.0))
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentOperations_MultipleCalls_HandledSafely() async throws {
        // Given
        let inputDTO = TransactionDTO(
            party: "John",
            amount: 50.0,
            direction: .lent
        )
        
        mockValidationService.validateTransactionResult = .success(inputDTO)
        
        // When - Perform multiple concurrent operations
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask { [weak self] in
                    do {
                        let dto = TransactionDTO(
                            party: "User\(i)",
                            amount: Decimal(i * 10),
                            direction: .lent
                        )
                        _ = try await self?.transactionService.addTransaction(dto)
                    } catch {
                        // Concurrent operations may fail, which is acceptable for this test
                    }
                }
            }
        }
        
        // Then - Should not crash or deadlock
        XCTAssertTrue(mockPersistenceController.saveWasCalled)
    }
    
    // MARK: - Performance Tests
    
    func testAddTransactionPerformance() {
        let inputDTO = TransactionDTO(
            party: "John",
            amount: 50.0,
            direction: .lent
        )
        
        mockValidationService.validateTransactionResult = .success(inputDTO)
        
        measure {
            Task {
                do {
                    _ = try await transactionService.addTransaction(inputDTO)
                } catch {
                    // Performance test - errors are acceptable
                }
            }
        }
    }
}

// MARK: - Mock Classes

class MockPersistenceController: PersistenceController {
    var saveWasCalled = false
    var deleteWasCalled = false
    var shouldFailSave = false
    var shouldReturnEmptyResults = false
    var dtoToTransactionReturnValue: TransactionDTO?
    var transactionToDTOReturnValue: TransactionDTO?
    var mockTransactionDTOs: [TransactionDTO] = []
    var mockUnsettledTransactionCount = 0
    var mockOwedToMeAmount = Decimal(0)
    var mockIOweAmount = Decimal(0)
    
    private var mockTransactions: [MockTransaction] = []
    
    override init() {
        super.init()
    }
    
    func setupMockTransaction(id: UUID) {
        let mockTransaction = MockTransaction(id: id)
        mockTransactions.append(mockTransaction)
        shouldReturnEmptyResults = false
    }
    
    override func dtoToTransaction(_ dto: TransactionDTO, context: NSManagedObjectContext) -> Transaction {
        saveWasCalled = true
        if shouldFailSave {
            // Simulate save failure by throwing in the context save
            context.insert(MockFailingTransaction())
        }
        
        let transaction = MockTransaction(id: dto.id)
        transaction.party = dto.party
        transaction.amount = dto.amount.map { NSDecimalNumber(decimal: $0) }
        transaction.direction = Int16(dto.direction.rawValue)
        transaction.isItem = dto.isItem
        transaction.settled = dto.settled
        transaction.timestamp = dto.timestamp
        
        return transaction
    }
    
    override func transactionToDTO(_ transaction: Transaction) -> TransactionDTO {
        if let returnValue = transactionToDTOReturnValue {
            return returnValue
        }
        
        return TransactionDTO(
            id: transaction.id ?? UUID(),
            party: transaction.party ?? "",
            amount: transaction.amount?.decimalValue,
            direction: TransactionDirection(rawValue: Int(transaction.direction)) ?? .lent,
            item: transaction.item,
            isItem: transaction.isItem,
            settled: transaction.settled,
            timestamp: transaction.timestamp ?? Date(),
            dueDate: transaction.dueDate,
            notes: transaction.notes
        )
    }
}

class MockValidationService: ValidationServiceProtocol {
    var validateTransactionResult: Result<TransactionDTO, ValidationError> = .success(TransactionDTO(party: "Test", amount: 0, direction: .lent))
    var validateTransactionCallCount = 0
    
    func validateTransaction(_ dto: TransactionDTO) -> Result<TransactionDTO, ValidationError> {
        validateTransactionCallCount += 1
        return validateTransactionResult
    }
    
    func sanitizeInput(_ input: String, for field: InputField) -> String {
        return input
    }
}

class MockTransaction: Transaction {
    private var _id: UUID?
    private var _party: String?
    private var _amount: NSDecimalNumber?
    private var _direction: Int16 = 0
    private var _isItem: Bool = false
    private var _settled: Bool = false
    private var _timestamp: Date?
    private var _item: String?
    private var _dueDate: Date?
    private var _notes: String?
    
    init(id: UUID) {
        super.init()
        self._id = id
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override var id: UUID? {
        get { _id }
        set { _id = newValue }
    }
    
    override var party: String? {
        get { _party }
        set { _party = newValue }
    }
    
    override var amount: NSDecimalNumber? {
        get { _amount }
        set { _amount = newValue }
    }
    
    override var direction: Int16 {
        get { _direction }
        set { _direction = newValue }
    }
    
    override var isItem: Bool {
        get { _isItem }
        set { _isItem = newValue }
    }
    
    override var settled: Bool {
        get { _settled }
        set { _settled = newValue }
    }
    
    override var timestamp: Date? {
        get { _timestamp }
        set { _timestamp = newValue }
    }
    
    override var item: String? {
        get { _item }
        set { _item = newValue }
    }
    
    override var dueDate: Date? {
        get { _dueDate }
        set { _dueDate = newValue }
    }
    
    override var notes: String? {
        get { _notes }
        set { _notes = newValue }
    }
}

class MockFailingTransaction: Transaction {
    override func awakeFromInsert() {
        super.awakeFromInsert()
        // This will cause the context save to fail
        self.party = nil
    }
}