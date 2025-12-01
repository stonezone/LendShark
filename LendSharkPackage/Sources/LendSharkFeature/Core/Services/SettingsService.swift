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
    @AppStorage("darkMode") public var darkMode = true
    @AppStorage("biometricAuth") public var biometricAuth = false
    @AppStorage("enableiCloudSync") public var enableiCloudSync = true
    
    // MARK: - Display Settings
    @AppStorage("currencySymbol") public var currencySymbol = "$"
    @AppStorage("exportFormat") public var exportFormat = "CSV"
    @AppStorage("notificationFrequency") public var notificationFrequency = "Daily"
    
    // MARK: - Privacy Settings
    @AppStorage("analyticsEnabled") public var analyticsEnabled = false
    @AppStorage("crashReportingEnabled") public var crashReportingEnabled = true
    
    // MARK: - Initialization
    /// Public initializer - no longer singleton
    public init() {}
    
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
        darkMode = true
        biometricAuth = false
        enableiCloudSync = true
        currencySymbol = "$"
        exportFormat = "CSV"
        notificationFrequency = "Daily"
        analyticsEnabled = false
        crashReportingEnabled = true
    }
    
    public func getAppVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    public func getBuildNumber() -> String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    // MARK: - Notification Scheduling
    public func scheduleNotifications() {
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
    }
    
    public func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
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