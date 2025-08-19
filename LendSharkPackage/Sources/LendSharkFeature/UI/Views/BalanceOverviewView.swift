import SwiftUI
import CoreData

/// Balance Overview screen matching reference app
public struct BalanceOverviewView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel = BalanceViewModel()
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Transaction.timestamp, ascending: false)],
        animation: .default
    ) private var transactions: FetchedResults<Transaction>
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(spacing: Layout.sectionSpacing) {
                // Total Balance Card
                totalBalanceCard
                
                // Balance Bar Chart
                balanceBarChart
                
                // Account Sections
                paymentAccountsSection
                creditCardsSection
                otherAssetsSection
            }
            .padding()
        }
        .background(Color.appBackground)
        .navigationTitle("Balance")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.calculateBalances(from: Array(transactions))
        }
    }
    
    private var totalBalanceCard: some View {
        VStack(spacing: 8) {
            Text("Total Balance")
                .font(.label)
                .foregroundColor(.textSecondary)
            
            Text(viewModel.formattedTotalBalance)
                .font(.largeAmount)
                .foregroundColor(.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Layout.sectionSpacing)
    }
    
    private var balanceBarChart: some View {
        HStack(spacing: 2) {
            // Assets bar
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.tealAccent)
                .frame(width: viewModel.assetsPercentage * 3, height: 8)
            
            // Debts bar
            if viewModel.debtsPercentage > 0 {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.warningYellow)
                    .frame(width: viewModel.debtsPercentage * 3, height: 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }
    
    private var paymentAccountsSection: some View {
        VStack(alignment: .leading, spacing: Layout.itemSpacing) {
            HStack {
                Text("PAYMENT ACCOUNTS")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                
                Spacer()
                
                Text(viewModel.formattedPaymentAccountsTotal)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            
            VStack(spacing: 0) {
                AccountRow(icon: "dollarsign.circle.fill", 
                          name: "Cash Fund",
                          balance: viewModel.cashFund,
                          color: .incomeGreen)
                
                Divider().background(Color.textSecondary.opacity(0.2))
                
                AccountRow(icon: "building.columns.fill",
                          name: "Money Pro Bank", 
                          balance: viewModel.moneyProBank,
                          color: .tealAccent)
                
                Divider().background(Color.textSecondary.opacity(0.2))
                
                AccountRow(icon: "building.columns",
                          name: "National Bank",
                          balance: viewModel.nationalBank,
                          color: .tealAccent)
            }
            .background(Color.cardBackground)
            .cornerRadius(Layout.cornerRadius)
        }
    }
    
    private var creditCardsSection: some View {
        VStack(alignment: .leading, spacing: Layout.itemSpacing) {
            HStack {
                Text("CREDIT CARDS")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                
                Spacer()
                
                Text(viewModel.formattedCreditCardsTotal)
                    .font(.caption)
                    .foregroundColor(.expenseRed)
            }
            
            VStack(spacing: 0) {
                AccountRow(icon: "creditcard.fill",
                          name: "Money Pro Bank",
                          balance: viewModel.creditCard1,
                          color: .expenseRed)
                
                Divider().background(Color.textSecondary.opacity(0.2))
                
                AccountRow(icon: "creditcard",
                          name: "National Bank",
                          balance: viewModel.creditCard2,
                          color: .expenseRed)
            }
            .background(Color.cardBackground)
            .cornerRadius(Layout.cornerRadius)
        }
    }
    
    private var otherAssetsSection: some View {
        VStack(alignment: .leading, spacing: Layout.itemSpacing) {
            HStack {
                Text("OTHER ASSETS")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                
                Spacer()
                
                Text(viewModel.formattedOtherAssetsTotal)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            
            VStack(spacing: 0) {
                AccountRow(icon: "bicycle",
                          name: "Bike",
                          balance: 1000,
                          color: .tealAccent)
                
                Divider().background(Color.textSecondary.opacity(0.2))
                
                AccountRow(icon: "car.fill",
                          name: "Motorbike",
                          balance: 14500,
                          color: .tealAccent)
                
                Divider().background(Color.textSecondary.opacity(0.2))
                
                AccountRow(icon: "parkingsign.circle.fill",
                          name: "Parking Place",
                          balance: 8900,
                          color: .tealAccent)
                
                Divider().background(Color.textSecondary.opacity(0.2))
                
                AccountRow(icon: "car",
                          name: "Car",
                          balance: 50000,
                          color: .tealAccent)
            }
            .background(Color.cardBackground)
            .cornerRadius(Layout.cornerRadius)
        }
    }
}

/// Individual account row component
struct AccountRow: View {
    let icon: String
    let name: String
    let balance: Double
    let color: Color
    
    var body: some View {
        HStack(spacing: Layout.itemSpacing) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: Layout.iconSize, height: Layout.iconSize)
            
            Text(name)
                .font(.cardTitle)
                .foregroundColor(.textPrimary)
            
            Spacer()
            
            Text(formatCurrency(balance))
                .font(.amount)
                .foregroundColor(balance < 0 ? .expenseRed : .textPrimary)
        }
        .padding(Layout.cardPadding)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = amount.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

/// View model for balance calculations
@MainActor
class BalanceViewModel: ObservableObject {
    @Published var totalBalance: Double = 300462.04
    @Published var assetsPercentage: CGFloat = 0.85
    @Published var debtsPercentage: CGFloat = 0.15
    
    // Payment accounts
    @Published var cashFund: Double = 4020
    @Published var moneyProBank: Double = 17072.97
    @Published var nationalBank: Double = 15416
    
    // Credit cards
    @Published var creditCard1: Double = -5031
    @Published var creditCard2: Double = -340
    
    var formattedTotalBalance: String {
        formatLargeCurrency(totalBalance)
    }
    
    var formattedPaymentAccountsTotal: String {
        let total = cashFund + moneyProBank + nationalBank
        return formatCurrency(total)
    }
    
    var formattedCreditCardsTotal: String {
        let total = creditCard1 + creditCard2
        return "(\(formatCurrency(abs(total))))"
    }
    
    var formattedOtherAssetsTotal: String {
        return "$350,778.50"
    }
    
    func calculateBalances(from transactions: [Transaction]) async {
        // Calculate from actual transactions
        // For now using mock data to match reference
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
    
    private func formatLargeCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

#Preview {
    NavigationStack {
        BalanceOverviewView()
            .preferredColorScheme(.dark)
    }
}
