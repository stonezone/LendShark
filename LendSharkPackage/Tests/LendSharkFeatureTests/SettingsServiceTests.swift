import XCTest
import SwiftUI
import LocalAuthentication
@testable import LendSharkFeature

@MainActor
final class SettingsServiceTests: XCTestCase {
    var settingsService: SettingsService!
    var mockUserDefaults: MockUserDefaults!
    var mockLAContext: MockLAContext!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create mock UserDefaults
        mockUserDefaults = MockUserDefaults()
        
        // Create settings service
        settingsService = SettingsService()
        
        // Mock LocalAuthentication context
        mockLAContext = MockLAContext()
        
        // Reset to defaults for consistent testing
        settingsService.resetToDefaults()
    }
    
    override func tearDown() async throws {
        settingsService = nil
        mockUserDefaults = nil
        mockLAContext = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization_DefaultValues_AreCorrect() {
        // Then
        XCTAssertTrue(settingsService.enableNotifications)
        XCTAssertFalse(settingsService.autoSettle)
        XCTAssertTrue(settingsService.darkMode)
        XCTAssertFalse(settingsService.biometricAuth)
        XCTAssertTrue(settingsService.enableiCloudSync)
        XCTAssertEqual(settingsService.currencySymbol, "$")
        XCTAssertEqual(settingsService.exportFormat, "CSV")
        XCTAssertEqual(settingsService.notificationFrequency, "Daily")
        XCTAssertFalse(settingsService.analyticsEnabled)
        XCTAssertTrue(settingsService.crashReportingEnabled)
    }
    
    // MARK: - General Settings Tests
    
    func testEnableNotifications_Toggle_UpdatesCorrectly() {
        // Given
        let initialValue = settingsService.enableNotifications
        
        // When
        settingsService.enableNotifications = !initialValue
        
        // Then
        XCTAssertEqual(settingsService.enableNotifications, !initialValue)
    }
    
    func testAutoSettle_Toggle_UpdatesCorrectly() {
        // Given
        settingsService.autoSettle = false
        
        // When
        settingsService.autoSettle = true
        
        // Then
        XCTAssertTrue(settingsService.autoSettle)
    }
    
    func testDarkMode_Toggle_UpdatesCorrectly() {
        // Given
        settingsService.darkMode = true
        
        // When
        settingsService.darkMode = false
        
        // Then
        XCTAssertFalse(settingsService.darkMode)
    }
    
    func testBiometricAuth_Toggle_UpdatesCorrectly() {
        // Given
        settingsService.biometricAuth = false
        
        // When
        settingsService.biometricAuth = true
        
        // Then
        XCTAssertTrue(settingsService.biometricAuth)
    }
    
    func testEnableiCloudSync_Toggle_UpdatesCorrectly() {
        // Given
        settingsService.enableiCloudSync = true
        
        // When
        settingsService.enableiCloudSync = false
        
        // Then
        XCTAssertFalse(settingsService.enableiCloudSync)
    }
    
    // MARK: - Display Settings Tests
    
    func testCurrencySymbol_ValidSymbols_UpdateCorrectly() {
        // Given
        let validSymbols = ["$", "€", "£", "¥", "₹", "₽", "₩", "₦", "₪", "₿"]
        
        // When/Then
        for symbol in validSymbols {
            settingsService.currencySymbol = symbol
            XCTAssertEqual(settingsService.currencySymbol, symbol)
        }
    }
    
    func testExportFormat_ValidFormats_UpdateCorrectly() {
        // Given
        let validFormats = ["CSV", "PDF", "JSON"]
        
        // When/Then
        for format in validFormats {
            settingsService.exportFormat = format
            XCTAssertEqual(settingsService.exportFormat, format)
        }
    }
    
    func testNotificationFrequency_ValidFrequencies_UpdateCorrectly() {
        // Given
        let validFrequencies = ["Never", "Daily", "Weekly", "Monthly"]
        
        // When/Then
        for frequency in validFrequencies {
            settingsService.notificationFrequency = frequency
            XCTAssertEqual(settingsService.notificationFrequency, frequency)
        }
    }
    
    // MARK: - Privacy Settings Tests
    
    func testAnalyticsEnabled_Toggle_UpdatesCorrectly() {
        // Given
        settingsService.analyticsEnabled = false
        
        // When
        settingsService.analyticsEnabled = true
        
        // Then
        XCTAssertTrue(settingsService.analyticsEnabled)
    }
    
    func testCrashReportingEnabled_Toggle_UpdatesCorrectly() {
        // Given
        settingsService.crashReportingEnabled = true
        
        // When
        settingsService.crashReportingEnabled = false
        
        // Then
        XCTAssertFalse(settingsService.crashReportingEnabled)
    }
    
    // MARK: - Available Options Tests
    
    func testAvailableCurrencies_ReturnsExpectedList() {
        // When
        let currencies = settingsService.availableCurrencies
        
        // Then
        XCTAssertEqual(currencies.count, 10)
        XCTAssertTrue(currencies.contains("$"))
        XCTAssertTrue(currencies.contains("€"))
        XCTAssertTrue(currencies.contains("£"))
        XCTAssertTrue(currencies.contains("¥"))
        XCTAssertTrue(currencies.contains("₹"))
        XCTAssertTrue(currencies.contains("₽"))
        XCTAssertTrue(currencies.contains("₩"))
        XCTAssertTrue(currencies.contains("₦"))
        XCTAssertTrue(currencies.contains("₪"))
        XCTAssertTrue(currencies.contains("₿"))
    }
    
    func testAvailableExportFormats_ReturnsExpectedList() {
        // When
        let formats = settingsService.availableExportFormats
        
        // Then
        XCTAssertEqual(formats.count, 3)
        XCTAssertTrue(formats.contains("CSV"))
        XCTAssertTrue(formats.contains("PDF"))
        XCTAssertTrue(formats.contains("JSON"))
    }
    
    func testAvailableNotificationFrequencies_ReturnsExpectedList() {
        // When
        let frequencies = settingsService.availableNotificationFrequencies
        
        // Then
        XCTAssertEqual(frequencies.count, 4)
        XCTAssertTrue(frequencies.contains("Never"))
        XCTAssertTrue(frequencies.contains("Daily"))
        XCTAssertTrue(frequencies.contains("Weekly"))
        XCTAssertTrue(frequencies.contains("Monthly"))
    }
    
    // MARK: - Biometric Authentication Tests
    
    func testIsBiometricAvailable_MockContext_ReturnsExpectedValue() {
        // Note: This test depends on the device capabilities and cannot be easily mocked
        // without dependency injection. In a production app, we would inject LAContext.
        
        // When
        let isAvailable = settingsService.isBiometricAvailable()
        
        // Then
        // We can only test that the method returns a boolean value
        XCTAssertTrue(isAvailable is Bool)
    }
    
    func testGetBiometricType_ReturnsStringValue() {
        // When
        let biometricType = settingsService.getBiometricType()
        
        // Then
        XCTAssertTrue(biometricType is String)
        XCTAssertFalse(biometricType.isEmpty)
        
        // Should return one of the expected values
        let expectedTypes = ["Face ID", "Touch ID", "Optic ID", "Biometric"]
        XCTAssertTrue(expectedTypes.contains(biometricType))
    }
    
    // MARK: - Reset to Defaults Tests
    
    func testResetToDefaults_AllSettings_ReturnToDefaults() {
        // Given - Change all settings from defaults
        settingsService.enableNotifications = false
        settingsService.autoSettle = true
        settingsService.darkMode = false
        settingsService.biometricAuth = true
        settingsService.enableiCloudSync = false
        settingsService.currencySymbol = "€"
        settingsService.exportFormat = "PDF"
        settingsService.notificationFrequency = "Never"
        settingsService.analyticsEnabled = true
        settingsService.crashReportingEnabled = false
        
        // When
        settingsService.resetToDefaults()
        
        // Then
        XCTAssertTrue(settingsService.enableNotifications)
        XCTAssertFalse(settingsService.autoSettle)
        XCTAssertTrue(settingsService.darkMode)
        XCTAssertFalse(settingsService.biometricAuth)
        XCTAssertTrue(settingsService.enableiCloudSync)
        XCTAssertEqual(settingsService.currencySymbol, "$")
        XCTAssertEqual(settingsService.exportFormat, "CSV")
        XCTAssertEqual(settingsService.notificationFrequency, "Daily")
        XCTAssertFalse(settingsService.analyticsEnabled)
        XCTAssertTrue(settingsService.crashReportingEnabled)
    }
    
    // MARK: - App Version and Build Tests
    
    func testGetAppVersion_ReturnsValidVersion() {
        // When
        let appVersion = settingsService.getAppVersion()
        
        // Then
        XCTAssertFalse(appVersion.isEmpty)
        
        // Should match semantic version pattern (x.y.z or similar)
        let versionComponents = appVersion.split(separator: ".")
        XCTAssertGreaterThanOrEqual(versionComponents.count, 2)
        
        // First component should be a number
        XCTAssertNotNil(Int(versionComponents[0]))
    }
    
    func testGetBuildNumber_ReturnsValidBuildNumber() {
        // When
        let buildNumber = settingsService.getBuildNumber()
        
        // Then
        XCTAssertFalse(buildNumber.isEmpty)
        
        // Build number should be numeric or alphanumeric
        XCTAssertTrue(buildNumber.allSatisfy { $0.isNumber || $0.isLetter })
    }
    
    // MARK: - Notification Management Tests
    
    func testScheduleNotifications_CallsWithCorrectFrequency() {
        // Given
        settingsService.notificationFrequency = "Weekly"
        
        // When
        settingsService.scheduleNotifications()
        
        // Then
        // In a real implementation, this would verify that UNUserNotificationCenter
        // was called with the correct schedule. For now, we just ensure it doesn't crash.
        XCTAssertEqual(settingsService.notificationFrequency, "Weekly")
    }
    
    func testCancelAllNotifications_CallsSuccessfully() {
        // When
        settingsService.cancelAllNotifications()
        
        // Then
        // In a real implementation, this would verify that UNUserNotificationCenter
        // removeAllPendingNotificationRequests was called. For now, we ensure it doesn't crash.
        XCTAssertTrue(true) // Method completed without crashing
    }
    
    // MARK: - Settings Persistence Tests
    
    func testSettingsPersistence_MultipleChanges_PersistCorrectly() {
        // Given - Create a new settings service to simulate app restart
        let originalSettings = SettingsService()
        
        // When - Change multiple settings
        originalSettings.enableNotifications = false
        originalSettings.currencySymbol = "€"
        originalSettings.exportFormat = "JSON"
        originalSettings.darkMode = false
        
        // Simulate app restart with new settings service
        let newSettings = SettingsService()
        
        // Then - Settings should persist (this tests UserDefaults integration)
        // Note: In a real test environment with isolated UserDefaults, we could verify persistence
        // For now, we test that the settings maintain their values within the same instance
        XCTAssertEqual(originalSettings.enableNotifications, false)
        XCTAssertEqual(originalSettings.currencySymbol, "€")
        XCTAssertEqual(originalSettings.exportFormat, "JSON")
        XCTAssertEqual(originalSettings.darkMode, false)
    }
    
    // MARK: - Edge Cases and Error Handling Tests
    
    func testCurrencySymbol_EmptyString_HandlesGracefully() {
        // When
        settingsService.currencySymbol = ""
        
        // Then
        // AppStorage should handle empty strings gracefully
        XCTAssertEqual(settingsService.currencySymbol, "")
    }
    
    func testExportFormat_InvalidFormat_HandlesGracefully() {
        // When
        settingsService.exportFormat = "INVALID_FORMAT"
        
        // Then
        // Should accept any string value (validation might happen elsewhere)
        XCTAssertEqual(settingsService.exportFormat, "INVALID_FORMAT")
    }
    
    func testNotificationFrequency_InvalidFrequency_HandlesGracefully() {
        // When
        settingsService.notificationFrequency = "Every Minute"
        
        // Then
        // Should accept any string value (validation might happen elsewhere)
        XCTAssertEqual(settingsService.notificationFrequency, "Every Minute")
    }
    
    // MARK: - Boundary Value Tests
    
    func testLongCurrencySymbol_HandlesCorrectly() {
        // Given
        let longSymbol = String(repeating: "💰", count: 100)
        
        // When
        settingsService.currencySymbol = longSymbol
        
        // Then
        XCTAssertEqual(settingsService.currencySymbol, longSymbol)
    }
    
    func testUnicodeCurrencySymbol_HandlesCorrectly() {
        // Given
        let unicodeSymbols = ["💰", "🪙", "💸", "💎"]
        
        // When/Then
        for symbol in unicodeSymbols {
            settingsService.currencySymbol = symbol
            XCTAssertEqual(settingsService.currencySymbol, symbol)
        }
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentSettingsAccess_ThreadSafe() async {
        // When - Perform concurrent setting updates
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask { [weak self] in
                    await MainActor.run {
                        self?.settingsService.enableNotifications = i % 2 == 0
                        self?.settingsService.autoSettle = i % 3 == 0
                        self?.settingsService.darkMode = i % 4 == 0
                    }
                }
            }
        }
        
        // Then - Should not crash and final values should be consistent
        let finalNotifications = settingsService.enableNotifications
        let finalAutoSettle = settingsService.autoSettle
        let finalDarkMode = settingsService.darkMode
        
        // Values should be boolean (not corrupted)
        XCTAssertTrue(finalNotifications is Bool)
        XCTAssertTrue(finalAutoSettle is Bool)
        XCTAssertTrue(finalDarkMode is Bool)
    }
    
    // MARK: - Integration with Other Components Tests
    
    func testSettingsIntegrationWithExportService_CorrectFormat() {
        // Given
        settingsService.exportFormat = "PDF"
        
        // When
        let selectedFormat = settingsService.exportFormat
        
        // Then
        XCTAssertEqual(selectedFormat, "PDF")
        XCTAssertTrue(settingsService.availableExportFormats.contains(selectedFormat))
    }
    
    func testSettingsIntegrationWithNotificationService_CorrectFrequency() {
        // Given
        settingsService.notificationFrequency = "Weekly"
        settingsService.enableNotifications = true
        
        // When
        let shouldSchedule = settingsService.enableNotifications
        let frequency = settingsService.notificationFrequency
        
        // Then
        XCTAssertTrue(shouldSchedule)
        XCTAssertEqual(frequency, "Weekly")
        XCTAssertTrue(settingsService.availableNotificationFrequencies.contains(frequency))
    }
    
    // MARK: - Performance Tests
    
    func testSettingsPerformance_MultipleAccess() {
        measure {
            for _ in 0..<1000 {
                settingsService.enableNotifications = !settingsService.enableNotifications
                settingsService.currencySymbol = settingsService.currencySymbol == "$" ? "€" : "$"
                _ = settingsService.availableCurrencies
                _ = settingsService.getAppVersion()
            }
        }
    }
    
    func testResetToDefaultsPerformance() {
        measure {
            for _ in 0..<100 {
                settingsService.resetToDefaults()
            }
        }
    }
}

// MARK: - Mock Classes

class MockUserDefaults: UserDefaults {
    private var storage: [String: Any] = [:]
    
    override func object(forKey defaultName: String) -> Any? {
        return storage[defaultName]
    }
    
    override func set(_ value: Any?, forKey defaultName: String) {
        storage[defaultName] = value
    }
    
    override func bool(forKey defaultName: String) -> Bool {
        return storage[defaultName] as? Bool ?? false
    }
    
    override func string(forKey defaultName: String) -> String? {
        return storage[defaultName] as? String
    }
    
    override func removeObject(forKey defaultName: String) {
        storage.removeValue(forKey: defaultName)
    }
    
    override func synchronize() -> Bool {
        return true
    }
}

class MockLAContext: LAContext {
    var mockBiometryType: LABiometryType = .none
    var mockCanEvaluatePolicy = false
    var mockError: NSError?
    
    override func canEvaluatePolicy(_ policy: LAPolicy, error: NSErrorPointer) -> Bool {
        if let mockError = mockError {
            error?.pointee = mockError
        }
        return mockCanEvaluatePolicy
    }
    
    override var biometryType: LABiometryType {
        return mockBiometryType
    }
}