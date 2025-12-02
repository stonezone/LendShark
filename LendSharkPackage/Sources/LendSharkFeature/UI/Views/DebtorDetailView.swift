import SwiftUI
import CoreData

/// Detail view showing all transactions with a specific person
struct DebtorDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let personName: String
    
    @FetchRequest private var transactions: FetchedResults<Transaction>
    
    @State private var editingTransaction: Transaction?
    @State private var showingEditSheet = false
    @State private var showingPartialPayment = false
    @State private var partialAmount = ""
    @FocusState private var isPartialAmountFocused: Bool
    
    init(personName: String) {
        self.personName = personName
        self._transactions = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Transaction.timestamp, ascending: false)],
            predicate: NSPredicate(format: "party ==[c] %@", personName)
        )
    }
    
    private var debtorInfo: DebtLedger.DebtorInfo? {
        DebtLedger.getDebtors(from: Array(transactions)).first
    }
    
    private var totalOwed: Decimal {
        debtorInfo?.principal ?? 0
    }
    
    private var totalWithInterest: Decimal {
        debtorInfo?.totalOwed ?? totalOwed
    }
    
    var body: some View {
        ZStack {
            RuledLinesBackground()
                .onTapGesture {
                    isPartialAmountFocused = false
                }
            
            VStack(alignment: .leading, spacing: 0) {
                // Header
                headerSection
                
                // Summary
                summarySection
                
                // Transaction list
                transactionList
            }
        }
        .navigationTitle(personName.uppercased())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if totalOwed > 0 {
                    Button("PARTIAL PAY") {
                        showingPartialPayment = true
                    }
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.cashGreen)
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            if let transaction = editingTransaction {
                EditTransactionView(transaction: transaction) {
                    showingEditSheet = false
                    editingTransaction = nil
                }
            }
        }
        .alert("PARTIAL PAYMENT", isPresented: $showingPartialPayment) {
            TextField("Amount", text: $partialAmount)
                .keyboardType(.decimalPad)
            Button("RECORD") {
                recordPartialPayment()
            }
            Button("CANCEL", role: .cancel) {
                partialAmount = ""
            }
        } message: {
            Text("How much did \(personName) pay?")
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("HISTORY")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(.pencilGray)
                Spacer()
                Text("← swipe rows")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.pencilGray.opacity(0.5))
            }
            Rectangle().frame(height: 1).foregroundColor(.inkBlack.opacity(0.3))
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    // MARK: - Summary
    private var summarySection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                // Status stamp
                Text(totalOwed >= 0 ? "OWES YOU" : "YOU OWE")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(totalOwed > 0 ? .bloodRed : .cashGreen)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .overlay(Rectangle().stroke(totalOwed > 0 ? Color.bloodRed : Color.cashGreen, lineWidth: 1))
                    .rotationEffect(.degrees(-2))

                // Big amount
                Text(formatCurrency(abs(totalWithInterest)))
                    .font(.system(size: 32, weight: .black, design: .monospaced))
                    .foregroundColor(totalOwed > 0 ? .bloodRed : .cashGreen)

                // Interest breakdown
                if totalWithInterest != totalOwed && totalOwed > 0 {
                    let interest = totalWithInterest - totalOwed
                    HStack(spacing: 4) {
                        Text(formatCurrency(totalOwed))
                            .foregroundColor(.inkBlack)
                        Text("+")
                            .foregroundColor(.pencilGray)
                        Text(formatCurrency(interest))
                            .foregroundColor(.bloodRed)
                        Text("int")
                            .foregroundColor(.pencilGray)
                    }
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                }
            }

            Spacer()

            // Active count badge
            VStack(alignment: .trailing, spacing: 2) {
                let activeCount = transactions.filter { !$0.settled }.count
                Text("\(activeCount)")
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .foregroundColor(.inkBlack)
                Text("ACTIVE")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(.pencilGray)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.bloodRed.opacity(totalOwed > 0 ? 0.04 : 0))
    }
    
    // MARK: - Transaction List
    private var transactionList: some View {
        List {
            ForEach(transactions) { transaction in
                TransactionRowView(transaction: transaction)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteTransaction(transaction)
                        } label: {
                            Label("DELETE", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            editingTransaction = transaction
                            showingEditSheet = true
                        } label: {
                            Label("EDIT", systemImage: "pencil")
                        }
                        .tint(.orange)
                        
                        if !transaction.settled {
                            Button {
                                settleTransaction(transaction)
                            } label: {
                                Label("PAID", systemImage: "checkmark")
                            }
                            .tint(.cashGreen)
                        }
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.immediately)
    }
    
    // MARK: - Actions
    
    private func deleteTransaction(_ transaction: Transaction) {
        viewContext.delete(transaction)
        try? viewContext.save()
    }
    
    private func settleTransaction(_ transaction: Transaction) {
        transaction.settled = true
        try? viewContext.save()
    }
    
    private func recordPartialPayment() {
        guard let amount = Decimal(string: partialAmount), amount > 0 else {
            partialAmount = ""
            return
        }
        
        do {
            try Transaction.recordPartialPayment(
                person: personName,
                amount: amount,
                in: viewContext
            )
            partialAmount = ""
        } catch {
            // Silent fail
        }
    }
    
    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0"
    }
}

// MARK: - Transaction Row

struct TransactionRowView: View {
    let transaction: Transaction

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Left - Direction indicator
            let isLent = transaction.direction == 1
            VStack(spacing: 2) {
                Image(systemName: isLent ? "arrow.up.right" : "arrow.down.left")
                    .font(.system(size: 12, weight: .bold))
                Text(isLent ? "OUT" : "IN")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
            }
            .foregroundColor(isLent ? .bloodRed : .cashGreen)
            .frame(width: 32)

            // Middle - Details
            VStack(alignment: .leading, spacing: 3) {
                // Date
                if let date = transaction.timestamp {
                    Text(date.formatted(date: .abbreviated, time: .omitted).uppercased())
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.pencilGray)
                }

                // Notes if present
                if let notes = transaction.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.inkBlack)
                        .lineLimit(1)
                }

                // Interest/Due info row
                HStack(spacing: 8) {
                    if let rate = transaction.interestRate?.decimalValue, rate > 0 {
                        let pct = NSDecimalNumber(decimal: rate * 100).intValue
                        Text("\(pct)%")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.bloodRed.opacity(0.8))
                    }

                    if let due = transaction.dueDate {
                        let isOverdue = due < Date() && !transaction.settled
                        Text("DUE \(due.formatted(date: .abbreviated, time: .omitted).uppercased())")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(isOverdue ? .bloodRed : .pencilGray.opacity(0.7))
                    }
                }
            }

            Spacer()

            // Right - Amount and status
            VStack(alignment: .trailing, spacing: 4) {
                let amount = transaction.amount?.decimalValue ?? 0
                Text(formatCurrency(amount))
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(transaction.settled ? .pencilGray : .inkBlack)

                if transaction.settled {
                    Text("PAID")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .tracking(1)
                        .foregroundColor(.cashGreen.opacity(0.8))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.cashGreen.opacity(0.1))
                        .overlay(Rectangle().stroke(Color.cashGreen.opacity(0.5), lineWidth: 1))
                        .rotationEffect(.degrees(3))
                }
            }
        }
        .padding(.vertical, 6)
        .opacity(transaction.settled ? 0.5 : 1.0)
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0"
    }
}

#Preview {
    NavigationStack {
        DebtorDetailView(personName: "John")
    }
}
