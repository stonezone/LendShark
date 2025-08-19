# Swift Code Style and Conventions for LendShark

## Naming Conventions
- **Types**: PascalCase (e.g., `TransactionDTO`, `ExportService`)
- **Properties/Methods**: camelCase (e.g., `calculateBalance`, `isSettled`)
- **Constants**: PascalCase for types, camelCase for instances
- **Protocols**: Suffix with `Protocol` or describe capability (e.g., `Exportable`)
- **Generic Parameters**: Single letter or descriptive (e.g., `T`, `Element`)

## Type System
- **Always use explicit types** for public APIs
- **Use type inference** for local variables when obvious
- **Prefer structs** over classes unless reference semantics needed
- **Mark classes as `final`** unless designed for inheritance

## Access Control
```swift
// Public API - exposed to app target
public struct TransactionDTO {
    public let id: UUID
    public let amount: Decimal
    public init(id: UUID, amount: Decimal) { ... }
}

// Internal - package visibility
internal final class DataService { ... }

// Private - file/type scope
private var cache: [String: Any] = [:]
```

## Documentation
```swift
/// Brief description of the type/method
/// 
/// - Parameters:
///   - parameter1: Description
///   - parameter2: Description
/// - Returns: Description of return value
/// - Throws: Description of errors thrown
public func processTransaction(_ transaction: TransactionDTO) throws -> ProcessingResult {
    // Implementation
}
```

## Error Handling
```swift
// Define specific error types
enum TransactionError: LocalizedError {
    case invalidAmount(Decimal)
    case missingParty
    case syncFailed(underlying: Error)
    
    var errorDescription: String? { ... }
}

// Use Result type for async operations
func exportTransactions() async -> Result<URL, ExportError> { ... }
```

## Async/Await (Swift 6+ Concurrency)
```swift
// Prefer async/await over completion handlers
@MainActor
func loadTransactions() async throws -> [TransactionDTO] {
    // Implementation
}

// Use TaskGroup for concurrent operations
await withTaskGroup(of: ValidationResult.self) { group in
    for transaction in transactions {
        group.addTask { await validate(transaction) }
    }
}
```

## SwiftUI Best Practices
```swift
// Use @Observable for view models (iOS 17+)
@Observable
final class TransactionViewModel {
    var transactions: [TransactionDTO] = []
    var isLoading = false
}

// Prefer computed properties over complex view bodies
private var transactionList: some View {
    List(transactions) { transaction in
        TransactionRow(transaction: transaction)
    }
}
```

## Testing Conventions
```swift
// Use Swift Testing framework (not XCTest)
@Test("Transaction parsing handles valid input")
func testValidParsing() async throws {
    let input = "lent $20 to john"
    let result = try Parser.parse(input)
    #expect(result.amount == 20)
    #expect(result.party == "john")
}

// Group related tests
@Suite("Export Service Tests")
struct ExportServiceTests { ... }
```

## DTO/Contract Pattern
```swift
// Immutable DTO for module boundaries
public struct TransactionDTO: Codable, Equatable, Sendable {
    public let id: UUID
    public let party: String
    public let amount: Decimal
    public let direction: TransactionDirection
    public let timestamp: Date
    
    // No behavior, only data
}

// Service accepts/returns DTOs only
public protocol TransactionServiceProtocol {
    func add(_ transaction: TransactionDTO) async throws
    func fetch() async throws -> [TransactionDTO]
}
```

## Dependency Injection
```swift
// Protocol for dependencies
protocol DataStoreProtocol {
    func save<T: Codable>(_ object: T) async throws
}

// Inject via initializer
final class TransactionService {
    private let dataStore: DataStoreProtocol
    
    init(dataStore: DataStoreProtocol) {
        self.dataStore = dataStore
    }
}
```

## Code Organization
- Group related functionality in extensions
- One type per file (exceptions for small related types)
- Organize by feature, not by type
- Keep files under 300 lines

## Performance Considerations
- Use `@Observable` instead of `@Published` for better performance
- Prefer value types (structs) to reduce heap allocations
- Use `lazy` for expensive computations
- Profile before optimizing
