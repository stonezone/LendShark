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
                // Header - like notebook tab with underline
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("THE LEDGER")
                            .font(.system(size: 28, weight: .black, design: .monospaced))
                            .foregroundColor(.inkBlack)
                            .tracking(2)
                        Spacer()
                        Text(Date.now.formatted(date: .abbreviated, time: .omitted).uppercased())
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(.pencilGray)
                    }
                    // Double underline like old ledger books
                    Rectangle().frame(height: 2).foregroundColor(.inkBlack)
                    Rectangle().frame(height: 1).foregroundColor(.inkBlack).padding(.top, 2)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                // Total outstanding - stamped look
                if totalOutstanding > 0 {
                    HStack(alignment: .center) {
                        Text("ON THE STREET")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundColor(.bloodRed)
                            .tracking(1)

                        // Dotted leader
                        Text(String(repeating: "·", count: 8))
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.pencilGray)

                        Spacer()

                        Text(formatCurrency(totalOutstanding))
                            .font(.system(size: 22, weight: .black, design: .monospaced))
                            .foregroundColor(.bloodRed)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.bloodRed.opacity(0.08))
                    .overlay(Rectangle().stroke(Color.bloodRed, lineWidth: 1))
                    .rotationEffect(.degrees(-0.5)) // Slight tilt like a stamp
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }

                // Divider line (like ruling)
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.inkBlack.opacity(0.3))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                
                if debtors.isEmpty {
                    // Empty state - ominous calm
                    VStack(spacing: 20) {
                        Text("—")
                            .font(.system(size: 48, weight: .ultraLight, design: .monospaced))
                            .foregroundColor(.pencilGray.opacity(0.4))

                        Text("LEDGER IS CLEAN")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .tracking(3)
                            .foregroundColor(.pencilGray)

                        Text("Everyone's square.")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.pencilGray.opacity(0.7))

                        Text("For now.")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.pencilGray.opacity(0.5))
                            .italic()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // The list - NO CARDS, NO FANCY UI
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(debtors, id: \.name) { debtor in
                                NavigationLink(destination: DebtorDetailView(personName: debtor.name)) {
                                    debtorRow(debtor)
                                }
                                .buttonStyle(.plain)
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
    
    /// Single debtor row - stark and direct with dotted leaders
    private func debtorRow(_ debtor: DebtLedger.DebtorInfo) -> some View {
        HStack(alignment: .center, spacing: 0) {
            // Left side - Name with chevron hint
            HStack(spacing: 6) {
                Text(debtor.name.uppercased())
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundColor(.inkBlack)
                    .lineLimit(1)

                // Subtle chevron indicating tappable
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.pencilGray.opacity(0.5))
            }

            // Dotted leader line (classic ledger style)
            GeometryReader { geo in
                let dotCount = Int(geo.size.width / 8)
                Text(String(repeating: "·", count: max(3, dotCount)))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.pencilGray.opacity(0.6))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
            }
            .frame(height: 16)
            .padding(.horizontal, 4)

            // Right side - Amount and stamp
            VStack(alignment: .trailing, spacing: 3) {
                amountText(for: debtor)
                stampText(for: debtor)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(
            debtor.isOverdue
                ? Color.bloodRed.opacity(0.06)
                : Color.clear
        )
        // Bottom border like ledger entry line
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(.inkBlack.opacity(0.15)),
            alignment: .bottom
        )
    }
    
    /// Amount display with proper coloring
    private func amountText(for debtor: DebtLedger.DebtorInfo) -> some View {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        
        let amountString = formatter.string(from: abs(debtor.totalOwed) as NSDecimalNumber) ?? "$0"
        let displayAmount = debtor.iOwe ? "(\(amountString))" : amountString
        
        return VStack(alignment: .trailing, spacing: 0) {
            Text(displayAmount)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(debtor.isOverdue ? .bloodRed : 
                               debtor.owesMe ? .inkBlack : 
                               .cashGreen)
            
            // Show interest breakdown if accrued
            if debtor.hasInterest {
                let intAmt = formatter.string(from: debtor.accruedInterest as NSDecimalNumber) ?? "$0"
                Text("+\(intAmt) int")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.bloodRed)
            }
        }
    }
    
    /// Status text (overdue days or "OK")
    private func statusText(for debtor: DebtLedger.DebtorInfo) -> some View {
        let label: String = {
            if debtor.isOverdue {
                return "\(debtor.daysOverdue)d late"
            } else if debtor.iOwe {
                return "I owe"
            } else {
                return "current"
            }
        }()
        
        return VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundColor(debtor.isOverdue ? .bloodRed : .pencilGray)
            
            // Show notes/collateral if present
            if let notes = debtor.notes, !notes.isEmpty {
                Text(notes)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.pencilGray)
                    .lineLimit(1)
            }
        }
    }

    /// Ink-style stamps for overall status - authentic rubber stamp look
    private func stampText(for debtor: DebtLedger.DebtorInfo) -> some View {
        let text: String
        let color: Color
        let rotation: Double

        if debtor.isOverdue {
            text = "PAST DUE"
            color = .bloodRed
            rotation = -2.5
        } else if debtor.iOwe {
            text = "I OWE"
            color = .cashGreen
            rotation = 1.5
        } else {
            text = "OWES"
            color = .inkBlack
            rotation = -1.0
        }

        return Text(text)
            .font(.system(size: 9, weight: .black, design: .monospaced))
            .tracking(1)
            .foregroundColor(color.opacity(0.85))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.08))
            .overlay(
                Rectangle()
                    .stroke(color.opacity(0.7), lineWidth: 1.5)
            )
            .rotationEffect(.degrees(rotation))
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
    
    /// Total money owed to me (on the street)
    private var totalOutstanding: Decimal {
        debtors.filter { $0.owesMe }.reduce(0) { $0 + $1.totalOwed }
    }
    
    /// Format currency
    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0"
    }
}

#Preview {
    LedgerView()
        .preferredColorScheme(.light)
}
