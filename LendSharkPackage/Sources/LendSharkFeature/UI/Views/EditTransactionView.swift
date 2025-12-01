import SwiftUI
import CoreData

/// Edit an existing transaction - loan shark style
struct EditTransactionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    let transaction: Transaction
    let onDismiss: () -> Void
    
    @State private var amount: String
    @State private var party: String
    @State private var notes: String
    @State private var interestRate: String
    @State private var dueDate: Date
    @State private var hasDueDate: Bool
    @State private var direction: Int16
    
    init(transaction: Transaction, onDismiss: @escaping () -> Void) {
        self.transaction = transaction
        self.onDismiss = onDismiss
        
        let amountValue = transaction.amount?.decimalValue ?? 0
        _amount = State(initialValue: String(format: "%.2f", NSDecimalNumber(decimal: amountValue).doubleValue))
        _party = State(initialValue: transaction.party ?? "")
        _notes = State(initialValue: transaction.notes ?? "")
        
        let rateValue = (transaction.interestRate?.decimalValue ?? 0) * 100
        _interestRate = State(initialValue: rateValue > 0 ? String(format: "%.0f", NSDecimalNumber(decimal: rateValue).doubleValue) : "")
        
        _dueDate = State(initialValue: transaction.dueDate ?? Date())
        _hasDueDate = State(initialValue: transaction.dueDate != nil)
        _direction = State(initialValue: transaction.direction)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                RuledLinesBackground()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Party name
                        fieldSection(title: "WHO") {
                            TextField("Name", text: $party)
                                .font(.system(size: 18, weight: .medium, design: .monospaced))
                                .foregroundColor(.inkBlack)
                                .autocapitalization(.words)
                        }
                        
                        // Amount
                        fieldSection(title: "AMOUNT") {
                            HStack {
                                Text("$")
                                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                                    .foregroundColor(.inkBlack)
                                TextField("0.00", text: $amount)
                                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                                    .foregroundColor(.inkBlack)
                                    .keyboardType(.decimalPad)
                            }
                        }
                        
                        // Direction
                        fieldSection(title: "DIRECTION") {
                            HStack(spacing: 16) {
                                directionButton(title: "THEY OWE ME", value: 1)
                                directionButton(title: "I OWE THEM", value: -1)
                            }
                        }
                        
                        // Interest rate
                        fieldSection(title: "INTEREST (WEEKLY %)") {
                            HStack {
                                TextField("0", text: $interestRate)
                                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                                    .foregroundColor(.inkBlack)
                                    .keyboardType(.numberPad)
                                Text("%")
                                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                                    .foregroundColor(.pencilGray)
                            }
                        }
                        
                        // Due date toggle and picker
                        fieldSection(title: "DUE DATE") {
                            VStack(alignment: .leading, spacing: 12) {
                                Toggle("SET DUE DATE", isOn: $hasDueDate)
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundColor(.inkBlack)
                                    .tint(.bloodRed)
                                
                                if hasDueDate {
                                    DatePicker("", selection: $dueDate, displayedComponents: .date)
                                        .datePickerStyle(.compact)
                                        .labelsHidden()
                                }
                            }
                        }
                        
                        // Notes
                        fieldSection(title: "NOTES / COLLATERAL") {
                            TextField("e.g. has my watch", text: $notes, axis: .vertical)
                                .font(.system(size: 16, design: .monospaced))
                                .foregroundColor(.inkBlack)
                                .lineLimit(3...5)
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("EDIT DEBT")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("CANCEL") {
                        onDismiss()
                    }
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.pencilGray)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("SAVE") {
                        saveChanges()
                    }
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundColor(.bloodRed)
                    .disabled(!isValid)
                }
            }
        }
    }
    
    // MARK: - Components
    
    private func fieldSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.pencilGray)
            
            content()
            
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.inkBlack.opacity(0.3))
        }
    }
    
    private func directionButton(title: String, value: Int16) -> some View {
        Button {
            direction = value
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(direction == value ? .paperYellow : .inkBlack)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(direction == value ? Color.inkBlack : Color.clear)
                .overlay(Rectangle().stroke(Color.inkBlack, lineWidth: 1))
        }
    }
    
    // MARK: - Validation
    
    private var isValid: Bool {
        guard !party.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        guard let amountValue = Decimal(string: amount), amountValue > 0 else { return false }
        return true
    }
    
    // MARK: - Save
    
    private func saveChanges() {
        guard isValid else { return }
        guard let amountValue = Decimal(string: amount) else { return }
        
        transaction.party = party.trimmingCharacters(in: .whitespaces)
        transaction.amount = NSDecimalNumber(decimal: amountValue)
        transaction.direction = direction
        transaction.notes = notes.isEmpty ? nil : notes
        transaction.dueDate = hasDueDate ? dueDate : nil
        
        // Convert interest rate from percentage to decimal
        if let ratePercent = Decimal(string: interestRate), ratePercent > 0 {
            transaction.interestRate = NSDecimalNumber(decimal: ratePercent / 100)
        } else {
            transaction.interestRate = nil
        }
        
        do {
            try viewContext.save()
            onDismiss()
        } catch {
            // Silent fail - loan sharks don't do errors
        }
    }
}

#Preview {
    EditTransactionView(
        transaction: {
            let context = PersistenceController.preview.container.viewContext
            let t = Transaction(context: context)
            t.party = "John"
            t.amount = NSDecimalNumber(decimal: 50)
            t.direction = 1
            t.timestamp = Date()
            return t
        }(),
        onDismiss: {}
    )
}
