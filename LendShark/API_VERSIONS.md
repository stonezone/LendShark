# API Versions

## External APIs
No external REST APIs are used. LendShark is offline-first.

## System Framework APIs (Used)

### Core Data
- **Usage:** Local persistence for `Transaction` records
- **Model:** `LendSharkPackage/Sources/LendSharkFeature/Core/Infrastructure/LendShark.xcdatamodeld`
- **SwiftPM note:** SwiftPM copies `.xcdatamodeld` as a resource; the package includes a programmatic model fallback for SwiftPM/macOS test builds.

### UserNotifications
- **Usage:** Local reminder scheduling via `SettingsService`
- **Platform:** iOS-only behavior (no-op on non-iOS SwiftPM test contexts)

### Contacts / ContactsUI (iOS only)
- **Usage:** Quick Add name/phone autocomplete

### MessageUI (iOS only)
- **Usage:** Native SMS composer (`SMSComposerView`)

## Swift Package Dependencies
- None (all functionality is built-in / system frameworks only)

## Targets / Tooling (Repo-configured)
- **Swift tools version:** 6.2 (`LendSharkPackage/Package.swift`)
- **Deployment target (app):** iOS 26.0 (`Config/Shared.xcconfig`)
- **SPM platforms:** iOS v26, macOS v26 (`LendSharkPackage/Package.swift`)

## Version History
- **1.0.0** - Initial release (Core Data-based ledger)
