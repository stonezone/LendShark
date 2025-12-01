import SwiftUI
import CoreData

/// Settlement View - Quick and direct debt resolution
struct SettlementView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    let debtor: DebtLedger.DebtorInfo
    let onDismiss: () -> Void
    
    @State private var partialAmount: String = ""
    @State private var showingPartialInput = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                // Aged paper background with ruled lines
                RuledLinesBackground()
                
                VStack(spacing: 30) {
                    // Header
                    headerSection
                    
                    // Amount owed display
                    amountSection
                    
                    // Settlement options
                    settlementOptionsSection
                    
                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle("SETTLEMENT")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "person.fill.checkmark")
                    .font(.title)
                    .foregroundColor(.inkBlack)
                
                Text("SETTLE DEBT")
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .foregroundColor(.inkBlack)
            }
            
            Text(debtor.name)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(debtor.isOverdue ? .bloodRed : .inkBlack)
            
            if debtor.isOverdue {
                Text("\(debtor.daysOverdue) days overdue")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.bloodRed)
            }
        }
    }
    
    // MARK: - Amount Section
    private var amountSection: some View {
        VStack(spacing: 12) {
            Text("AMOUNT OWED")
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundColor(.pencilGray)
            
            Text(formatAmount(debtor.totalOwed))
                .font(.system(size: 36, weight: .black, design: .monospaced))
                .foregroundColor(debtor.isOverdue ? .bloodRed : .inkBlack)

            if debtor.isOverdue {
                Text("PAST DUE")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundColor(.bloodRed)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .overlay(
                        Rectangle()
                            .stroke(Color.bloodRed, lineWidth: 1)
                    )
            } else {
                Text("SETTLEMENT")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundColor(.inkBlack)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .overlay(
                        Rectangle()
                            .stroke(Color.inkBlack, lineWidth: 1)
                    )
            }
        }
        .padding(20)
    }
    
    // MARK: - Settlement Options
    private var settlementOptionsSection: some View {
        VStack(spacing: 20) {
            Text("SETTLEMENT OPTIONS")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.inkBlack)
            
            // PAID IN FULL - One tap solution
            Button(action: {
                settleFullAmount()
            }) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                    
                    Text("PAID IN FULL")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                }
                .foregroundColor(.paperYellow)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.cashGreen)
            }
            
            // PARTIAL PAYMENT - Enter amount
            if showingPartialInput {
                partialPaymentSection
            } else {
                Button(action: {
                    showingPartialInput = true
                }) {
                    HStack {
                        Image(systemName: "dollarsign.circle")
                            .font(.title2)
                        
                        Text("PARTIAL PAYMENT")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(.paperYellow)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.orange)
                }
            }
        }
    }
    
    // MARK: - Partial Payment Section
    private var partialPaymentSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("$")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(.inkBlack)
                
                TextField("0.00", text: $partialAmount)
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(.inkBlack)
            }
            
            HStack(spacing: 12) {
                Button(action: {
                    recordPartialPayment()
                }) {
                    Text("RECORD PAYMENT")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.paperYellow)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.cashGreen)
                }
                .disabled(partialAmount.isEmpty)
                
                Button(action: {
                    showingPartialInput = false
                    partialAmount = ""
                }) {
                    Text("CANCEL")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.bloodRed)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
    }
    
    // MARK: - Helper Functions
    
    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0"
    }
    
    private func settleFullAmount() {
        do {
            try Transaction.settleAll(with: debtor.name, in: viewContext)
            AppLogger.transaction.info("Fully settled all debts with \(debtor.name)")
            onDismiss()
        } catch {
            errorMessage = "Failed to settle debt: \(error.localizedDescription)"
            showingError = true
        }
    }
    
    private func recordPartialPayment() {
        guard let amount = Decimal(string: partialAmount), amount > 0 else {
            errorMessage = "Please enter a valid amount"
            showingError = true
            return
        }
        
        guard amount <= debtor.totalOwed else {
            errorMessage = "Amount cannot exceed total debt of \(formatAmount(debtor.totalOwed))"
            showingError = true
            return
        }
        
        do {
            try Transaction.recordPartialPayment(
                person: debtor.name, 
                amount: amount, 
                in: viewContext
            )
            AppLogger.transaction.info("Recorded partial payment of $\(amount) from \(debtor.name)")
            onDismiss()
        } catch {
            errorMessage = "Failed to record payment: \(error.localizedDescription)"
            showingError = true
        }
    }
}

#Preview {
    SettlementView(
        debtor: DebtLedger.DebtorInfo(
            name: "John Smith", 
            totalOwed: 500, 
            daysOverdue: 30
        )
    ) {
        // onDismiss
    }
    .preferredColorScheme(.light)
}
