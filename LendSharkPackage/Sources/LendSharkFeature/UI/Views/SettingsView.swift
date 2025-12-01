import SwiftUI
import CoreData

/// Settings view - now uses environment object instead of singleton
public struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var settingsService: SettingsService
    @State private var showingCurrencyPicker = false
    @State private var showingExportFormatPicker = false
    @State private var showingNotificationFrequencyPicker = false
    @State private var showingClearDataAlert = false
    @State private var showingContactSupport = false
    @State private var showingResetAlert = false
    
    public init() {}
    
    public var body: some View {
        Form {
            // General Settings Section
            Section {
                Toggle("Notifications", isOn: $settingsService.enableNotifications)
                    .tint(.inkBlack)
                    .onChange(of: settingsService.enableNotifications) { newValue in
                        if newValue {
                            settingsService.scheduleNotifications()
                        } else {
                            settingsService.cancelAllNotifications()
                        }
                    }
                
                if settingsService.enableNotifications {
                    HStack {
                        Text("Frequency")
                            .foregroundColor(.inkBlack)
                        Spacer()
                        Button(settingsService.notificationFrequency) {
                            showingNotificationFrequencyPicker = true
                        }
                        .foregroundColor(.pencilGray)
                    }
                }
                
                Toggle("Auto-settle Transactions", isOn: $settingsService.autoSettle)
                    .tint(.inkBlack)
                
                Toggle("iCloud Sync", isOn: $settingsService.enableiCloudSync)
                    .tint(.inkBlack)
                
                if settingsService.isBiometricAvailable() {
                    Toggle(settingsService.getBiometricType(), isOn: $settingsService.biometricAuth)
                        .tint(.inkBlack)
                }
            } header: {
                Text("General")
            }
            
            // Display Settings Section
            Section {
                HStack {
                    Text("Currency Symbol")
                        .foregroundColor(.inkBlack)
                    Spacer()
                    Button(settingsService.currencySymbol) {
                        showingCurrencyPicker = true
                    }
                    .foregroundColor(.pencilGray)
                }
                
                HStack {
                    Text("Export Format")
                        .foregroundColor(.inkBlack)
                    Spacer()
                    Button(settingsService.exportFormat) {
                        showingExportFormatPicker = true
                    }
                    .foregroundColor(.pencilGray)
                }
                
                Toggle("Dark Mode", isOn: $settingsService.darkMode)
                    .tint(.inkBlack)
            } header: {
                Text("Display")
            }
            
            // Loan Defaults Section
            Section {
                HStack {
                    Text("Weekly Interest Rate")
                        .foregroundColor(.inkBlack)
                        .font(.system(.body, design: .monospaced))
                    Spacer()
                    Stepper("\(settingsService.defaultInterestRate)%", 
                           value: $settingsService.defaultInterestRate,
                           in: 0...100,
                           step: 5)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.inkBlack)
                }
                
                HStack {
                    Text("Default Loan Period")
                        .foregroundColor(.inkBlack)
                        .font(.system(.body, design: .monospaced))
                    Spacer()
                    Stepper("\(settingsService.defaultLoanDuration) days", 
                           value: $settingsService.defaultLoanDuration,
                           in: 1...90,
                           step: 7)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.inkBlack)
                }
            } header: {
                Text("LOAN DEFAULTS")
                    .font(.system(.caption, design: .monospaced))
            } footer: {
                Text("These values are used when creating new loans")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.pencilGray)
            }
            
            // Quick Add Section
            Section {
                Toggle("Show Frequent Borrowers", isOn: $settingsService.showFrequentBorrowers)
                    .tint(.inkBlack)
                    .font(.system(.body, design: .monospaced))
                
                Toggle("Enable Tap-to-Build", isOn: $settingsService.enableTapToBuild)
                    .tint(.inkBlack)
                    .font(.system(.body, design: .monospaced))
            } header: {
                Text("QUICK ADD")
                    .font(.system(.caption, design: .monospaced))
            } footer: {
                Text("Customize quick add interface behavior")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.pencilGray)
            }
            
            // Shortcuts Section
            Section {
                if settingsService.abbreviations.isEmpty {
                    Text("No shortcuts configured")
                        .foregroundColor(.pencilGray)
                        .font(.system(.body, design: .monospaced))
                        .italic()
                } else {
                    ForEach(Array(settingsService.abbreviations.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                        HStack {
                            Text(key)
                                .foregroundColor(.inkBlack)
                                .font(.system(.body, design: .monospaced, weight: .bold))
                            Text("=")
                                .foregroundColor(.pencilGray)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Text(settingsService.currencySymbol + "\(value)")
                                .foregroundColor(.cashGreen)
                                .font(.system(.body, design: .monospaced, weight: .bold))
                        }
                    }
                }
            } header: {
                Text("SHORTCUTS")
                    .font(.system(.caption, design: .monospaced))
            } footer: {
                Text("Quick amount shortcuts for common loans")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.pencilGray)
            }
            
            // Privacy Settings Section
            Section {
Toggle("Crash Reporting", isOn: $settingsService.crashReportingEnabled)
                    .tint(.inkBlack)
            } header: {
                Text("Privacy")
            }
            
            // Data Management Section
            Section {
                Button("Clear All Data") {
                    showingClearDataAlert = true
                }
                .foregroundColor(.red)
                
                Button("Reset Settings") {
                    showingResetAlert = true
                }
                .foregroundColor(.orange)
            } header: {
                Text("Data Management")
            }
            
            // Support Section
            Section {
                Button("Contact Support") {
                    showingContactSupport = true
                }
                .foregroundColor(.inkBlack)
                
                HStack {
                    Text("App Version")
                        .foregroundColor(.inkBlack)
                    Spacer()
                    Text(settingsService.getAppVersion())
                        .foregroundColor(.pencilGray)
                }
                
                HStack {
                    Text("Build Number")
                        .foregroundColor(.inkBlack)
                    Spacer()
                    Text(settingsService.getBuildNumber())
                        .foregroundColor(.pencilGray)
                }
            } header: {
                Text("Support")
            }
        }
        .navigationTitle("Settings")
        
        // Pickers
        .sheet(isPresented: $showingCurrencyPicker) {
            CurrencyPickerView(settingsService: settingsService)
        }
        .sheet(isPresented: $showingExportFormatPicker) {
            ExportFormatPickerView(settingsService: settingsService)
        }
        .sheet(isPresented: $showingNotificationFrequencyPicker) {
            NotificationFrequencyPickerView(settingsService: settingsService)
        }
        
        // Alerts
        .alert("Clear All Data", isPresented: $showingClearDataAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                clearAllData()
            }
        } message: {
            Text("This will permanently delete all your transactions. This action cannot be undone.")
        }
        .alert("Reset Settings", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                settingsService.resetToDefaults()
            }
        } message: {
            Text("This will reset all settings to their default values.")
        }
        .sheet(isPresented: $showingContactSupport) {
            ContactSupportView()
        }
    }
    
    private func clearAllData() {
        // Implementation to clear Core Data
        // This would need access to the persistence controller through environment
        print("Clearing all data...")
    }
}

