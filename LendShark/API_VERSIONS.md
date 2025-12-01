# API Versions

## External APIs

### CloudKit
- **Version:** iOS 16.0+ SDK
- **Framework:** CloudKit.framework
- **Usage:** Transaction sync across devices
- **Status:** Basic implementation added

### Core Data
- **Version:** iOS 16.0+ SDK  
- **Framework:** CoreData.framework
- **Usage:** Local data persistence
- **Model Version:** LendShark.xcdatamodel v1.0

## Swift Package Dependencies
- None (all functionality built-in)

## System Requirements
- **iOS:** 16.0 or later
- **macOS:** 13.0 or later (for testing)
- **Xcode:** 15.0 or later
- **Swift:** 5.9

## API Endpoints
No external REST APIs used - app is fully offline-capable with optional CloudKit sync.

## Version History
- **1.0.0** - Initial release with Core Data and CloudKit sync
