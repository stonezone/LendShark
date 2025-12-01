import SwiftUI

// MARK: - Collections View (Overdue Debts)
struct CollectionsView: View {
    @EnvironmentObject var debtStore: DebtStore
    @State private var showingSettleAlert = false
    @State private var debtorToSettle: String = ""
    @State private var showingWriteOffAlert = false
    
    private var overdueDebts: [GroupedDebtor] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        
        let groupedOverdue = Dictionary(grouping: debtStore.debts.filter { debt in
            !debt.isSettled && debt.dateAdded < cutoffDate && debt.amount > 0
        }) { debt in
            debt.name.uppercased()
        }
        
        return groupedOverdue.map { (name, transactions) in
            let totalAmount = transactions.reduce(0) { $0 + $1.amount }
            let oldestDate = transactions.map { $0.dateAdded }.min() ?? Date()
            let daysOverdue = Calendar.current.dateComponents([.day], from: oldestDate, to: Date()).day ?? 0
            
            return GroupedDebtor(
                name: name,
                totalAmount: totalAmount,
                transactionCount: transactions.count,
                daysOverdue: daysOverdue,
                hasOverdueTransactions: true,
                transactions: transactions.sorted { $0.dateAdded < $1.dateAdded }
            )
        }.sorted { $0.daysOverdue > $1.daysOverdue }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("COLLECTIONS")
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "8B0000"))
                .padding(.top)
                .padding(.horizontal)
            
            Rectangle()
                .frame(height: 3)
                .foregroundColor(Color(hex: "8B0000"))
                .padding(.horizontal)
                .padding(.bottom, 16)
            
            if overdueDebts.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(Color(hex: "2E7D32"))
                    
                    Text("ALL CLEAR")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "2E7D32"))
                    
                    Text("No overdue debts")
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundColor(Color(hex: "6B6B6B"))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("\(overdueDebts.count) DEBTORS OVERDUE")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "8B0000"))
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(overdueDebts) { debtor in
                            overdueDebtorRow(debtor)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .background(Color(hex: "F4E8D0"))
        .alert("Settle All Debts", isPresented: $showingSettleAlert) {
            Button("Cancel", role: .cancel) { }
            Button("SETTLE ALL", role: .destructive) {
                debtStore.settleAllDebtsFor(name: debtorToSettle)
            }
        } message: {
            Text("Mark all debts for \(debtorToSettle) as settled?")
        }
        .alert("Write Off Debt", isPresented: $showingWriteOffAlert) {
            Button("Cancel", role: .cancel) { }
            Button("WRITE OFF", role: .destructive) {
                debtStore.settleAllDebtsFor(name: debtorToSettle)
            }
        } message: {
            Text("Write off all debts for \(debtorToSettle)? This cannot be undone.")
        }
    }
    
    private func overdueDebtorRow(_ debtor: GroupedDebtor) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with name and amount
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(debtor.name)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "8B0000"))
                    
                    Text("\(debtor.daysOverdue) DAYS OVERDUE")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color(hex: "8B0000"))
                        .cornerRadius(4)
                }
                
                Spacer()
                
                Text(formatAmount(debtor.totalAmount))
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "8B0000"))
            }
            
            // Action buttons
            HStack(spacing: 8) {
                Button("REMIND") {
                    sendReminder(debtor.name)
                }
                .buttonStyle(ActionButtonStyle(color: Color(hex: "1A1A1A")))
                
                Button("SETTLE ALL") {
                    debtorToSettle = debtor.name
                    showingSettleAlert = true
                }
                .buttonStyle(ActionButtonStyle(color: Color(hex: "2E7D32")))
                
                Button("WRITE OFF") {
                    debtorToSettle = debtor.name
                    showingWriteOffAlert = true
                }
                .buttonStyle(ActionButtonStyle(color: Color(hex: "8B0000")))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.9))
                .overlay(
                    Rectangle()
                        .frame(width: 4)
                        .foregroundColor(Color(hex: "8B0000"))
                    , alignment: .leading
                )
        )
    }
    
    private func sendReminder(_ name: String) {
        // Simple haptic feedback to simulate sending reminder
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // In a real app, this would send an actual notification/text
        print("Reminder sent to \(name)")
    }
    
    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        return formatter.string(from: abs(amount) as NSNumber) ?? "$0"
    }
}

// MARK: - Action Button Style
struct ActionButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color)
            .cornerRadius(6)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}