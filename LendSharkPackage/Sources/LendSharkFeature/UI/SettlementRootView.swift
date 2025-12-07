import SwiftUI
import CoreData

/// Simple settlement screen - pick a person and mark debts paid.
public struct SettlementRootView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Transaction.timestamp, ascending: false)],
        animation: .default
    ) private var transactions: FetchedResults<Transaction>
    
    @State private var selectedName: String = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    public init() {}
    
    public var body: some View {
        ZStack {
            RuledLinesBackground()
            
            VStack(alignment: .leading, spacing: 16) {
            Text("SETTLEMENT")
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(.inkBlack)
            
            TextField("Name", text: $selectedName)
                .font(.system(size: 18, weight: .regular, design: .monospaced))
                .foregroundColor(.inkBlack)
                .textFieldStyle(.plain)
                .padding(.vertical, 8)
                .overlay(Rectangle().frame(height: 1).foregroundColor(.inkBlack), alignment: .bottom)
            
            Text(currentLine)
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .foregroundColor(.pencilGray)
            
            HStack(spacing: 16) {
                Button(action: settleFull) {
                    Text("PAID IN FULL")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.paperYellow)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.cashGreen)
                }
                .disabled(selectedName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            
            Spacer()
            }
            .padding(24)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var currentLine: String {
        let name = selectedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return "Type a name to clear their tab." }
        let total = Transaction.totalOwed(by: name, in: viewContext)
        let amount = NSDecimalNumber(decimal: total).doubleValue
        let formatted = String(format: "%.2f", amount)
        return "On the books for \(name.uppercased()): $\(formatted)"
    }
    
    private func settleFull() {
        let name = selectedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        do {
            try Transaction.settleAll(with: name, in: viewContext)
            selectedName = ""
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
