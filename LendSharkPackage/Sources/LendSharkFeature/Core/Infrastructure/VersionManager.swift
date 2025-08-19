import Foundation

/// Version management and validation system
/// Following Version Verification Protocol from requirements
public final class VersionManager: @unchecked Sendable {
    public static let shared = VersionManager()
    
    // Current versions
    public struct Versions {
        public static let app = "1.0.0"
        public static let dtoContract = "1.0.0"
        public static let minimumIOS = "16.0"
        public static let swiftVersion = "6.0"
        public static let coreDataModel = "1.0"
    }
    
    // Dependency versions with compatibility matrix
    public struct Dependencies {
        public static let verified: [String: DependencyInfo] = [
            "iOS": DependencyInfo(
                current: "16.0",
                minimum: "16.0",
                maximum: "18.0",
                lastVerified: Date()
            ),
            "Swift": DependencyInfo(
                current: "6.0",
                minimum: "5.9",
                maximum: "6.1",
                lastVerified: Date()
            ),
            "CloudKit": DependencyInfo(
                current: "1.0",
                minimum: "1.0",
                maximum: "1.0",
                lastVerified: Date()
            )
        ]
    }
    
    private init() {}
    
    // MARK: - Version Validation
    
    public func validateAllVersions() -> VersionValidationResult {
        var issues: [VersionIssue] = []
        
        // Check iOS version
        if let iosVersion = ProcessInfo.processInfo.operatingSystemVersionString.components(separatedBy: " ").last {
            if !isVersionCompatible(iosVersion, with: Dependencies.verified["iOS"]!) {
                issues.append(VersionIssue(
                    component: "iOS",
                    current: iosVersion,
                    required: Dependencies.verified["iOS"]!.minimum,
                    severity: .warning
                ))
            }
        }
        
        // Check DTO contract version
        if TransactionDTO.version != Versions.dtoContract {
            issues.append(VersionIssue(
                component: "DTO Contract",
                current: TransactionDTO.version,
                required: Versions.dtoContract,
                severity: .critical
            ))
        }
        
        return VersionValidationResult(
            isValid: issues.filter { $0.severity == .critical }.isEmpty,
            issues: issues,
            validatedAt: Date()
        )
    }
    
    public func checkForUpdates() async -> [UpdateInfo] {
        // In production, this would check against a server or package registry
        // For now, return empty array
        return []
    }
    
    // MARK: - Compatibility Checking
    
    private func isVersionCompatible(_ version: String, with dependency: DependencyInfo) -> Bool {
        guard let current = Version(version),
              let minimum = Version(dependency.minimum),
              let maximum = Version(dependency.maximum) else {
            return false
        }
        
        return current >= minimum && current <= maximum
    }
    
    // MARK: - Migration Support
    
    public func migrationRequired(from oldVersion: String, to newVersion: String) -> Bool {
        guard let old = Version(oldVersion),
              let new = Version(newVersion) else {
            return false
        }
        
        // Migration required for major version changes
        return old.major != new.major
    }
    
    public func getMigrationPath(from oldVersion: String, to newVersion: String) -> [MigrationStep] {
        guard migrationRequired(from: oldVersion, to: newVersion) else {
            return []
        }
        
        // Define migration steps based on version changes
        var steps: [MigrationStep] = []
        
        if let old = Version(oldVersion), let new = Version(newVersion) {
            if old.major < new.major {
                steps.append(MigrationStep(
                    from: oldVersion,
                    to: newVersion,
                    description: "Major version upgrade - backup recommended",
                    handler: performMajorMigration
                ))
            }
        }
        
        return steps
    }
    
    private func performMajorMigration() async throws {
        // Implement major version migration logic
        print("Performing major version migration...")
    }
}

// MARK: - Supporting Types

public struct DependencyInfo: Sendable {
    public let current: String
    public let minimum: String
    public let maximum: String
    public let lastVerified: Date
}

public struct VersionValidationResult {
    public let isValid: Bool
    public let issues: [VersionIssue]
    public let validatedAt: Date
}

public struct VersionIssue {
    public let component: String
    public let current: String
    public let required: String
    public let severity: Severity
    
    public enum Severity {
        case info
        case warning
        case critical
    }
}

public struct UpdateInfo {
    public let component: String
    public let currentVersion: String
    public let availableVersion: String
    public let releaseNotes: String
    public let isSecurityUpdate: Bool
}

public struct MigrationStep {
    public let from: String
    public let to: String
    public let description: String
    public let handler: () async throws -> Void
}

// MARK: - Version Type

struct Version: Comparable {
    let major: Int
    let minor: Int
    let patch: Int
    
    init?(_ string: String) {
        let components = string.split(separator: ".").compactMap { Int($0) }
        guard components.count >= 2 else { return nil }
        
        self.major = components[0]
        self.minor = components[1]
        self.patch = components.count > 2 ? components[2] : 0
    }
    
    static func < (lhs: Version, rhs: Version) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }
    
    static func == (lhs: Version, rhs: Version) -> Bool {
        return lhs.major == rhs.major && lhs.minor == rhs.minor && lhs.patch == rhs.patch
    }
}
