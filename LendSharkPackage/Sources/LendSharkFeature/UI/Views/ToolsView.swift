import SwiftUI

/// Tools hub: Settlement, Export, etc. in notebook style
struct ToolsView: View {
    var body: some View {
        ZStack {
            RuledLinesBackground()
            
            VStack(alignment: .leading, spacing: 0) {
                headerSection
                
                List {
                    NavigationLink {
                        SettlementRootView()
                    } label: {
                        Text("Settlement")
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .foregroundColor(.inkBlack)
                    }
                    .listRowBackground(Color.clear)
                    
                    NavigationLink {
                        ExportView()
                    } label: {
                        Text("Export")
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .foregroundColor(.inkBlack)
                    }
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("TOOLS")
                .font(.system(size: 24, weight: .black, design: .monospaced))
                .foregroundColor(.inkBlack)
                .tracking(2)
            Rectangle().frame(height: 2).foregroundColor(.inkBlack)
            Rectangle().frame(height: 1).foregroundColor(.inkBlack).padding(.top, 2)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
}

#Preview {
    NavigationStack {
        ToolsView()
    }
}