// MARK: - Picker Views

private struct CurrencyPickerView: View {
    @ObservedObject var settingsService: SettingsService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(settingsService.availableCurrencies, id: \.self) { currency in
                HStack {
                    Text(currency)
                    Spacer()
                    if currency == settingsService.currencySymbol {
                        Image(systemName: "checkmark")
                            .foregroundColor(.inkBlack)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    settingsService.currencySymbol = currency
                    dismiss()
                }
            }
            .navigationTitle("Currency")
        }
    }
}

private struct ExportFormatPickerView: View {
    @ObservedObject var settingsService: SettingsService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(settingsService.availableExportFormats, id: \.self) { format in
                HStack {
                    Text(format)
                    Spacer()
                    if format == settingsService.exportFormat {
                        Image(systemName: "checkmark")
                            .foregroundColor(.inkBlack)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    settingsService.exportFormat = format
                    dismiss()
                }
            }
            .navigationTitle("Export Format")
        }
    }
}

private struct NotificationFrequencyPickerView: View {
    @ObservedObject var settingsService: SettingsService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(settingsService.availableNotificationFrequencies, id: \.self) { frequency in
                HStack {
                    Text(frequency)
                    Spacer()
                    if frequency == settingsService.notificationFrequency {
                        Image(systemName: "checkmark")
                            .foregroundColor(.inkBlack)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    settingsService.notificationFrequency = frequency
                    dismiss()
                }
            }
            .navigationTitle("Notification Frequency")
        }
    }
}

private struct ContactSupportView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "envelope")
                    .font(.system(size: 60))
                    .foregroundColor(.inkBlack)
                
                Text("Contact Support")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("For questions, issues, or feedback, please email us at:")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.pencilGray)
                
                Button("support@lendshark.app") {
                    dismiss()
                }
                .foregroundColor(.inkBlack)
                .font(.headline)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Support")
        }
    }
}
