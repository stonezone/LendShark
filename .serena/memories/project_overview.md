# LendShark Project Overview

## Purpose
LendShark is a merged iOS loan tracking application that combines the best architectural patterns from LoanShark (enterprise-grade structure) and LendLog_final (practical features). The app tracks lending and borrowing transactions between users with a focus on:
- Clean architecture with strict separation of concerns
- Comprehensive test coverage
- Version management and dependency validation
- Contract-based module communication via DTOs

## Tech Stack
- **Platform**: iOS 17.0+
- **Language**: Swift 6.1
- **UI Framework**: SwiftUI
- **Data Persistence**: Core Data with CloudKit sync
- **Architecture**: Workspace + SPM Package structure
- **Build System**: Xcode 16 with XCConfig files
- **Testing**: Swift Testing framework + XCUITest

## Project Structure
```
LendShark/
├── LendShark.xcworkspace/          # Main workspace file
├── LendShark.xcodeproj/           # App shell project
├── LendShark/                     # Minimal app target
├── LendSharkPackage/              # Primary development area (SPM)
│   ├── Sources/
│   │   └── LendSharkFeature/     # Feature implementation
│   └── Tests/
│       └── LendSharkFeatureTests/ # Unit tests
├── LendSharkUITests/              # UI automation tests
└── Config/                        # Build configuration
    ├── Shared.xcconfig
    ├── Debug.xcconfig
    ├── Release.xcconfig
    └── LendShark.entitlements
```

## Key Architectural Principles
1. **Single Responsibility**: One purpose per module
2. **Stable Contracts**: Immutable DTOs for module I/O
3. **Dependency Injection**: Pass collaborators, avoid hard-wired imports
4. **Stateless Boundaries**: Share only data, not behavior
5. **Semantic Versioning**: Bump version on contract change
6. **Pure Functions First**: Prefer referential transparency
7. **Version Verification**: Validate all technology versions
8. **Dependency Hygiene**: Audit and update dependencies systematically
