import SwiftUI

/// Settings view
public struct SettingsView: View {
    @AppStorage("enableNotifications") private var enableNotifications = true
    @AppStorage("enableiCloudSync") private var enableiCloudSync = true
    @AppStorage("currencySymbol") private var currencySymbol = "$"
    @State private var showingClearDataAlert = false
    
    public init() {}
    
    public var body: some View {
        Form {
            Section {
                Toggle("iCloud Sync", isOn: $enableiCloudSync)
                    .tint(.tealAccent)
                
                Toggle("Notifications", isOn: $enableNotifications)
                    .tint(.tealAccent)
            } header: {
                Text("GENERAL")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            .listRowBackground(Color.cardBackground)
            
            Section {
                HStack {
                    Text("Currency")
                        .foregroundColor(.textPrimary)
                    Spacer()
                    Text(currencySymbol)
                        .foregroundColor(.textSecondary)
                }
                
                HStack {
                    Text("Theme")
                        .foregroundColor(.textPrimary)
                    Spacer()
                    Text("Dark")
                        .foregroundColor(.textSecondary)
                }
            } header: {
                Text("DISPLAY")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            .listRowBackground(Color.cardBackground)
            
            Section {
                HStack {
                    Text("Version")
                        .foregroundColor(.textPrimary)
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.textSecondary)
                }
                
                HStack {
                    Text("Build")
                        .foregroundColor(.textPrimary)
                    Spacer()
                    Text("2025.1")
                        .foregroundColor(.textSecondary)
                }
            } header: {
                Text("ABOUT")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            .listRowBackground(Color.cardBackground)
            
            Section {
                Button(action: exportAllData) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export All Data")
                    }
                    .foregroundColor(.tealAccent)
                }
                
                Button(action: { showingClearDataAlert = true }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear All Data")
                    }
                    .foregroundColor(.expenseRed)
                }
            } header: {
                Text("DATA MANAGEMENT")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            .listRowBackground(Color.cardBackground)
            
            Section {
                Link(destination: URL(string: "https://example.com/privacy")!) {
                    HStack {
                        Text("Privacy Policy")
                            .foregroundColor(.textPrimary)
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.textSecondary)
                    }
                }
                
                Link(destination: URL(string: "https://example.com/terms")!) {
                    HStack {
                        Text("Terms of Service")
                            .foregroundColor(.textPrimary)
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.textSecondary)
                    }
                }
            } header: {
                Text("LEGAL")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            .listRowBackground(Color.cardBackground)
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .alert("Clear All Data?", isPresented: $showingClearDataAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                clearAllData()
            }
        } message: {
            Text("This will permanently delete all your transactions. This action cannot be undone.")
        }
    }
    
    private func exportAllData() {
        // Implement export functionality
        print("Exporting all data...")
    }
    
    private func clearAllData() {
        // Implement clear data functionality
        print("Clearing all data...")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .preferredColorScheme(.dark)
    }
}
