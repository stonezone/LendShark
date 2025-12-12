import SwiftUI
import LocalAuthentication
import Combine
import UserNotifications

/// Settings Manager to handle UserDefaults persistence and app-wide settings
/// Now uses proper Dependency Injection instead of singleton pattern
@MainActor
public final class SettingsService: ObservableObject {
    // MARK: - General Settings
    @AppStorage("enableNotifications") public var enableNotifications = true
    @AppStorage("autoSettle") public var autoSettle = false
    @AppStorage("darkMode") public var darkMode = false  // Light mode (paper) by default
    @AppStorage("biometricAuth") public var biometricAuth = false
    @AppStorage("enableiCloudSync") public var enableiCloudSync = false

    // MARK: - Loan Shark Defaults
    @AppStorage("defaultInterestRate") public var defaultInterestRate = 10  // Weekly %
    @AppStorage("defaultLoanDuration") public var defaultLoanDuration = 14  // Days
    @AppStorage("showFrequentBorrowers") public var showFrequentBorrowers = true
    @AppStorage("enableTapToBuild") public var enableTapToBuild = true

    // MARK: - Display Settings
    @AppStorage("currencySymbol") public var currencySymbol = "$"
    @AppStorage("exportFormat") public var exportFormat = "PDF"  // Loan sharks prefer PDF
    @AppStorage("notificationFrequency") public var notificationFrequency = "Daily"

    // MARK: - Abbreviations (stored as JSON)
    @AppStorage("abbreviationsJSON") private var abbreviationsJSON = """
    {"note":"100","k":"1000","point":"1","half":"50","quarter":"25","dime":"10","nickel":"5","buck":"1"}
    """
    
    // MARK: - Privacy Settings
    @AppStorage("analyticsEnabled") public var analyticsEnabled = false
    @AppStorage("crashReportingEnabled") public var crashReportingEnabled = false
    
    // MARK: - Initialization
    /// Public initializer - no longer singleton
    public init() {}

    // MARK: - Abbreviations Access
    public var abbreviations: [String: Decimal] {
        get {
            guard let data = abbreviationsJSON.data(using: .utf8),
                  let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
                return [:]
            }
            var result: [String: Decimal] = [:]
            for (key, value) in dict {
                if let decimal = Decimal(string: value) {
                    result[key.lowercased()] = decimal
                }
            }
            return result
        }
        set {
            var stringDict: [String: String] = [:]
            for (key, value) in newValue {
                stringDict[key.lowercased()] = "\(value)"
            }
            if let data = try? JSONEncoder().encode(stringDict),
               let json = String(data: data, encoding: .utf8) {
                abbreviationsJSON = json
            }
        }
    }

    public func addAbbreviation(_ key: String, value: Decimal) {
        var current = abbreviations
        current[key.lowercased()] = value
        abbreviations = current
    }

    public func removeAbbreviation(_ key: String) {
        var current = abbreviations
        current.removeValue(forKey: key.lowercased())
        abbreviations = current
    }

    /// Expand abbreviations in amount string (e.g., "2 notes" -> 200)
    public func expandAbbreviation(_ input: String) -> Decimal? {
        let lower = input.lowercased().trimmingCharacters(in: .whitespaces)

        // Check for multiplier pattern: "2 notes", "3k", etc.
        let parts = lower.split(separator: " ")
        if parts.count == 2,
           let multiplier = Decimal(string: String(parts[0])),
           let baseValue = abbreviations[String(parts[1]).replacingOccurrences(of: "s", with: "")] {
            return multiplier * baseValue
        }

        // Check for suffix pattern: "2notes", "3k"
        for (abbr, value) in abbreviations {
            if lower.hasSuffix(abbr) {
                let numPart = lower.dropLast(abbr.count)
                if let multiplier = Decimal(string: String(numPart)) {
                    return multiplier * value
                }
            }
        }

        // Check direct match
        if let value = abbreviations[lower] {
            return value
        }

        return nil
    }
    
    // MARK: - Available Options
    public var availableCurrencies: [String] {
        ["$", "€", "£", "¥", "₹", "₽", "₩", "₦", "₪", "₿"]
    }
    
    public var availableExportFormats: [String] {
        ["CSV", "PDF", "JSON"]
    }
    
    public var availableNotificationFrequencies: [String] {
        ["Never", "Daily", "Weekly", "Monthly"]
    }
    
    // MARK: - Biometric Authentication
    public func isBiometricAvailable() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    public func getBiometricType() -> String {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return "Biometric"
        }
        
        switch context.biometryType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        default:
            return "Biometric"
        }
    }
    
    // MARK: - Utility Methods
    public func resetToDefaults() {
        enableNotifications = true
        autoSettle = false
        darkMode = false
        biometricAuth = false
        enableiCloudSync = false
        currencySymbol = "$"
        exportFormat = "PDF"
        notificationFrequency = "Daily"
        analyticsEnabled = false
        crashReportingEnabled = false
        // Loan shark defaults
        defaultInterestRate = 10
        defaultLoanDuration = 14
        showFrequentBorrowers = true
        enableTapToBuild = true
        abbreviationsJSON = """
        {"note":"100","k":"1000","point":"1","half":"50","quarter":"25","dime":"10","nickel":"5","buck":"1"}
        """
    }
    
    public func getAppVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    public func getBuildNumber() -> String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    // MARK: - Notification Scheduling
    public func scheduleNotifications() {
        #if !os(iOS)
        // UNUserNotificationCenter usage is not reliable in SwiftPM/macOS test contexts.
        // This app targets iOS; keep notification scheduling iOS-only.
        return
        #else
        Task {
            await requestNotificationPermission()
            
            guard enableNotifications else {
                cancelAllNotifications()
                return
            }
            
            let center = UNUserNotificationCenter.current()
            center.removeAllPendingNotificationRequests()
            
            switch notificationFrequency {
            case "Never":
                return
            case "Daily":
                await scheduleDailyNotification()
            case "Weekly":
                await scheduleWeeklyNotification()
            case "Monthly":
                await scheduleMonthlyNotification()
            default:
                break
            }
        }
        #endif
    }
    
    public func cancelAllNotifications() {
        #if os(iOS)
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        #endif
    }
    
    @MainActor
    private func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            if !granted {
                enableNotifications = false
            }
        } catch {
            AppLogger.settings.error("Failed to request notification permission", error: error)
            enableNotifications = false
        }
    }
    
    private func scheduleDailyNotification() async {
        let content = UNMutableNotificationContent()
        content.title = "LendShark Reminder"
        content.body = "Check your pending transactions"
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = 9
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "daily_reminder", content: content, trigger: trigger)
        
        try? await UNUserNotificationCenter.current().add(request)
    }
    
    private func scheduleWeeklyNotification() async {
        let content = UNMutableNotificationContent()
        content.title = "Weekly Summary"
        content.body = "Review your weekly transactions"
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.weekday = 2 // Monday
        dateComponents.hour = 10
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "weekly_reminder", content: content, trigger: trigger)
        
        try? await UNUserNotificationCenter.current().add(request)
    }
    
    private func scheduleMonthlyNotification() async {
        let content = UNMutableNotificationContent()
        content.title = "Monthly Review"
        content.body = "Time to review your monthly transactions"
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.day = 1
        dateComponents.hour = 10
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "monthly_reminder", content: content, trigger: trigger)
        
        try? await UNUserNotificationCenter.current().add(request)
    }
}
