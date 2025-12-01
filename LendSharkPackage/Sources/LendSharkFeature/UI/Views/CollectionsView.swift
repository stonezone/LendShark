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
        debtors.filter { $0.isOverdue && $0.owesMe }
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
        .onChange(of: transactions.count) { _ in updateDebtors() }
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("COLLECTIONS")
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                    .foregroundColor(.bloodRed)
                Spacer()
                Text("PAST DUE")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.bloodRed)
            }
            Rectangle().frame(height: 3).foregroundColor(.bloodRed)
        }
    }
    
    // MARK: - Overdue Section
    private var overdueSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("!")
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .foregroundColor(.bloodRed)
                Text("IMMEDIATE ACTION REQUIRED")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.bloodRed)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.bloodRed.opacity(0.1))
            .overlay(Rectangle().stroke(Color.bloodRed, lineWidth: 2))
            
            ForEach(overdueDebtors, id: \.name) { debtor in
                overdueDebtorRow(debtor)
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyStateSection: some View {
        VStack(spacing: 16) {
            Text("✓")
                .font(.system(size: 48, weight: .black, design: .monospaced))
                .foregroundColor(.cashGreen)
            Text("ALL DEBTS COLLECTED")
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(.cashGreen)
            Text("No one ducking you right now.")
                .font(.system(size: 16, design: .monospaced))
                .foregroundColor(.pencilGray)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
    
    // MARK: - Debtor Row
    private func overdueDebtorRow(_ debtor: DebtLedger.DebtorInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(debtor.name)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.bloodRed)
                    
                    Text("\(formatAmount(debtor.totalOwed)) • \(debtor.daysOverdue) DAYS")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.bloodRed)
                }
                
                Spacer()

                // Stamp showing escalation level
                Text(escalationLevel(for: debtor.daysOverdue))
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundColor(.bloodRed)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .overlay(
                        Rectangle()
                            .stroke(Color.bloodRed, lineWidth: 1)
                    )
            }
            
            // Action buttons - sharp edges
            HStack(spacing: 12) {
                Button(action: { sendReminder(to: debtor) }) {
                    Text("REMIND")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.paperYellow)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.bloodRed)
                }
                
                Button(action: {
                    selectedDebtor = debtor
                    showingSettlement = true
                }) {
                    Text("SETTLED")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.paperYellow)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.cashGreen)
                }
                
                Button(action: { writeOffDebt(for: debtor) }) {
                    Text("WRITE OFF")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.paperYellow)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.pencilGray)
                }
            }
        }
        .padding(16)
        .background(Color.bloodRed.opacity(0.05))
        .overlay(
            Rectangle()
                .stroke(Color.bloodRed.opacity(0.3), lineWidth: 1)
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
