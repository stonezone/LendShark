import Foundation
import os

/// Centralized logging system for LendShark
/// Replaces print() statements with proper structured logging
public struct AppLogger: Sendable {
    private let logger: os.Logger
    
    public init(subsystem: String = "com.stonezone.LendShark", category: String) {
        self.logger = Logger(subsystem: subsystem, category: category)
    }
    
    /// Log debug information (only in debug builds)
    public func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        logger.debug("\(message) [\(URL(fileURLWithPath: file).lastPathComponent):\(line)]")
        #endif
    }
    
    /// Log informational messages
    public func info(_ message: String) {
        logger.info("\(message)")
    }
    
    /// Log warning messages
    public func warning(_ message: String) {
        logger.warning("⚠️ \(message)")
    }
    
    /// Log error messages
    public func error(_ message: String, error: Error? = nil) {
        if let error = error {
            logger.error("❌ \(message): \(error.localizedDescription)")
        } else {
            logger.error("❌ \(message)")
        }
    }
    
    /// Log critical errors that require immediate attention
    public func critical(_ message: String, error: Error? = nil) {
        if let error = error {
            logger.critical("🔴 CRITICAL: \(message): \(error.localizedDescription)")
        } else {
            logger.critical("🔴 CRITICAL: \(message)")
        }
    }
}

/// Pre-configured loggers for different subsystems
public extension AppLogger {
    static let persistence = AppLogger(category: "Persistence")
    static let sync = AppLogger(category: "CloudKit")
    static let transaction = AppLogger(category: "Transaction")
    static let validation = AppLogger(category: "Validation")
    static let settings = AppLogger(category: "Settings")
    static let ui = AppLogger(category: "UI")
    static let parser = AppLogger(category: "Parser")
    static let version = AppLogger(category: "VersionManager")
}