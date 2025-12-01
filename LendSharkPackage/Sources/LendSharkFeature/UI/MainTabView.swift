import SwiftUI

/// Main tab navigation matching reference app
public struct MainTabView: View {
    @State private var selectedTab = 0
    
    public init() {}
    
    public var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                LedgerView()
            }
            .tabItem {
                Label("The Ledger", systemImage: "book.fill")
            }
            .tag(0)
            
            // Quick Add Debt
            NavigationStack {
                QuickAddView()
            }
            .tabItem {
                Label("Quick Add", systemImage: "plus.circle.fill")
            }
            .tag(1)
            
            // Collections Tab
            NavigationStack {
                CollectionsView()
            }
            .tabItem {
                Label("Collections", systemImage: "exclamationmark.triangle.fill")
            }
            .tag(2)
            
            // Settlement Tab
            NavigationStack {
                SettlementRootView()
            }
            .tabItem {
                Label("Settlement", systemImage: "checkmark.circle")
            }
            .tag(3)
            
            // Export Tab
            NavigationStack {
                ExportView()
            }
            .tabItem {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .tag(4)
        }
        .tint(Color.inkBlack)
        // Debug: force tab bar to always be visible
        .tabViewStyle(DefaultTabViewStyle())
    }
}

/// Loan Shark Notebook Color Scheme
public extension Color {
    static let paperYellow = Color(hex: "F4E8D0") // Aged paper
    static let inkBlack = Color(hex: "1A1A1A")    // Pen ink  
    static let bloodRed = Color(hex: "8B0000")     // Overdue
    static let cashGreen = Color(hex: "2E7D32")    // Settled
    static let pencilGray = Color(hex: "6B6B6B")   // Notes
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

/// Loan Shark Notebook Typography - Handwritten Feel
public extension Font {
    // Amounts - Always monospaced like ledger entries
    static let ledgerAmount = Font.system(size: 18, weight: .bold, design: .monospaced)
    static let largeAmount = Font.system(size: 34, weight: .black, design: .monospaced)
    
    // Names and labels - Clean but not fancy
    static let ledgerName = Font.system(size: 16, weight: .medium, design: .monospaced)
    static let sectionTitle = Font.system(size: 20, weight: .bold, design: .monospaced)
    
    // Stamps and badges - Bold like stamped ink
    static let overdueStamp = Font.system(size: 14, weight: .black, design: .monospaced)
    static let badgeText = Font.system(size: 12, weight: .bold, design: .monospaced)
    
    // Body text - Simple and direct
    static let notebookText = Font.system(size: 16, weight: .regular, design: .monospaced)
    static let smallNote = Font.system(size: 14, weight: .regular, design: .monospaced)
    
    // Headers - Bold and imposing
    static let notebookHeader = Font.system(size: 28, weight: .black, design: .monospaced)
    static let tabTitle = Font.system(size: 24, weight: .bold, design: .monospaced)
    
    // Legacy compatibility
    static let cardTitle = ledgerName
    static let amount = ledgerAmount
    static let label = smallNote
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
