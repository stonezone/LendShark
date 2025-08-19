import SwiftUI

/// Main tab navigation matching reference app
public struct MainTabView: View {
    @State private var selectedTab = 0
    
    public init() {}
    
    public var body: some View {
        TabView(selection: $selectedTab) {
            // Today/Transactions Tab
            NavigationStack {
                TransactionListView()
            }
            .tabItem {
                Label("Today", systemImage: "calendar")
            }
            .tag(0)
            
            // Balance Tab
            NavigationStack {
                BalanceOverviewView()
            }
            .tabItem {
                Label("Balance", systemImage: "chart.bar.fill")
            }
            .tag(1)
            
            // Budget/Analytics Tab
            NavigationStack {
                AnalyticsView()
            }
            .tabItem {
                Label("Budget", systemImage: "chart.pie.fill")
            }
            .tag(2)
            
            // Reports/Export Tab
            NavigationStack {
                ReportsView()
            }
            .tabItem {
                Label("Reports", systemImage: "doc.text.fill")
            }
            .tag(3)
            
            // More/Settings Tab
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("More", systemImage: "ellipsis.circle.fill")
            }
            .tag(4)
        }
        .tint(Color.tealAccent)
    }
}

/// Color extensions matching reference app
public extension Color {
    static let appBackground = Color(hex: "1C1C1E")
    static let cardBackground = Color(hex: "2C2C2E")
    static let tealAccent = Color(hex: "00BCD4")
    static let incomeGreen = Color(hex: "4CAF50")
    static let expenseRed = Color(hex: "FF5252")
    static let warningYellow = Color(hex: "FFC107")
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "8E8E93")
}

/// Layout constants
public struct Layout {
    public static let cardPadding: CGFloat = 16
    public static let itemSpacing: CGFloat = 12
    public static let sectionSpacing: CGFloat = 24
    public static let cornerRadius: CGFloat = 12
    public static let iconSize: CGFloat = 32
    public static let buttonHeight: CGFloat = 44
}

/// Typography extensions
public extension Font {
    static let largeAmount = Font.system(size: 34, weight: .bold, design: .rounded)
    static let sectionTitle = Font.system(size: 20, weight: .semibold)
    static let cardTitle = Font.system(size: 17, weight: .semibold)
    static let amount = Font.system(size: 17, weight: .medium).monospacedDigit()
    static let label = Font.system(size: 14, weight: .regular)
}

/// Color hex initializer
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    MainTabView()
        .preferredColorScheme(.dark)
}
