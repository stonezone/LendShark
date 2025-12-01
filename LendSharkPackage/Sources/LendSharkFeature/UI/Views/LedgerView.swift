import SwiftUI
import CoreData

/// The Ledger - Shows who owes what in stark simplicity
struct LedgerView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Transaction.timestamp, ascending: false)],
        animation: .default
    ) private var transactions: FetchedResults<Transaction>
    
    @State private var debtors: [DebtLedger.DebtorInfo] = []
    
    var body: some View {
        ZStack {
            // Aged paper background with ruled lines
            RuledLinesBackground()
            
            VStack(alignment: .leading, spacing: 0) {
                // Header - like notebook tab
                HStack {
                    Text("THE LEDGER")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.inkBlack)
                    Spacer()
                    Text(Date.now.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.pencilGray)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)
                
                // Divider line (like ruling)
                Rectangle()
                    .frame(height: 2)
                    .foregroundColor(.inkBlack)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                
                if debtors.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Text("LEDGER IS CLEAN")
                            .font(.system(size: 18, weight: .medium, design: .monospaced))
                            .foregroundColor(.pencilGray)
                        
                        Text("Everyone's square. For now.")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.pencilGray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // The list - NO CARDS, NO FANCY UI
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(debtors, id: \.name) { debtor in
                                debtorRow(debtor)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .onAppear {
            updateDebtors()
        }
        .onChange(of: transactions.count) { _ in
            updateDebtors()
        }
    }
    
    /// Single debtor row - stark and direct
    private func debtorRow(_ debtor: DebtLedger.DebtorInfo) -> some View {
        HStack(alignment: .center, spacing: 0) {
            // Name (left aligned)
            Text(debtor.name)
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundColor(.inkBlack)
                .lineLimit(1)
            
            // Dots (fill space)
            HStack(spacing: 2) {
                ForEach(0..<calculateDotCount(for: debtor), id: \.self) { _ in
                    Text(".")
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundColor(.pencilGray)
                }
            }
            
            // Amount and status (right aligned)
            VStack(alignment: .trailing, spacing: 2) {
                amountText(for: debtor)
                statusText(for: debtor)
                stampText(for: debtor)
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    /// Amount display with proper coloring
    private func amountText(for debtor: DebtLedger.DebtorInfo) -> some View {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$" // TODO: Use settings currency
        
        let amountString = formatter.string(from: abs(debtor.totalOwed) as NSDecimalNumber) ?? "$0"
        let displayAmount = debtor.iOwe ? "(\(amountString))" : amountString
        
        return Text(displayAmount)
            .font(.system(size: 16, weight: .bold, design: .monospaced))
            .foregroundColor(debtor.isOverdue ? .bloodRed : 
                           debtor.owesMe ? .inkBlack : 
                           .cashGreen)
    }
    
    /// Status text (overdue days or "OK")
    private func statusText(for debtor: DebtLedger.DebtorInfo) -> some View {
        let statusText: String
        if debtor.isOverdue {
            statusText = "(\(debtor.daysOverdue) days)"
        } else if debtor.iOwe {
            statusText = "(I owe)"
        } else {
            statusText = "(square)"
        }
        
        return Text(statusText)
            .font(.system(size: 12, weight: .regular, design: .monospaced))
            .foregroundColor(debtor.isOverdue ? .bloodRed : .pencilGray)
    }

    /// Ink-style stamps for overall status
    private func stampText(for debtor: DebtLedger.DebtorInfo) -> some View {
        let text: String
        let color: Color

        if debtor.isOverdue {
            text = "PAST DUE"
            color = .bloodRed
        } else if debtor.iOwe {
            text = "I OWE"
            color = .cashGreen
        } else {
            text = "OWES ME"
            color = .inkBlack
        }

        return Text(text)
            .font(.system(size: 11, weight: .black, design: .monospaced))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .overlay(
                Rectangle()
                    .stroke(color, lineWidth: 1)
            )
    }
    
    /// Calculate number of dots to fill space (approximation)
    private func calculateDotCount(for debtor: DebtLedger.DebtorInfo) -> Int {
        // Rough calculation based on character widths; assume typical phone width
        let screenWidth: CGFloat = 320
        let nameWidth = CGFloat(debtor.name.count) * 9 // approx char width
        let amountWidth = CGFloat(120) // rough amount + status width
        let availableWidth = screenWidth - nameWidth - amountWidth
        let dotWidth: CGFloat = 6 // approx dot width
        
        return max(3, Int(availableWidth / dotWidth))
    }
    
    /// Update debtors list from transactions
    private func updateDebtors() {
        let transactionArray = Array(transactions)
        debtors = DebtLedger.getDebtors(from: transactionArray)
    }
}

#Preview {
    LedgerView()
        .preferredColorScheme(.light)
}
