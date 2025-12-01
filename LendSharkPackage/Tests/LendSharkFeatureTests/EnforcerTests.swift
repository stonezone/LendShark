import XCTest
import CoreData
@testable import LendSharkFeature

/// Agent Alpha Testing - Verify enforcer features work correctly
final class EnforcerTests: XCTestCase {
    
    var testContext: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        
        // Create in-memory Core Data stack for testing
        let container = NSPersistentContainer(name: "LendShark")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load test store: \(error)")
            }
        }
        
        testContext = container.viewContext
    }
    
    override func tearDown() {
        testContext = nil
        super.tearDown()
    }
    
    // MARK: - Test Overdue Calculations
    
    func testOverdueCalculations() throws {
        // Create test transactions
        let oldTransaction = createTransaction(
            party: "John Smith",
            amount: 500,
            daysAgo: 30 // 23 days overdue (30 - 7 grace period)
        )
        
        let recentTransaction = createTransaction(
            party: "Jane Doe", 
            amount: 200,
            daysAgo: 3 // Not overdue yet
        )
        
        let settledTransaction = createTransaction(
            party: "Bob Johnson",
            amount: 300,
            daysAgo: 20
        )
        settledTransaction.settled = true
        
        try testContext.save()
        
        // Get debtors
        let transactions = [oldTransaction, recentTransaction, settledTransaction]
        let debtors = DebtLedger.getDebtors(from: transactions)
        
        // Verify calculations
        XCTAssertEqual(debtors.count, 2, "Should have 2 active debtors")
        
        let johnDebt = debtors.first { $0.name == "John Smith" }
        XCTAssertNotNil(johnDebt, "John's debt should be found")
        XCTAssertTrue(johnDebt!.isOverdue, "John should be overdue")
        XCTAssertEqual(johnDebt!.daysOverdue, 23, "John should be 23 days overdue")
        XCTAssertEqual(johnDebt!.totalOwed, 500, "John should owe $500")
        
        let janeDebt = debtors.first { $0.name == "Jane Doe" }
        XCTAssertNotNil(janeDebt, "Jane's debt should be found")
        XCTAssertFalse(janeDebt!.isOverdue, "Jane should not be overdue")
        XCTAssertEqual(janeDebt!.daysOverdue, 0, "Jane should have 0 overdue days")
        
        // Bob should not appear (settled)
        let bobDebt = debtors.first { $0.name == "Bob Johnson" }
        XCTAssertNil(bobDebt, "Bob should not appear (settled)")
        
        print("✅ Overdue calculations working correctly")
    }
    
    // MARK: - Test Settlement Functions
    
    func testSettlementRecordings() throws {
        // Create test debtor
        let transaction1 = createTransaction(party: "Test User", amount: 300, daysAgo: 10)
        let transaction2 = createTransaction(party: "Test User", amount: 200, daysAgo: 5)
        try testContext.save()
        
        // Verify initial debt
        let initialTotal = Transaction.totalOwed(by: "Test User", in: testContext)
        XCTAssertEqual(initialTotal, 500, "Initial total should be $500")
        
        // Test partial payment
        try Transaction.recordPartialPayment(
            person: "Test User", 
            amount: 150, 
            in: testContext
        )
        
        let afterPartial = Transaction.totalOwed(by: "Test User", in: testContext)
        XCTAssertEqual(afterPartial, 350, "After $150 payment, should owe $350")
        
        // Test full settlement
        try Transaction.settleAll(with: "Test User", in: testContext)
        
        let afterSettlement = Transaction.totalOwed(by: "Test User", in: testContext)
        XCTAssertEqual(afterSettlement, 0, "After settlement, should owe $0")
        
        print("✅ Settlement recordings working correctly")
    }
    
    // MARK: - Test Data Integrity
    
    func testDataIntegrity() throws {
        // Create various transaction types
        let transactions = [
            createTransaction(party: "Person A", amount: 100, daysAgo: 5),
            createTransaction(party: "Person B", amount: 200, daysAgo: 15),
            createTransaction(party: "Person C", amount: 50, daysAgo: 2)
        ]
        
        try testContext.save()
        
        // Count before operations
        let initialCount = try testContext.count(for: Transaction.fetchRequest())
        
        // Perform settlement operations
        try Transaction.settleAll(with: "Person A", in: testContext)
        try Transaction.recordPartialPayment(person: "Person B", amount: 50, in: testContext)
        try Transaction.markAsDefaulted(person: "Person C", in: testContext)
        
        // Count after operations
        let finalCount = try testContext.count(for: Transaction.fetchRequest())
        
        // Should have added one transaction (partial payment)
        XCTAssertEqual(finalCount, initialCount + 1, "Should have added exactly one transaction for partial payment")
        
        // Verify no data was lost
        let allTransactions = try testContext.fetch(Transaction.fetchRequest())
        XCTAssertTrue(allTransactions.count > 0, "Should have transactions in database")
        
        print("✅ Data integrity maintained during operations")
    }
    
    // MARK: - Test Reminder System
    
    func testReminderSystem() {
        // Test escalation levels
        let friendly = ReminderSystem.EscalationLevel.level(for: 3)
        XCTAssertEqual(friendly, .friendly, "3 days should be friendly level")
        
        let overdue = ReminderSystem.EscalationLevel.level(for: 10)
        XCTAssertEqual(overdue, .overdue, "10 days should be overdue level")
        
        let collections = ReminderSystem.EscalationLevel.level(for: 70)
        XCTAssertEqual(collections, .collections, "70 days should be collections level")
        
        // Test reminder generation
        let reminder = ReminderSystem.generateReminder(
            for: "Test Person",
            amount: 250,
            daysOverdue: 15
        )
        
        XCTAssertEqual(reminder.person, "Test Person")
        XCTAssertEqual(reminder.amount, 250)
        XCTAssertEqual(reminder.daysOverdue, 15)
        XCTAssertEqual(reminder.escalationLevel, .urgent)
        XCTAssertTrue(reminder.message.contains("$250"))
        XCTAssertTrue(reminder.message.contains("Test Person"))
        
        print("✅ Reminder system working correctly")
    }
    
    // MARK: - Helper Functions
    
    private func createTransaction(party: String, amount: Decimal, daysAgo: Int) -> Transaction {
        let transaction = Transaction(context: testContext)
        transaction.id = UUID()
        transaction.party = party
        transaction.amount = NSDecimalNumber(decimal: amount)
        transaction.direction = 1 // Owed to me
        transaction.settled = false
        transaction.isItem = false
        transaction.timestamp = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())
        return transaction
    }
}

/// Quick integration test to verify app doesn't crash
final class IntegrationSmokeTests: XCTestCase {
    
    func testAppComponentsLoad() {
        // Test that key views can be instantiated without crashing
        let _ = LedgerView()
        let _ = CollectionsView()
        let _ = MainTabView()
        
        // Test DTO creation
        let debtorInfo = DebtLedger.DebtorInfo(name: "Test", totalOwed: 100, daysOverdue: 5)
        XCTAssertEqual(debtorInfo.name, "Test")
        XCTAssertEqual(debtorInfo.totalOwed, 100)
        XCTAssertEqual(debtorInfo.daysOverdue, 5)
        XCTAssertTrue(debtorInfo.isOverdue)
        XCTAssertTrue(debtorInfo.owesMe)
        
        print("✅ App components load without crashing")
    }
}