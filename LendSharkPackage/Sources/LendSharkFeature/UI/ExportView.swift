import SwiftUI
import CoreData

/// Simple export screen - generates an "invoice" style summary.
public struct ExportView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Transaction.timestamp, ascending: false)],
        animation: .default
    ) private var transactions: FetchedResults<Transaction>
    
    @State private var isExporting = false
    @State private var lastSummary: String = ""
    
    public init() {}
    
    public var body: some View {
        ZStack {
            RuledLinesBackground()
            
            VStack(alignment: .leading, spacing: 16) {
            Text("EXPORT")
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(.inkBlack)
            
            Text("OUTSTANDING DEBTS")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.inkBlack)
            
            if transactions.isEmpty {
                Text("Nothing on the books to print.")
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .foregroundColor(.pencilGray)
            } else {
                ScrollView {
                    Text(summaryText)
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundColor(.inkBlack)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            Button(action: performExport) {
                Text(isExporting ? "STAMPING..." : "EXPORT LEDGER")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.paperYellow)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(transactions.isEmpty ? Color.pencilGray : Color.inkBlack)
            }
            .disabled(transactions.isEmpty || isExporting)
            
            Spacer()
            }
            .padding(24)
        }
    }
    
    private var summaryText: String {
        if !lastSummary.isEmpty { return lastSummary }
        
        var lines: [String] = []
        lines.append("Date: \(Date.now.formatted(date: .abbreviated, time: .omitted))")
        lines.append("-----------------")
        
        let debtors = DebtLedger.getDebtors(from: Array(transactions))
        var total: Decimal = 0
        
        for debtor in debtors where debtor.totalOwed > 0 {
            let amount = NSDecimalNumber(decimal: debtor.totalOwed).doubleValue
            lines.append("\(debtor.name): $\(String(format: "%.2f", amount))")
            total += debtor.totalOwed
        }
        
        lines.append("-----------------")
        let totalAmount = NSDecimalNumber(decimal: total).doubleValue
        lines.append("TOTAL DUE: $\(String(format: "%.2f", totalAmount))")
        
        return lines.joined(separator: "\n")
    }
    
    private func performExport() {
        isExporting = true
        lastSummary = summaryText
        
        Task {
            let dtoList = Array(transactions).map { transaction in
                TransactionDTO(
                    id: transaction.id ?? UUID(),
                    party: transaction.party ?? "",
                    amount: transaction.amount as? Decimal,
                    item: transaction.item,
                    direction: TransactionDTO.TransactionDirection(rawValue: Int(transaction.direction)) ?? .lent,
                    isItem: transaction.isItem,
                    settled: transaction.settled,
                    timestamp: transaction.timestamp ?? Date(),
                    dueDate: transaction.dueDate,
                    notes: transaction.notes,
                    cloudKitRecordID: transaction.cloudKitRecordID
                )
            }
            
            let service = ExportService()
            _ = try? await service.exportTransactions(dtoList, format: .pdf)
            isExporting = false
        }
    }
}
