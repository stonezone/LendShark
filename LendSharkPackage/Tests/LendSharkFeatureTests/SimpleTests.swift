import CoreData
import XCTest
@testable import LendSharkFeature

@MainActor
final class DebtLedgerTests: XCTestCase {
    private var persistenceController: PersistenceController!
    private var context: NSManagedObjectContext!

    override func setUp() async throws {
        try await super.setUp()
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext

        let deadline = Date().addingTimeInterval(2.0)
        while !persistenceController.isDataStoreReady && Date() < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertTrue(persistenceController.isDataStoreReady, "Data store should be ready for tests")
    }

    override func tearDown() async throws {
        context = nil
        persistenceController = nil
        try await super.tearDown()
    }

    func testGetDebtors_AccumulatesPrincipalAndItems() throws {
        // John owes me $100, paid $20 back; oldest transaction is 10 days ago so 3 days overdue by grace rule.
        let old = Calendar.current.date(byAdding: .day, value: -10, to: Date())!

        let johnDebt = Transaction(context: context)
        johnDebt.party = "John"
        johnDebt.amount = NSDecimalNumber(decimal: 100)
        johnDebt.direction = 1
        johnDebt.settled = false
        johnDebt.isItem = false
        johnDebt.timestamp = old

        let johnPayment = Transaction(context: context)
        johnPayment.party = "John"
        johnPayment.amount = NSDecimalNumber(decimal: 20)
        johnPayment.direction = -1
        johnPayment.settled = false
        johnPayment.isItem = false
        johnPayment.timestamp = Date()

        // Jane has my drill, due yesterday.
        let janeItem = Transaction(context: context)
        janeItem.party = "Jane"
        janeItem.amount = NSDecimalNumber(decimal: 0)
        janeItem.direction = 1
        janeItem.settled = false
        janeItem.isItem = true
        janeItem.timestamp = Date()
        janeItem.dueDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        janeItem.notes = "drill"

        try context.save()

        let allTransactions = try context.fetch(Transaction.fetchRequest())
        let debtors = DebtLedger.getDebtors(from: allTransactions)

        let john = debtors.first { $0.name == "John" }
        XCTAssertNotNil(john)
        XCTAssertEqual(john?.principal, 80)
        XCTAssertEqual(john?.accruedInterest ?? 0, 0)
        XCTAssertEqual(john?.daysOverdue, 3)
        XCTAssertTrue(john?.owesMe ?? false)

        let jane = debtors.first { $0.name == "Jane" }
        XCTAssertNotNil(jane)
        XCTAssertEqual(jane?.principal, 0)
        XCTAssertTrue(jane?.hasItems ?? false)
        XCTAssertTrue(jane?.isOverdue ?? false)
        XCTAssertEqual(jane?.items.first?.name, "drill")
    }
}
