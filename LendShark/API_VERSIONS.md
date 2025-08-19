# API Versions

## Current API Versions

| API/Framework | Version | Status | Last Verified |
|--------------|---------|--------|---------------|
| iOS SDK | 16.0+ | ✅ Stable | 2025-01-01 |
| Swift | 6.0 | ✅ Stable | 2025-01-01 |
| CloudKit | Framework | ✅ Stable | 2025-01-01 |
| Core Data | Framework | ✅ Stable | 2025-01-01 |
| SwiftUI | Framework | ✅ Stable | 2025-01-01 |

## DTO Contract Versions

| Contract | Version | Breaking Changes | Migration Required |
|----------|---------|-----------------|-------------------|
| TransactionDTO | 1.0.0 | - | No |
| BalanceDTO | 1.0.0 | - | No |
| ExportResultDTO | 1.0.0 | - | No |

## Service Protocol Versions

| Protocol | Version | Compatibility |
|----------|---------|--------------|
| TransactionServiceProtocol | 1.0.0 | All versions |
| ExportServiceProtocol | 1.0.0 | All versions |
| SyncServiceProtocol | 1.0.0 | All versions |
| ValidationServiceProtocol | 1.0.0 | All versions |
| ParserServiceProtocol | 1.0.0 | All versions |

## Compatibility Matrix

### iOS Versions
- **Minimum**: iOS 16.0
- **Recommended**: iOS 17.0+
- **Maximum Tested**: iOS 18.0

### Swift Versions
- **Minimum**: Swift 5.9
- **Current**: Swift 6.0
- **Maximum**: Swift 6.1

## Migration Guidelines

### From Version 0.x to 1.0
No migration required - initial release

### Future Migrations
When updating major versions:
1. Backup all user data
2. Run migration validator
3. Execute migration steps
4. Verify data integrity
5. Update version markers

## Version Check Schedule

- **Daily**: Check for security updates
- **Weekly**: Validate dependency versions
- **Monthly**: Full compatibility audit
- **Quarterly**: Performance benchmark across versions

## Deprecation Notices

Currently no deprecated APIs.

## Change Log

### Version 1.0.0 (2025-01-01)
- Initial release
- Core transaction management
- CloudKit sync
- Export functionality
- Natural language parsing
