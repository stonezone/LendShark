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
    
    init(personName: String) {
        self.personName = personName
        self._transactions = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Transaction.timestamp, ascending: false)],
            predicate: NSPredicate(format: "party ==[c] %@", personName)
        )
    }
    
    private var totalOwed: Decimal {
        transactions.filter { !$0.settled }.reduce(Decimal.zero) { total, t in
            let amount = t.amount?.decimalValue ?? 0
            let direction: Decimal = t.direction == 1 ? 1 : -1
            return total + (amount * direction)
        }
    }
    
    private var totalWithInterest: Decimal {
        let now = Date()
        return transactions.filter { !$0.settled }.reduce(Decimal.zero) { total, t in
            let amount = t.amount?.decimalValue ?? 0
            let direction: Decimal = t.direction == 1 ? 1 : -1
            let principal = amount * direction
            
            // Calculate interest
            var interest: Decimal = 0
            if let rate = t.interestRate?.decimalValue,
               let timestamp = t.timestamp,
               principal > 0 {
                let weeks = Decimal(Calendar.current.dateComponents([.day], from: timestamp, to: now).day ?? 0) / 7
                interest = principal * rate * weeks
            }
            
            return total + principal + interest
        }
    }
    
    var body: some View {
        ZStack {
            RuledLinesBackground()
            
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
            Text("TRANSACTION HISTORY")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.pencilGray)
            
            Rectangle()
                .frame(height: 2)
                .foregroundColor(.inkBlack)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
    
    // MARK: - Summary
    private var summarySection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(totalOwed >= 0 ? "OWES YOU" : "YOU OWE")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.pencilGray)
                
                Text(formatCurrency(abs(totalWithInterest)))
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                    .foregroundColor(totalOwed > 0 ? .bloodRed : .cashGreen)
                
                if totalWithInterest != totalOwed && totalOwed > 0 {
                    let interest = totalWithInterest - totalOwed
                    Text("(\(formatCurrency(totalOwed)) + \(formatCurrency(interest)) interest)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.pencilGray)
                }
            }
            
            Spacer()
            
            Text("\(transactions.filter { !$0.settled }.count) active")
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.pencilGray)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.bloodRed.opacity(totalOwed > 0 ? 0.05 : 0))
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
        HStack(alignment: .top) {
            // Left side - date and details
            VStack(alignment: .leading, spacing: 4) {
                // Date
                if let date = transaction.timestamp {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.pencilGray)
                }
                
                // Direction indicator
                let isLent = transaction.direction == 1
                Text(isLent ? "LENT" : "BORROWED")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(isLent ? .bloodRed : .cashGreen)
                
                // Notes if present
                if let notes = transaction.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.pencilGray)
                        .lineLimit(2)
                }
                
                // Interest rate if present
                if let rate = transaction.interestRate?.decimalValue, rate > 0 {
                    let pct = NSDecimalNumber(decimal: rate * 100).intValue
                    Text("\(pct)% weekly")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.bloodRed)
                }
                
                // Due date if present
                if let due = transaction.dueDate {
                    let isOverdue = due < Date()
                    Text("Due: \(due.formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(isOverdue ? .bloodRed : .pencilGray)
                }
            }
            
            Spacer()
            
            // Right side - amount and status
            VStack(alignment: .trailing, spacing: 4) {
                let amount = transaction.amount?.decimalValue ?? 0
                Text(formatCurrency(amount))
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(transaction.settled ? .pencilGray : .inkBlack)
                
                if transaction.settled {
                    Text("SETTLED")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundColor(.cashGreen)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .overlay(Rectangle().stroke(Color.cashGreen, lineWidth: 1))
                }
            }
        }
        .padding(.vertical, 4)
        .opacity(transaction.settled ? 0.6 : 1.0)
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
