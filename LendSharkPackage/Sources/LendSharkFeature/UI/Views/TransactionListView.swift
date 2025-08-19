import SwiftUI
import CoreData

/// Transaction list view matching reference app
public struct TransactionListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel = TransactionListViewModel()
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Transaction.timestamp, ascending: false)],
        animation: .default
    ) private var transactions: FetchedResults<Transaction>
    
    @State private var searchText = ""
    @State private var showingAddSheet = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Date header
            dateHeader
            
            // Quick entry section
            quickEntryCard
            
            // Transaction list
            transactionsList
        }
        .background(Color.appBackground)
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search transactions")
        .sheet(isPresented: $showingAddSheet) {
            AddTransactionSheet()
        }
    }
    
    private var dateHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.dayNumber)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.textPrimary)
                
                Text(viewModel.dayName)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                
                Text(viewModel.monthYear)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            
            Spacer()
            
            Button(action: { showingAddSheet = true }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.tealAccent)
            }
        }
        .padding()
    }
    
    private var quickEntryCard: some View {
        EmptyView() // Removed hardcoded yacht and goals - will implement properly later
    }
    
    private var transactionsList: some View {
        List {
            ForEach(groupedTransactions, id: \.key) { section in
                Section {
                    ForEach(section.transactions) { transaction in
                        TransactionRowView(transaction: transaction)
                            .listRowBackground(Color.cardBackground)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    deleteTransaction(transaction)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                
                                Button {
                                    toggleSettle(transaction)
                                } label: {
                                    Label("Settle", systemImage: "checkmark.circle")
                                }
                                .tint(.incomeGreen)
                            }
                    }
                } header: {
                    Text(section.key)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
            }
        }
        .listStyle(PlainListStyle())
        .scrollContentBackground(.hidden)
    }
    
    private var groupedTransactions: [(key: String, transactions: [Transaction])] {
        let filtered = searchText.isEmpty ? Array(transactions) : 
            transactions.filter { 
                ($0.party ?? "").localizedCaseInsensitiveContains(searchText) ||
                ($0.notes ?? "").localizedCaseInsensitiveContains(searchText)
            }
        
        let grouped = Dictionary(grouping: filtered) { transaction in
            viewModel.formatSectionDate(transaction.timestamp ?? Date())
        }
        
        return grouped.sorted { $0.key > $1.key }
            .map { (key: $0.key, transactions: $0.value) }
    }
    
    private func deleteTransaction(_ transaction: Transaction) {
        withAnimation {
            viewContext.delete(transaction)
            try? viewContext.save()
        }
    }
    
    private func toggleSettle(_ transaction: Transaction) {
        withAnimation {
            transaction.settled.toggle()
            try? viewContext.save()
        }
    }
}

/// Individual transaction row
struct TransactionRowView: View {
    let transaction: Transaction
    
    var body: some View {
        HStack(spacing: Layout.itemSpacing) {
            // Category icon
            Image(systemName: categoryIcon)
                .font(.system(size: 24))
                .foregroundColor(categoryColor)
                .frame(width: 40, height: 40)
                .background(categoryColor.opacity(0.2))
                .cornerRadius(20)
            
            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.party ?? "Unknown")
                    .font(.cardTitle)
                    .foregroundColor(.textPrimary)
                
                if let notes = transaction.notes {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Amount
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatAmount)
                    .font(.amount)
                    .foregroundColor(amountColor)
                
                if transaction.settled {
                    Text("SETTLED")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.textSecondary)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private var categoryIcon: String {
        if transaction.isItem {
            return "cube.box"
        } else if transaction.direction > 0 {
            return "arrow.up.circle"
        } else {
            return "arrow.down.circle"
        }
    }
    
    private var categoryColor: Color {
        transaction.direction > 0 ? .incomeGreen : .expenseRed
    }
    
    private var amountColor: Color {
        transaction.settled ? .textSecondary : 
            (transaction.direction > 0 ? .incomeGreen : .expenseRed)
    }
    
    private var formatAmount: String {
        if transaction.isItem {
            return transaction.item ?? "Item"
        } else {
            let amount = (transaction.amount as? NSDecimalNumber)?.doubleValue ?? 0
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencySymbol = "$"
            return formatter.string(from: NSNumber(value: amount)) ?? "$0"
        }
    }
}

/// Add transaction sheet
/// Add transaction sheet with natural language parsing
struct AddTransactionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @State private var inputText = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Enter a transaction")
                    .font(.headline)
                    .foregroundColor(.textSecondary)
                    .padding(.top)
                
                TextField("e.g. lent 20 to john for lunch", text: $inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                Text("Examples:")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("• \"lent 50 to sarah\"")
                    Text("• \"borrowed 20 from mike\"")
                    Text("• \"john owes me 15 for coffee\"")
                    Text("• \"paid back emma 30\"")
                }
                .font(.caption)
                .foregroundColor(.textSecondary)
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Add Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addTransaction()
                    }
                    .disabled(inputText.isEmpty)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func addTransaction() {
        // Parse the input using a local instance with required dependencies
        let validationService = ValidationService()
        let parserService = ParserService(validationService: validationService)
        let result = parserService.parse(inputText)
        
        // Handle the Result type
        switch result {
        case .failure(let error):
            errorMessage = "Could not understand: \(inputText)\nError: \(error.localizedDescription)\nTry: 'lent 20 to john'"
            showError = true
            return
        case .success(let parsedAction):
            switch parsedAction {
            case .add(let dto):
                // Create transaction from parsed DTO
                let transaction = Transaction(context: viewContext)
                transaction.id = dto.id
                transaction.party = dto.party
                transaction.amount = dto.amount as? NSDecimalNumber
                transaction.item = dto.item
                transaction.direction = Int16(dto.direction.rawValue)
                transaction.isItem = dto.isItem
                transaction.settled = dto.settled
                transaction.timestamp = dto.timestamp
                transaction.notes = dto.notes
            case .settle(let party):
                // Handle settlement - find and mark transactions as settled
                let request: NSFetchRequest<Transaction> = Transaction.fetchRequest()
                request.predicate = NSPredicate(
                    format: "party ==[c] %@ AND settled == NO",
                    party
                )
                
                do {
                    let transactions = try viewContext.fetch(request)
                    if transactions.isEmpty {
                        errorMessage = "No unsettled transactions found for \(party)"
                        showError = true
                        return
                    }
                    
                    // Mark all as settled
                    for transaction in transactions {
                        transaction.settled = true
                    }
                    
                    // Save and dismiss
                    try viewContext.save()
                    dismiss()
                    
                } catch {
                    errorMessage = "Failed to settle transactions: \(error.localizedDescription)"
                    showError = true
                    return
                }
            }
        }
        
        // Save to Core Data
        do {
            try viewContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to save transaction: \(error.localizedDescription)"
            showError = true
        }
    }
}

/// View model for transaction list
@MainActor
class TransactionListViewModel: ObservableObject {
    var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: Date())
    }
    
    var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: Date())
    }
    
    var monthYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: Date())
    }
    
    func formatSectionDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        TransactionListView()
            .preferredColorScheme(.dark)
    }
}
