import SwiftUI

/// Ruled lines background to simulate notebook paper
struct RuledLinesBackground: View {
    let lineSpacing: CGFloat
    let lineColor: Color
    let marginLeft: CGFloat
    
    init(
        lineSpacing: CGFloat = 28,
        lineColor: Color = Color.inkBlack.opacity(0.1),
        marginLeft: CGFloat = 40
    ) {
        self.lineSpacing = lineSpacing
        self.lineColor = lineColor
        self.marginLeft = marginLeft
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base paper color
                Color.paperYellow
                    .ignoresSafeArea()
                
                // Horizontal ruled lines
                VStack(spacing: lineSpacing) {
                    ForEach(0..<Int(geometry.size.height / lineSpacing) + 1, id: \.self) { _ in
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(lineColor)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                
                // Left margin line (red line like school notebooks)
                Rectangle()
                    .frame(width: 1)
                    .foregroundColor(.bloodRed.opacity(0.3))
                    .position(x: marginLeft, y: geometry.size.height / 2)
                
                // Optional: Three hole punches (like binder paper)
                VStack {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .frame(width: 8, height: 8)
                            .foregroundColor(.pencilGray.opacity(0.4))
                            .position(
                                x: 20,
                                y: geometry.size.height * (0.2 + CGFloat(index) * 0.3)
                            )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

/// Simplified ruled lines for smaller components
struct SimpleRuledLines: View {
    let lineSpacing: CGFloat
    
    init(lineSpacing: CGFloat = 24) {
        self.lineSpacing = lineSpacing
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: lineSpacing) {
                ForEach(0..<Int(geometry.size.height / lineSpacing) + 1, id: \.self) { _ in
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundColor(Color.inkBlack.opacity(0.08))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

/// Notebook-style section divider
struct NotebookDivider: View {
    let title: String?
    let color: Color
    
    init(title: String? = nil, color: Color = .inkBlack) {
        self.title = title
        self.color = color
    }
    
    var body: some View {
        HStack {
            if let title = title {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
                    .padding(.trailing, 8)
            }
            
            Rectangle()
                .frame(height: 2)
                .foregroundColor(color)
        }
    }
}

#Preview("Ruled Lines Background") {
    RuledLinesBackground()
        .frame(height: 400)
}

#Preview("Simple Ruled Lines") {
    ZStack {
        Color.paperYellow
        SimpleRuledLines()
        
        VStack(alignment: .leading, spacing: 24) {
            Text("Sample notebook text")
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundColor(.inkBlack)
            
            Text("Another line of writing")
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundColor(.inkBlack)
        }
        .padding(60)
    }
    .frame(height: 200)
}