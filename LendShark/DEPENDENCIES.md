# Dependencies

## System Frameworks

### Required Frameworks
- **SwiftUI** - UI framework
- **CoreData** - Local data persistence  
- **CloudKit** - iCloud sync (optional)
- **Foundation** - Base functionality
- **Combine** - Reactive programming (via @Published)
- **UniformTypeIdentifiers** - File export types
- **CoreText** - PDF generation

### Platform Dependencies
- iOS 16.0+ SDK
- macOS 13.0+ SDK (for testing)

## Third-Party Dependencies
**None** - LendShark uses no external packages or CocoaPods/Carthage dependencies.

## Build Tools
- Xcode 15.0+
- Swift 5.9+
- Swift Package Manager (built-in)

## Project Structure Dependencies

### Internal Modules
- **LendSharkFeature** - Main feature module (Swift Package)
  - Contains all business logic, UI, and services
  - Self-contained with no external dependencies

### Asset Dependencies
- App icons (included in Assets.xcassets)
- No external image or font dependencies

## Development Dependencies

### Testing
- XCTest framework (built-in)
- No third-party testing libraries

### CI/CD
- No specific CI/CD dependencies
- Can be built with standard Xcode command line tools

## Runtime Dependencies

### Optional Services
- **iCloud Account** - Required only for CloudKit sync
- **Network Connection** - Required only for sync operations
- App runs fully offline without these

## Security & Privacy
- No analytics SDKs
- No crash reporting services
- No advertising frameworks
- No tracking libraries

## Update Policy
All dependencies are Apple system frameworks that update with iOS/macOS releases. No manual dependency updates required.
