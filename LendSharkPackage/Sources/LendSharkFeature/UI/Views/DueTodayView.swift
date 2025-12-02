import SwiftUI
import CoreData

/// Today's Collections - Morning briefing for the loan shark
/// Shows debts due today and tomorrow with quick action buttons
struct DueTodayView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Transaction.dueDate, ascending: true)],
        predicate: NSPredicate(format: "settled == false AND dueDate != nil"),
        animation: .default
    ) private var transactionsWithDueDates: FetchedResults<Transaction>
    
    @State private var showingSMSComposer = false
    @State private var selectedPhone: String = ""
    @State private var selectedMessage: String = ""
    
    private var calendar: Calendar { Calendar.current }
    
    var body: some View {
        ZStack {
            RuledLinesBackground()
            
            VStack(alignment: .leading, spacing: 0) {
                // Header
                headerSection
                
                // Total on deck summary
                if totalOnDeck > 0 {
                    totalSummary
                }
                
                // Divider
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.inkBlack.opacity(0.3))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                
                if dueToday.isEmpty && dueTomorrow.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            if !dueToday.isEmpty {
                                dueTodaySection
                            }
                            if !dueTomorrow.isEmpty {
                                dueTomorrowSection
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        #if os(iOS)
        .smsComposer(
            isPresented: $showingSMSComposer,
            recipient: selectedPhone,
            body: selectedMessage
        )
        #endif
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("TODAY'S COLLECTIONS")
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .foregroundColor(.inkBlack)
                    .tracking(2)
                Spacer()
                Text(Date.now.formatted(date: .abbreviated, time: .omitted).uppercased())
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.pencilGray)
            }
            // Double underline
            Rectangle().frame(height: 2).foregroundColor(.inkBlack)
            Rectangle().frame(height: 1).foregroundColor(.inkBlack).padding(.top, 2)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
    
    // MARK: - Total Summary
    
    private var totalSummary: some View {
        HStack(alignment: .center) {
            Text("TOTAL ON DECK")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundColor(.bloodRed)
                .tracking(1)
            
            Text(String(repeating: "·", count: 8))
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.pencilGray)
            
            Spacer()
            
            Text(formatCurrency(totalOnDeck))
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundColor(.bloodRed)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.bloodRed.opacity(0.08))
        .overlay(Rectangle().stroke(Color.bloodRed, lineWidth: 1))
        .rotationEffect(.degrees(-0.5))
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Text("—")
                .font(.system(size: 48, weight: .ultraLight, design: .monospaced))
                .foregroundColor(.pencilGray.opacity(0.4))
            
            Text("NOTHING DUE")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .tracking(3)
                .foregroundColor(.pencilGray)
            
            Text("No collections scheduled for today or tomorrow.")
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.pencilGray.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Due Today Section
    
    private var dueTodaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Stamp-style header
            Text("DUE TODAY")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundColor(.bloodRed)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.bloodRed.opacity(0.1))
                .overlay(Rectangle().stroke(Color.bloodRed, lineWidth: 1.5))
                .rotationEffect(.degrees(-1.5))
                .padding(.bottom, 4)
            
            ForEach(groupedByPerson(dueToday), id: \.name) { debtor in
                collectionRow(debtor: debtor, urgent: true)
            }
        }
    }
    
    // MARK: - Due Tomorrow Section
    
    private var dueTomorrowSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Stamp-style header
            Text("DUE TOMORROW")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundColor(.inkBlack)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.inkBlack.opacity(0.1))
                .overlay(Rectangle().stroke(Color.inkBlack, lineWidth: 1.5))
                .rotationEffect(.degrees(1.0))
                .padding(.bottom, 4)
            
            ForEach(groupedByPerson(dueTomorrow), id: \.name) { debtor in
                collectionRow(debtor: debtor, urgent: false)
            }
        }
    }
    
    // MARK: - Collection Row
    
    private func collectionRow(debtor: DebtorDue, urgent: Bool) -> some View {
        HStack(alignment: .center, spacing: 0) {
            // Name
            Text(debtor.name.uppercased())
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundColor(.inkBlack)
                .lineLimit(1)
            
            // Dotted leader
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
            
            // Amount
            Text(formatCurrency(debtor.totalAmount))
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(urgent ? .bloodRed : .inkBlack)
            
            #if os(iOS)
            // Phone action buttons (if phone exists)
            if let phone = debtor.phoneNumber, !phone.isEmpty {
                PhoneActionButtonsCompact(
                    phoneNumber: phone,
                    personName: debtor.name,
                    amount: debtor.totalAmount,
                    dueDate: debtor.dueDate
                )
                .padding(.leading, 8)
            }
            #endif
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(urgent ? Color.bloodRed.opacity(0.06) : Color.clear)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(.inkBlack.opacity(0.15)),
            alignment: .bottom
        )
    }
    
    // MARK: - Computed Properties
    
    private var dueToday: [Transaction] {
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        return transactionsWithDueDates.filter { tx in
            guard let due = tx.dueDate else { return false }
            let dueStart = calendar.startOfDay(for: due)
            return dueStart >= today && dueStart < tomorrow
        }
    }
    
    private var dueTomorrow: [Transaction] {
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let dayAfter = calendar.date(byAdding: .day, value: 2, to: today)!
        
        return transactionsWithDueDates.filter { tx in
            guard let due = tx.dueDate else { return false }
            let dueStart = calendar.startOfDay(for: due)
            return dueStart >= tomorrow && dueStart < dayAfter
        }
    }
    
    private var totalOnDeck: Decimal {
        let todayAmounts = dueToday.compactMap { $0.amount?.decimalValue }.reduce(0, +)
        let tomorrowAmounts = dueTomorrow.compactMap { $0.amount?.decimalValue }.reduce(0, +)
        return todayAmounts + tomorrowAmounts
    }
    
    // MARK: - Helpers
    
    private struct DebtorDue: Identifiable {
        let id = UUID()
        let name: String
        let totalAmount: Decimal
        let phoneNumber: String?
        let dueDate: Date?
    }
    
    private func groupedByPerson(_ transactions: [Transaction]) -> [DebtorDue] {
        var grouped: [String: (amount: Decimal, phone: String?, dueDate: Date?)] = [:]
        
        for tx in transactions {
            let name = tx.party ?? "Unknown"
            let amount = tx.amount?.decimalValue ?? 0
            let existing = grouped[name] ?? (amount: 0, phone: nil, dueDate: nil)
            grouped[name] = (
                amount: existing.amount + amount,
                phone: tx.phoneNumber ?? existing.phone,
                dueDate: tx.dueDate ?? existing.dueDate
            )
        }
        
        return grouped.map { DebtorDue(name: $0.key, totalAmount: $0.value.amount, phoneNumber: $0.value.phone, dueDate: $0.value.dueDate) }
            .sorted { $0.totalAmount > $1.totalAmount }
    }
    
    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0"
    }
}

#Preview {
    DueTodayView()
        .preferredColorScheme(.light)
}
