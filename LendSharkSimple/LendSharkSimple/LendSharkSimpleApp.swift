import SwiftUI

@main
struct LendSharkApp: App {
    var body: some Scene {
        WindowGroup {
            ZStack {
                // Notebook paper background
                Color(hex: "F4E8D0") // Aged paper
                    .ignoresSafeArea()
                
                // Ruled lines - exclude safe area bottom to avoid covering tab bar
                RuledLinesBackground()
                    .ignoresSafeArea(.all, edges: [.top, .leading, .trailing])
                
                // Main content
                MainTabView()
            }
        }
    }
}

/// Ruled lines background to simulate notebook paper
struct RuledLinesBackground: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Horizontal ruled lines
                VStack(spacing: 28) {
                    ForEach(0..<Int(geometry.size.height / 28) + 1, id: \.self) { _ in
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(Color(hex: "1A1A1A").opacity(0.1))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                
                // Left margin line (red line like school notebooks)
                Rectangle()
                    .frame(width: 1)
                    .foregroundColor(Color(hex: "8B0000").opacity(0.3))
                    .position(x: 40, y: geometry.size.height / 2)
            }
        }
    }
}

/// Color extensions
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