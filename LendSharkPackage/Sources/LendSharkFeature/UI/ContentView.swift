import SwiftUI

/// Main content view combining best features from both projects
/// Following Separation of Concerns with proper view/logic separation
public struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel = TransactionViewModel()
    
    @State private var inputText = ""
    @State private var showingExportSheet = false
    @State private var showingSettingsSheet = false
    @State private var selectedExportFormat: ExportFormat = .csv
    
    // Fetch request for transactions
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Transaction.timestamp, ascending: false)],
        animation: .default
    ) private var transactions: FetchedResults<Transaction>
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Quick entry section
                quickEntrySection
                    .padding()
                    .background(Color(.systemBackground))
                
                // Balance summary
                balanceSummary
                    .padding(.horizontal)
                    .padding(.bottom)
                
                // Transaction list
                transactionList
            }
            .navigationTitle("LendShark")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingSettingsSheet = true }) {
                        Image(systemName: "gear")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingExportSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(transactions.isEmpty)
                }
            }
            .sheet(isPresented: $showingExportSheet) {
                ExportSheet(
                    transactions: Array(transactions).map { viewModel.transactionToDTO($0) },
                    selectedFormat: $selectedExportFormat,
                    onExport: handleExport
                )
            }
            .sheet(isPresented: $showingSettingsSheet) {
                SettingsView()
            }
            .alert("Error", isPresented: $viewModel.showError, presenting: viewModel.errorMessage) { _ in
                Button("OK") { viewModel.clearError() }
            } message: { error in
                Text(error)
            }
        }
        .task {
            await viewModel.initializeServices()
        }
    }
    
    // MARK: - View Components
    
    private var quickEntrySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Entry")
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                TextField("e.g. lent 20 to john", text: $inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        Task { await addTransaction() }
                    }
                
                Button("Add") {
                    Task { await addTransaction() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(inputText.isEmpty)
            }
            
            if let preview = viewModel.parsePreview {
                parsePreviewView(preview)
            }
        }
    }
    
    private var balanceSummary: some View {
        HStack(spacing: 16) {
            SimpleBalanceCard(
                title: "They owe me",
                amount: viewModel.calculateOwedToMe(from: transactions),
                color: .green
            )
            
            SimpleBalanceCard(
                title: "I owe",
                amount: viewModel.calculateIOwe(from: transactions),
                color: .red
            )
        }
    }
    
    private var transactionList: some View {
        List {
            ForEach(transactions) { transaction in
                ContentTransactionRow(
                    transaction: viewModel.transactionToDTO(transaction),
                    onToggleSettle: {
                        Task { await toggleSettle(transaction) }
                    }
                )
            }
            .onDelete { indexSet in
                Task { await deleteTransactions(at: indexSet) }
            }
        }
        .listStyle(PlainListStyle())
    }
    
    private func parsePreviewView(_ preview: String) -> some View {
        HStack {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.blue)
            
            Text(preview)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
    
    // MARK: - Actions
    
    private func addTransaction() async {
        guard !inputText.isEmpty else { return }
        
        await viewModel.parseAndAddTransaction(inputText, context: viewContext)
        
        if viewModel.errorMessage == nil {
            inputText = ""
        }
    }
    
    private func toggleSettle(_ transaction: Transaction) async {
        transaction.settled.toggle()
        
        do {
            try viewContext.save()
        } catch {
            viewModel.showError(message: "Failed to update transaction: \(error.localizedDescription)")
        }
    }
    
    private func deleteTransactions(at offsets: IndexSet) async {
        for index in offsets {
            viewContext.delete(transactions[index])
        }
        
        do {
            try viewContext.save()
        } catch {
            viewModel.showError(message: "Failed to delete transaction: \(error.localizedDescription)")
        }
    }
    
    private func handleExport(format: ExportFormat) {
        Task {
            await viewModel.exportTransactions(
                Array(transactions).map { viewModel.transactionToDTO($0) },
                format: format
            )
        }
    }
}

// MARK: - Balance Card Component

struct SimpleBalanceCard: View {
    let title: String
    let amount: Decimal
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("$\(NSDecimalNumber(decimal: amount).doubleValue, specifier: "%.2f")")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Transaction Row Component

struct ContentTransactionRow: View {
    let transaction: TransactionDTO
    let onToggleSettle: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: transaction.direction == .lent ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .foregroundColor(transaction.direction == .lent ? .green : .red)
                    
                    Text(transaction.party)
                        .font(.headline)
                    
                    if transaction.settled {
                        Text("SETTLED")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                
                HStack {
                    if transaction.isItem {
                        Text(transaction.item ?? "Item")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("$\(NSDecimalNumber(decimal: transaction.amount ?? 0).doubleValue, specifier: "%.2f")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(transaction.timestamp, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let notes = transaction.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            Button(action: onToggleSettle) {
                Image(systemName: transaction.settled ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(transaction.settled ? .green : .gray)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Export Sheet

struct ExportSheet: View {
    let transactions: [TransactionDTO]
    @Binding var selectedFormat: ExportFormat
    let onExport: (ExportFormat) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Export \(transactions.count) transactions")
                    .font(.headline)
                    .padding(.top)
                
                Picker("Format", selection: $selectedFormat) {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 12) {
                    Label("CSV: Spreadsheet compatible", systemImage: "tablecells")
                    Label("PDF: Printable report", systemImage: "doc.text")
                    Label("JSON: Developer format", systemImage: "curlybraces")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                
                Spacer()
                
                Button(action: {
                    onExport(selectedFormat)
                    dismiss()
                }) {
                    Text("Export")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
