# Dependencies

## System Frameworks (Apple)

### Core
- **SwiftUI** — UI, state, and settings (`@AppStorage`)
- **Foundation** — base types, dates, formatting
- **CoreData** — local persistence for transactions

### Feature-Specific (platform-conditional)
- **Combine** — `ObservableObject` / publish semantics used by settings
- **UserNotifications** — notification permission + scheduling (iOS app behavior; no-op in macOS SwiftPM tests)
- **LocalAuthentication** — Face ID / Touch ID gating
- **UniformTypeIdentifiers** — export file type identifiers
- **UIKit + CoreText** — PDF generation path (compiled only when `canImport(UIKit)`)
- **Contacts + ContactsUI** — contact picker/autocomplete (iOS-only UI)
- **MessageUI** — SMS compose sheet (iOS-only)
- **os** — structured logging

## Platform Targets (from repo config)
- **App target**: iOS deployment target `26.0` (`Config/Shared.xcconfig`)
- **SwiftPM package**: `.iOS(.v26)`, `.macOS(.v26)` (`LendSharkPackage/Package.swift`)

## Third-Party Dependencies
**None** — no CocoaPods/Carthage and no external SwiftPM packages.

## Build & Test Tooling
- **Workspace**: open `LendShark.xcworkspace` (app shell + feature package)
- **SwiftPM**: run tests via `cd LendSharkPackage && swift test`

## Optional / Not Implemented
- **iCloud/CloudKit sync**: not implemented (setting exists but defaults off)
- **Analytics / crash reporting**: no third-party SDKs (toggles are placeholders and default off)
