import SwiftUI
import CoreData

/// Quick Add Debt - single field, simple parser.
public struct QuickAddView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var inputText = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    public init() {}
    
    public var body: some View {
        ZStack {
            RuledLinesBackground()
            
            VStack(alignment: .leading, spacing: 16) {
            Text("QUICK ADD")
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(.inkBlack)
            
            TextField("e.g. john owes 50", text: $inputText)
                .font(.system(size: 18, weight: .regular, design: .monospaced))
                .textFieldStyle(.plain)
                .padding(.vertical, 8)
                .overlay(Rectangle().frame(height: 1).foregroundColor(.inkBlack), alignment: .bottom)
                .onSubmit(add)
            
            if !previewText.isEmpty {
                Text(previewText)
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .foregroundColor(.pencilGray)
            }
            
            Button(action: add) {
                Text("ADD")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.paperYellow)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.inkBlack)
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
                if dto.direction == .lent {
                    return "Will record: \(who.uppercased()) owes $\(dollars)"
                } else {
                    return "Will record: I owe \(who.uppercased()) $\(dollars)"
                }
            case .settle(let name):
                return "Will mark everything with \(name.uppercased()) as PAID."
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
                    try viewContext.save()
                case .settle(let name):
                    try Transaction.settleAll(with: name, in: viewContext)
                }
                inputText = ""
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}
