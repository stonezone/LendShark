import CoreData
import XCTest
@testable import LendSharkFeature

@MainActor
final class PersistenceControllerTests: XCTestCase {
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

    func testInMemoryStack_CanInsertFetchAndConvertToDTO() throws {
        let transaction = Transaction(context: context)
        transaction.id = UUID()
        transaction.party = "Sam"
        transaction.amount = NSDecimalNumber(decimal: 123.45)
        transaction.direction = 1
        transaction.settled = false
        transaction.isItem = false
        transaction.timestamp = Date()
        transaction.dueDate = Calendar.current.date(byAdding: .day, value: 14, to: Date())
        transaction.interestRate = NSDecimalNumber(decimal: 0.10)
        transaction.notes = "has my watch"
        transaction.phoneNumber = "(555) 123-4567"

        try context.save()

        let fetched = try context.fetch(Transaction.fetchRequest())
        XCTAssertEqual(fetched.count, 1)

        let dto = persistenceController.transactionToDTO(fetched[0])
        XCTAssertEqual(dto.party, "Sam")
        XCTAssertEqual(dto.amount, Decimal(string: "123.45"))
        XCTAssertEqual(dto.direction, .lent)
        XCTAssertEqual(dto.interestRate, Decimal(string: "0.10"))
        XCTAssertEqual(dto.phoneNumber, "(555) 123-4567")
        XCTAssertEqual(dto.notes, "has my watch")
    }
}
