# LendShark Architecture & Implementation Guide

## Project Architecture

### Core Principles (MUST FOLLOW)
1. **Single Responsibility** - One purpose per module
2. **Stable Contracts** - DTOs for module I/O
3. **Dependency Injection** - Pass collaborators via protocols
4. **Stateless Boundaries** - Share only data, not behavior
5. **Semantic Versioning** - Bump version on contract changes
6. **Pure Functions First** - Prefer referential transparency

### Layer Architecture
```
UI Layer (SwiftUI Views)
    ↓ (ViewModels)
Application Layer (Coordinators)
    ↓ (DTOs)
Domain Layer (Services + Protocols)
    ↓ (DTOs)
Infrastructure Layer (Persistence, Network)
```

### Service Contracts
All services MUST:
- Implement a protocol interface
- Use DTOs for input/output
- Be registered in DependencyContainer
- Have <200 lines of code
- Include unit tests

## Implementation Checklist

### Immediate Fixes Required
```swift
// 1. Fix PersistenceController concurrency
@MainActor
final class PersistenceController: @unchecked Sendable {
    static let shared = PersistenceController()
    // Make static preview a computed property
}

// 2. Fix type conversions
transaction.amount = NSDecimalNumber(decimal: dto.amount ?? 0)

// 3. Fix Core Data defaults
// Remove timestamp default or make it optional
```

### UI Implementation Plan

Based on reference app, implement in this order:

1. **Tab Bar Structure**
   - Today (Transactions)
   - Balance (Overview)
   - Budget (Analytics)
   - Reports (Export)
   - More (Settings)

2. **Balance Screen Components**
   - Total balance card
   - Account groupings (Payment/Credit/Assets)
   - Account rows with balances
   - Pull-to-refresh

3. **Transaction Screen**
   - Date-based grouping
   - Swipe actions (settle/delete)
   - Search bar
   - Category filters
   - Amount formatting

4. **Analytics Screen**
   - Pie chart (use Swift Charts)
   - Category breakdown
   - Date range selector
   - Expense vs Income toggle

## Code Generation Rules

### When Creating New Features
1. Start with the protocol
2. Create DTOs for data
3. Implement service (<200 lines)
4. Write tests first (TDD)
5. Update DependencyContainer
6. Document public APIs

### File Organization
```
Feature/
├── Domain/
│   ├── DTOs/
│   └── Protocols/
├── Services/
├── UI/
│   ├── Views/
│   └── ViewModels/
└── Tests/
```

## Testing Strategy
- Unit tests: Each service method
- Integration tests: Service interactions
- UI tests: Critical user flows
- Minimum 80% coverage

## Version Management
- Check all dependency versions
- Update API_VERSIONS.md monthly
- Maintain compatibility matrix
- Document breaking changes

## Performance Targets
- App launch: <1 second
- Transaction add: <100ms
- Export 1000 items: <2 seconds
- Memory usage: <50MB baseline

## Security Requirements
- Input sanitization on all user input
- CloudKit container validation
- No sensitive data in logs
- Secure export file handling

## Remember
- KISS - Keep It Simple, Stupid
- YAGNI - You Aren't Gonna Need It
- DRY - Don't Repeat Yourself
- Test early, test often
- Document as you go