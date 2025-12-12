import CoreData
import XCTest
@testable import LendSharkFeature

@MainActor
final class TransactionModelTests: XCTestCase {
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

    func testTotalOwed_CaseInsensitiveAndTrimmed() throws {
        let t1 = Transaction(context: context)
        t1.party = "John"
        t1.amount = NSDecimalNumber(decimal: 100)
        t1.direction = 1
        t1.settled = false
        t1.isItem = false
        t1.timestamp = Date()

        let t2 = Transaction(context: context)
        t2.party = "john"
        t2.amount = NSDecimalNumber(decimal: 20)
        t2.direction = -1
        t2.settled = false
        t2.isItem = false
        t2.timestamp = Date()

        try context.save()

        let total = Transaction.totalOwed(by: "  JOHN  ", in: context)
        XCTAssertEqual(total, 80)
    }

    func testSettleAll_CaseInsensitiveAndTrimmed() throws {
        let t = Transaction(context: context)
        t.party = "John Smith"
        t.amount = NSDecimalNumber(decimal: 50)
        t.direction = 1
        t.settled = false
        t.isItem = false
        t.timestamp = Date()
        try context.save()

        try Transaction.settleAll(with: " john smith ", in: context)

        let request: NSFetchRequest<Transaction> = Transaction.fetchRequest()
        request.predicate = NSPredicate(format: "party ==[c] %@ AND settled == false", "john smith")
        let remaining = try context.fetch(request)
        XCTAssertTrue(remaining.isEmpty)
    }

    func testRecordPartialPayment_CreatesCounterTransaction() throws {
        let before = try context.fetch(Transaction.fetchRequest()).count

        try Transaction.recordPartialPayment(person: "Alex", amount: 25, in: context)

        let after = try context.fetch(Transaction.fetchRequest()).count
        XCTAssertEqual(after, before + 1)

        let request: NSFetchRequest<Transaction> = Transaction.fetchRequest()
        request.predicate = NSPredicate(format: "party ==[c] %@", "alex")
        let matches = try context.fetch(request)
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches.first?.direction, -1)
        XCTAssertEqual(matches.first?.notes, "Partial payment")
        XCTAssertEqual(matches.first?.amount?.decimalValue, 25)
        XCTAssertEqual(matches.first?.settled, false)
    }

    func testMarkAsDefaulted_SettlesOnlyDirectionLent() throws {
        let debt = Transaction(context: context)
        debt.party = "Bob"
        debt.amount = NSDecimalNumber(decimal: 100)
        debt.direction = 1
        debt.settled = false
        debt.isItem = false
        debt.timestamp = Date()

        let payment = Transaction(context: context)
        payment.party = "Bob"
        payment.amount = NSDecimalNumber(decimal: 20)
        payment.direction = -1
        payment.settled = false
        payment.isItem = false
        payment.timestamp = Date()

        try context.save()

        try Transaction.markAsDefaulted(person: " bob ", in: context)

        let request: NSFetchRequest<Transaction> = Transaction.fetchRequest()
        request.predicate = NSPredicate(format: "party ==[c] %@", "bob")
        let all = try context.fetch(request)

        let lent = all.filter { $0.direction == 1 }
        XCTAssertFalse(lent.isEmpty)
        XCTAssertTrue(lent.allSatisfy { $0.settled })

        let nonLent = all.filter { $0.direction != 1 }
        XCTAssertFalse(nonLent.isEmpty)
        XCTAssertTrue(nonLent.contains { !$0.settled })
    }
}
