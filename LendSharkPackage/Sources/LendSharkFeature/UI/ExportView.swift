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

        // Section: They owe me (money)
        let theyOweMe = debtors.filter { $0.owesMe && $0.totalOwed > 0 }
        if !theyOweMe.isEmpty {
            lines.append("")
            lines.append("THEY OWE ME:")
            var total: Decimal = 0
            for debtor in theyOweMe {
                let amount = NSDecimalNumber(decimal: debtor.totalOwed).doubleValue
                lines.append("  \(debtor.name): $\(String(format: "%.2f", amount))")
                total += debtor.totalOwed
            }
            let totalAmount = NSDecimalNumber(decimal: total).doubleValue
            lines.append("  SUBTOTAL: $\(String(format: "%.2f", totalAmount))")
        }

        // Section: I owe them (money)
        let iOwe = debtors.filter { $0.iOwe && $0.totalOwed > 0 }
        if !iOwe.isEmpty {
            lines.append("")
            lines.append("I OWE:")
            var total: Decimal = 0
            for debtor in iOwe {
                let amount = NSDecimalNumber(decimal: debtor.totalOwed).doubleValue
                lines.append("  \(debtor.name): $\(String(format: "%.2f", amount))")
                total += debtor.totalOwed
            }
            let totalAmount = NSDecimalNumber(decimal: total).doubleValue
            lines.append("  SUBTOTAL: $\(String(format: "%.2f", totalAmount))")
        }

        // Section: Items they have (borrowed from me)
        let theyHaveMyItems = debtors.flatMap { debtor in
            debtor.items.filter { $0.theyHaveMine }.map { (debtor.name, $0) }
        }
        if !theyHaveMyItems.isEmpty {
            lines.append("")
            lines.append("ITEMS THEY HAVE:")
            for (name, item) in theyHaveMyItems {
                let overdueText = item.isOverdue ? " [OVERDUE \(item.daysOverdue)d]" : ""
                lines.append("  \(name): \(item.name)\(overdueText)")
            }
        }

        // Section: Items I have (borrowed from them)
        let iHaveTheirItems = debtors.flatMap { debtor in
            debtor.items.filter { !$0.theyHaveMine }.map { (debtor.name, $0) }
        }
        if !iHaveTheirItems.isEmpty {
            lines.append("")
            lines.append("ITEMS I HAVE:")
            for (name, item) in iHaveTheirItems {
                let overdueText = item.isOverdue ? " [OVERDUE \(item.daysOverdue)d]" : ""
                lines.append("  From \(name): \(item.name)\(overdueText)")
            }
        }

        // Summary
        lines.append("")
        lines.append("-----------------")
        let totalOwedToMe = theyOweMe.reduce(Decimal(0)) { $0 + $1.totalOwed }
        let totalIOwe = iOwe.reduce(Decimal(0)) { $0 + $1.totalOwed }
        let netAmount = totalOwedToMe - totalIOwe

        lines.append("NET: \(netAmount >= 0 ? "+" : "")$\(String(format: "%.2f", NSDecimalNumber(decimal: netAmount).doubleValue))")
        lines.append("Items out: \(theyHaveMyItems.count)")
        lines.append("Items in: \(iHaveTheirItems.count)")

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
