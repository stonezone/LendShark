import SwiftUI
import CoreData
#if canImport(UIKit)
import UIKit
#endif

/// The Collections View - Intimidating overdue tracking
/// NO rounded corners, sharp edges only per CLAUDE.md
struct CollectionsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Transaction.timestamp, ascending: false)],
        animation: .default
    ) private var transactions: FetchedResults<Transaction>
    
    @State private var debtors: [DebtLedger.DebtorInfo] = []
    @State private var selectedDebtor: DebtLedger.DebtorInfo?
    @State private var showingSettlement = false
    @State private var showingReminderAlert = false
    @State private var reminderText: String = ""
    
    var overdueDebtors: [DebtLedger.DebtorInfo] {
        // Include people with overdue money OR overdue items they borrowed from me
        debtors.filter { debtor in
            let hasOverdueMoney = debtor.daysOverdue > 0 && debtor.owesMe
            let hasOverdueItems = debtor.items.contains { $0.isOverdue && $0.theyHaveMine }
            return hasOverdueMoney || hasOverdueItems
        }
    }
    
    var body: some View {
        ZStack {
            Color.paperYellow.ignoresSafeArea()
            RuledLinesBackground()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    
                    if !overdueDebtors.isEmpty {
                        overdueSection
                    } else {
                        emptyStateSection
                    }
                }
                .padding(20)
            }
        }
        .onAppear { updateDebtors() }
        .onChange(of: transactions.count) { updateDebtors() }
        .sheet(isPresented: $showingSettlement) {
            if let debtor = selectedDebtor {
                SettlementView(debtor: debtor, onDismiss: {
                    showingSettlement = false
                    selectedDebtor = nil
                    updateDebtors()
                })
            }
        }
        .alert("Reminder ready", isPresented: $showingReminderAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(reminderText)
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("COLLECTIONS")
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                    .foregroundColor(.bloodRed)
                    .tracking(2)
                Spacer()
                // Stamp-style badge
                Text("PAST DUE")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(.bloodRed)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .overlay(Rectangle().stroke(Color.bloodRed, lineWidth: 1.5))
                    .rotationEffect(.degrees(-3))
            }
            // Double underline in red
            Rectangle().frame(height: 3).foregroundColor(.bloodRed)
            Rectangle().frame(height: 1).foregroundColor(.bloodRed.opacity(0.5)).padding(.top, 2)
        }
    }
    
    // MARK: - Overdue Section
    private var overdueSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Urgent warning banner
            HStack(spacing: 8) {
                Text("!")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundColor(.paperYellow)
                    .frame(width: 28, height: 28)
                    .background(Color.bloodRed)

                Text("ACTION REQUIRED")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(.bloodRed)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.bloodRed.opacity(0.08))
            .overlay(
                Rectangle()
                    .stroke(Color.bloodRed, lineWidth: 2)
            )
            .rotationEffect(.degrees(-0.3))

            ForEach(overdueDebtors, id: \.name) { debtor in
                overdueDebtorRow(debtor)
            }
        }
    }

    // MARK: - Empty State
    private var emptyStateSection: some View {
        VStack(spacing: 24) {
            // Checkmark stamp
            Text("✓")
                .font(.system(size: 36, weight: .black, design: .monospaced))
                .foregroundColor(.cashGreen)
                .padding(16)
                .overlay(
                    Circle()
                        .stroke(Color.cashGreen, lineWidth: 3)
                )
                .rotationEffect(.degrees(-5))

            VStack(spacing: 8) {
                Text("ALL CLEAR")
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .tracking(3)
                    .foregroundColor(.cashGreen)

                Text("No one ducking you.")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.pencilGray)

                Text("Yet.")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.pencilGray.opacity(0.6))
                    .italic()
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(48)
    }
    
    // MARK: - Debtor Row
    private func overdueDebtorRow(_ debtor: DebtLedger.DebtorInfo) -> some View {
        let overdueItems = debtor.items.filter { $0.isOverdue && $0.theyHaveMine }
        let hasOverdueMoney = debtor.daysOverdue > 0 && debtor.totalOwed > 0
        let maxDaysOverdue = max(debtor.daysOverdue, overdueItems.map { $0.daysOverdue }.max() ?? 0)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(debtor.name.uppercased())
                        .font(.system(size: 17, weight: .bold, design: .monospaced))
                        .foregroundColor(.bloodRed)

                    // Show money if overdue
                    if hasOverdueMoney {
                        HStack(spacing: 4) {
                            Text(formatAmount(debtor.totalOwed))
                                .font(.system(size: 20, weight: .black, design: .monospaced))
                            Text("•")
                                .foregroundColor(.bloodRed.opacity(0.5))
                            Text("\(debtor.daysOverdue)d")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(.bloodRed)
                    }

                    // Show overdue items
                    ForEach(overdueItems, id: \.name) { item in
                        HStack(spacing: 4) {
                            Text("🔧")
                                .font(.system(size: 12))
                            Text(item.name.uppercased())
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                            Text("•")
                                .foregroundColor(.bloodRed.opacity(0.5))
                            Text("\(item.daysOverdue)d")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(.bloodRed)
                    }
                }

                Spacer()

                // Escalation stamp with rotation
                Text(escalationLevel(for: maxDaysOverdue))
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(.bloodRed.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.bloodRed.opacity(0.1))
                    .overlay(Rectangle().stroke(Color.bloodRed.opacity(0.6), lineWidth: 1.5))
                    .rotationEffect(.degrees(-4))
            }

            // Action buttons - stark and direct
            HStack(spacing: 10) {
                Button(action: { sendReminder(to: debtor) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 10))
                        Text("REMIND")
                    }
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundColor(.paperYellow)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.bloodRed)
                }

                Button(action: {
                    selectedDebtor = debtor
                    showingSettlement = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                        // Show RETURNED if only items, PAID if money
                        Text(hasOverdueMoney ? "PAID" : "RETURNED")
                    }
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundColor(.paperYellow)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.cashGreen)
                }

                Spacer()

                Button(action: { writeOffDebt(for: debtor) }) {
                    Text("×")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.pencilGray)
                        .frame(width: 32, height: 32)
                        .overlay(Rectangle().stroke(Color.pencilGray.opacity(0.5), lineWidth: 1))
                }
            }
        }
        .padding(14)
        .background(Color.bloodRed.opacity(0.04))
        .overlay(
            Rectangle()
                .stroke(Color.bloodRed.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Helpers
    
    private func escalationLevel(for days: Int) -> String {
        switch days {
        case 1...13: return "REMINDER"
        case 14...29: return "OVERDUE"
        case 30...59: return "FINAL"
        default: return "COLLECTIONS"
        }
    }
    
    private func formatAmount(_ amount: Decimal) -> String {
        "$\(NSDecimalNumber(decimal: amount).intValue)"
    }
    
    private func sendReminder(to debtor: DebtLedger.DebtorInfo) {
        // Generate a short, in-character reminder line
        let amountDouble = NSDecimalNumber(decimal: debtor.totalOwed).doubleValue
        let formatted = String(format: "%.2f", amountDouble)
        let message = "Hey \(debtor.name), about that $\(formatted) you still owe me."
        
        reminderText = message
        
        #if canImport(UIKit)
        UIPasteboard.general.string = message
        #endif
        
        showingReminderAlert = true
    }
    
    private func writeOffDebt(for debtor: DebtLedger.DebtorInfo) {
        do {
            try Transaction.markAsDefaulted(person: debtor.name, in: viewContext)
            updateDebtors()
        } catch {
            // Silent fail - loan shark doesn't care
        }
    }
    
    private func updateDebtors() {
        debtors = DebtLedger.getDebtors(from: Array(transactions))
    }
}

#Preview {
    CollectionsView()
        .preferredColorScheme(.light)
}
