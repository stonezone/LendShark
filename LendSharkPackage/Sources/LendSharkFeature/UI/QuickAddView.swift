import SwiftUI
import CoreData

/// Quick Add Debt - single field, simple parser.
public struct QuickAddView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var inputText = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @FocusState private var isInputFocused: Bool

    public init() {}

    public var body: some View {
        ZStack {
            RuledLinesBackground()
                .onTapGesture {
                    isInputFocused = false
                }

            VStack(alignment: .leading, spacing: 0) {
                // Header with double underline
                VStack(alignment: .leading, spacing: 4) {
                    Text("QUICK ADD")
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .foregroundColor(.inkBlack)
                        .tracking(2)
                    Rectangle().frame(height: 2).foregroundColor(.inkBlack)
                    Rectangle().frame(height: 1).foregroundColor(.inkBlack).padding(.top, 2)
                }
                .padding(.bottom, 24)

                // Input field with pencil-style underline
                VStack(alignment: .leading, spacing: 8) {
                    Text("WRITE IT DOWN:")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.pencilGray)
                        .tracking(1)

                    TextField("john owes 50 due 2 weeks at 10%", text: $inputText)
                        .font(.system(size: 17, weight: .medium, design: .monospaced))
                        .foregroundColor(.inkBlack)
                        .textFieldStyle(.plain)
                        .padding(.vertical, 12)
                        .focused($isInputFocused)
                        .onSubmit {
                            add()
                            isInputFocused = false
                        }

                    // Pencil underline effect
                    Rectangle()
                        .frame(height: 2)
                        .foregroundColor(.inkBlack.opacity(0.7))
                }
                .padding(.bottom, 20)

                // Preview with stamp styling
                if !previewText.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("WILL RECORD:")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.pencilGray)
                            .tracking(1)

                        Text(previewText)
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundColor(.inkBlack)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.inkBlack.opacity(0.05))
                            .overlay(
                                Rectangle()
                                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 2]))
                                    .foregroundColor(.inkBlack.opacity(0.3))
                            )
                    }
                    .padding(.bottom, 24)
                }

                // Add button - bold and direct
                Button(action: add) {
                    HStack {
                        Text("ADD TO LEDGER")
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .tracking(1)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.paperYellow)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.inkBlack)
                }
                .disabled(previewText.isEmpty)
                .opacity(previewText.isEmpty ? 0.5 : 1.0)

                // Help text
                VStack(alignment: .leading, spacing: 8) {
                    Text("EXAMPLES:")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.pencilGray.opacity(0.7))
                        .padding(.top, 24)

                    Group {
                        Text("• john owes 50")
                        Text("• mary owes 100 due 2 weeks")
                        Text("• mike owes 200 at 10%")
                        Text("• john paid 25")
                        Text("• i owe frank 50")
                    }
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.pencilGray.opacity(0.6))
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
    
    private var previewText: String {
        let parser = ParserService()
        switch parser.parse(inputText) {
        case .success(let action):
            switch action {
            case .add(let dto):
                let who = dto.party
                let amount = dto.amount ?? 0
                let dollars = String(format: "%.2f", NSDecimalNumber(decimal: amount).doubleValue)
                var base = dto.direction == .lent 
                    ? "\(who.uppercased()) owes $\(dollars)"
                    : "I owe \(who.uppercased()) $\(dollars)"
                
                // Add interest if present
                if let rate = dto.interestRate {
                    let pct = NSDecimalNumber(decimal: rate * 100).intValue
                    base += " @ \(pct)%/wk"
                }
                
                // Add due date if present
                if let due = dto.dueDate {
                    let days = Calendar.current.dateComponents([.day], from: Date(), to: due).day ?? 0
                    base += " (due in \(days)d)"
                }
                
                // Add notes if present
                if let notes = dto.notes, !notes.isEmpty {
                    base += " [\(notes)]"
                }
                
                return base
            case .settle(let name):
                return "Mark \(name.uppercased()) as PAID"
            }
        case .failure:
            return ""
        }
    }
    
    private func add() {
        let parser = ParserService()
        let result = parser.parse(inputText)
        
        switch result {
        case .failure(let error):
            // Stay in character but keep it clear.
            errorMessage = error.localizedDescription
            showError = true
        case .success(let action):
            do {
                switch action {
                case .add(let dto):
                    let t = Transaction(context: viewContext)
                    t.id = dto.id
                    t.party = dto.party
                    t.amount = dto.amount.map { NSDecimalNumber(decimal: $0) }
                    t.direction = Int16(dto.direction == .lent ? 1 : -1)
                    t.isItem = dto.isItem
                    t.settled = dto.settled
                    t.timestamp = dto.timestamp
                    t.dueDate = dto.dueDate
                    t.interestRate = dto.interestRate.map { NSDecimalNumber(decimal: $0) }
                    t.notes = dto.notes
                    try viewContext.save()
                case .settle(let name):
                    try Transaction.settleAll(with: name, in: viewContext)
                }
                inputText = ""
                isInputFocused = false
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}
