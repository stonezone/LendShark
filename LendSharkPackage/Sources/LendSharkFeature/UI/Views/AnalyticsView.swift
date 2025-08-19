import SwiftUI
import Charts

/// Analytics view with expense breakdown matching reference app
public struct AnalyticsView: View {
    @StateObject private var viewModel = AnalyticsViewModel()
    @State private var selectedDateRange = 0
    
    private let dateRanges = ["This Month", "Last 3 Months", "This Year", "All Time"]
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(spacing: Layout.sectionSpacing) {
                // Date range selector
                dateRangeSelector
                
                // Total expenses card
                totalExpensesCard
                
                // Donut chart
                expenseDonutChart
                
                // Category breakdown
                categoryBreakdownList
            }
            .padding()
        }
        .background(Color.appBackground)
        .navigationTitle("Expenses")
        .navigationBarTitleDisplayMode(.large)
    }
    
    private var dateRangeSelector: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Begin")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                
                Spacer()
                
                Text("End")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            
            HStack {
                Text(viewModel.startDate)
                    .font(.cardTitle)
                    .foregroundColor(.textPrimary)
                
                Spacer()
                
                Text(viewModel.endDate)
                    .font(.cardTitle)
                    .foregroundColor(.textPrimary)
            }
            
            Picker("Date Range", selection: $selectedDateRange) {
                ForEach(0..<dateRanges.count, id: \.self) { index in
                    Text(dateRanges[index]).tag(index)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.top, 8)
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(Layout.cornerRadius)
    }
    
    private var totalExpensesCard: some View {
        VStack(spacing: 8) {
            Text("TOTAL EXPENSES")
                .font(.caption)
                .foregroundColor(.textSecondary)
            
            Text(viewModel.formattedTotalExpenses)
                .font(.largeAmount)
                .foregroundColor(.expenseRed)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(Layout.cornerRadius)
    }
    
    private var expenseDonutChart: some View {
        ZStack {
            // Donut chart segments
            ForEach(viewModel.expenseCategories.indices, id: \.self) { index in
                let category = viewModel.expenseCategories[index]
                let startAngle = viewModel.startAngle(for: index)
                let endAngle = viewModel.endAngle(for: index)
                
                Path { path in
                    path.addArc(
                        center: CGPoint(x: 150, y: 150),
                        radius: 100,
                        startAngle: startAngle,
                        endAngle: endAngle,
                        clockwise: false
                    )
                }
                .stroke(category.color, lineWidth: 40)
            }
            
            // Center text
            VStack(spacing: 4) {
                Text(viewModel.formattedTotalExpenses)
                    .font(.sectionTitle)
                    .foregroundColor(.textPrimary)
                
                Text("EXPENSES")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
        }
        .frame(height: 300)
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(Layout.cornerRadius)
    }
    
    private var categoryBreakdownList: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.expenseCategories) { category in
                HStack(spacing: Layout.itemSpacing) {
                    // Color indicator
                    Circle()
                        .fill(category.color)
                        .frame(width: 12, height: 12)
                    
                    // Category name
                    Text(category.name)
                        .font(.cardTitle)
                        .foregroundColor(.textPrimary)
                    
                    Spacer()
                    
                    // Percentage
                    Text("\(Int(category.percentage))%")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                        .frame(width: 40, alignment: .trailing)
                    
                    // Amount
                    Text(formatCurrency(category.amount))
                        .font(.amount)
                        .foregroundColor(.textPrimary)
                        .frame(width: 80, alignment: .trailing)
                }
                .padding()
                
                if category.id != viewModel.expenseCategories.last?.id {
                    Divider().background(Color.textSecondary.opacity(0.2))
                }
            }
        }
        .background(Color.cardBackground)
        .cornerRadius(Layout.cornerRadius)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

/// Expense category model
struct ExpenseCategory: Identifiable {
    let id = UUID()
    let name: String
    let amount: Double
    let percentage: Double
    let color: Color
}

/// Analytics view model
@MainActor
class AnalyticsViewModel: ObservableObject {
    @Published var startDate = "Jan 1, 2023"
    @Published var endDate = "Dec 31, 2023"
    @Published var totalExpenses: Double = 48529
    
    @Published var expenseCategories: [ExpenseCategory] = [
        ExpenseCategory(name: "Home", amount: 14073, percentage: 29, color: Color.orange),
        ExpenseCategory(name: "Debt", amount: 10676, percentage: 22, color: Color.purple),
        ExpenseCategory(name: "Travelling", amount: 9706, percentage: 20, color: Color.green),
        ExpenseCategory(name: "Clothing", amount: 5823, percentage: 12, color: Color.blue),
        ExpenseCategory(name: "Cafe", amount: 2912, percentage: 6, color: Color.brown),
        ExpenseCategory(name: "Education", amount: 1941, percentage: 4, color: Color.pink),
        ExpenseCategory(name: "Car", amount: 1456, percentage: 3, color: Color.teal),
        ExpenseCategory(name: "Utilities", amount: 1942, percentage: 4, color: Color.indigo)
    ]
    
    var formattedTotalExpenses: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 0
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: totalExpenses)) ?? "$0"
    }
    
    func startAngle(for index: Int) -> Angle {
        let percentagesBefore = expenseCategories[0..<index].map { $0.percentage }.reduce(0, +)
        return Angle(degrees: -90 + (percentagesBefore * 3.6))
    }
    
    func endAngle(for index: Int) -> Angle {
        let percentagesIncluding = expenseCategories[0...index].map { $0.percentage }.reduce(0, +)
        return Angle(degrees: -90 + (percentagesIncluding * 3.6))
    }
}

#Preview {
    NavigationStack {
        AnalyticsView()
            .preferredColorScheme(.dark)
    }
}
