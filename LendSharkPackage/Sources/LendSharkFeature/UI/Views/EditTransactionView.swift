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
                    VStack(alignment: .leading, spacing: 0) {
                        // Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text("EDIT ENTRY")
                                .font(.system(size: 24, weight: .black, design: .monospaced))
                                .tracking(2)
                                .foregroundColor(.inkBlack)
                            Rectangle().frame(height: 2).foregroundColor(.inkBlack)
                            Rectangle().frame(height: 1).foregroundColor(.inkBlack).padding(.top, 2)
                        }
                        .padding(.bottom, 24)

                        // Party name
                        fieldSection(title: "WHO", spacing: 24) {
                            TextField("Name", text: $party)
                                .font(.system(size: 17, weight: .semibold, design: .monospaced))
                                .foregroundColor(.inkBlack)
                                .autocapitalization(.words)
                        }

                        // Amount
                        fieldSection(title: "AMOUNT", spacing: 24) {
                            HStack(spacing: 4) {
                                Text("$")
                                    .font(.system(size: 24, weight: .black, design: .monospaced))
                                    .foregroundColor(.inkBlack)
                                TextField("0.00", text: $amount)
                                    .font(.system(size: 24, weight: .black, design: .monospaced))
                                    .foregroundColor(.inkBlack)
                                    .keyboardType(.decimalPad)
                            }
                        }

                        // Direction
                        fieldSection(title: "DIRECTION", spacing: 24) {
                            HStack(spacing: 12) {
                                directionButton(title: "THEY OWE", value: 1, color: .bloodRed)
                                directionButton(title: "I OWE", value: -1, color: .cashGreen)
                            }
                        }

                        // Interest rate
                        fieldSection(title: "INTEREST (WEEKLY)", spacing: 24) {
                            HStack(spacing: 4) {
                                TextField("0", text: $interestRate)
                                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                                    .foregroundColor(.bloodRed)
                                    .keyboardType(.numberPad)
                                    .frame(width: 60)
                                Text("%")
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                                    .foregroundColor(.pencilGray)
                                Spacer()
                            }
                        }

                        // Due date toggle and picker
                        fieldSection(title: "DUE DATE", spacing: 24) {
                            VStack(alignment: .leading, spacing: 12) {
                                Toggle(isOn: $hasDueDate) {
                                    Text(hasDueDate ? "DUE DATE SET" : "NO DUE DATE")
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundColor(hasDueDate ? .bloodRed : .pencilGray)
                                }
                                .tint(.bloodRed)

                                if hasDueDate {
                                    DatePicker("", selection: $dueDate, displayedComponents: .date)
                                        .datePickerStyle(.compact)
                                        .labelsHidden()
                                }
                            }
                        }

                        // Notes
                        fieldSection(title: "NOTES / COLLATERAL", spacing: 24) {
                            TextField("e.g. has my watch", text: $notes, axis: .vertical)
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(.inkBlack)
                                .lineLimit(2...4)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("CANCEL") {
                        onDismiss()
                    }
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.pencilGray)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        saveChanges()
                    } label: {
                        Text("SAVE")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .tracking(1)
                            .foregroundColor(.paperYellow)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(isValid ? Color.inkBlack : Color.pencilGray)
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
    
    // MARK: - Components

    private func fieldSection<Content: View>(title: String, spacing: CGFloat = 20, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundColor(.pencilGray)

            content()

            Rectangle()
                .frame(height: 1)
                .foregroundColor(.inkBlack.opacity(0.2))
        }
        .padding(.bottom, spacing)
    }

    private func directionButton(title: String, value: Int16, color: Color) -> some View {
        Button {
            direction = value
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .tracking(1)
                .foregroundColor(direction == value ? .paperYellow : color)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(direction == value ? color : Color.clear)
                .overlay(Rectangle().stroke(color, lineWidth: direction == value ? 0 : 1.5))
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
