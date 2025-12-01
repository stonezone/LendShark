import SwiftUI
import UserNotifications

// MARK: - Data Store
class DebtStore: ObservableObject {
    @Published var debts: [DebtRecord] = []
    
    private let userDefaults = UserDefaults.standard
    private let debtsKey = "SavedDebts"
    
    init() {
        loadDebts()
    }
    
    private func loadDebts() {
        if let data = userDefaults.data(forKey: debtsKey),
           let decodedDebts = try? JSONDecoder().decode([DebtRecord].self, from: data) {
            self.debts = decodedDebts
        }
    }
    
    private func saveDebts() {
        if let encoded = try? JSONEncoder().encode(debts) {
            userDefaults.set(encoded, forKey: debtsKey)
        }
    }
    
    func addDebt(name: String, amount: Double, note: String = "") {
        let debt = DebtRecord(
            id: UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: amount,
            note: note,
            dateAdded: Date(),
            isSettled: false
        )
        debts.append(debt)
        saveDebts()
    }
    
    func settleDebt(_ debt: DebtRecord) {
        if let index = debts.firstIndex(where: { $0.id == debt.id }) {
            debts[index].isSettled = true
            debts[index].dateSettled = Date()
            saveDebts()
        }
    }
    
    func settleAllDebtsFor(name: String) {
        for i in debts.indices {
            if debts[i].name.lowercased() == name.lowercased() && !debts[i].isSettled {
                debts[i].isSettled = true
                debts[i].dateSettled = Date()
            }
        }
        saveDebts()
    }
    
    func removeDebt(_ debt: DebtRecord) {
        debts.removeAll { $0.id == debt.id }
        saveDebts()
    }
    
    func removeAllDebtsFor(name: String) {
        debts.removeAll { $0.name.lowercased() == name.lowercased() }
        saveDebts()
    }
    
    func updateDebt(_ debt: DebtRecord) {
        if let index = debts.firstIndex(where: { $0.id == debt.id }) {
            debts[index] = debt
            saveDebts()
        }
    }
    
    func applyInterestToGroup(name: String, interestRate: Double) {
        for i in debts.indices {
            if debts[i].name.lowercased() == name.lowercased() && !debts[i].isSettled && debts[i].amount > 0 {
                let interest = debts[i].amount * (interestRate / 100)
                debts[i].amount += interest
            }
        }
        saveDebts()
    }
    
    func getGroupSummary(name: String) -> (totalAmount: Double, transactionCount: Int, oldestDate: Date?) {
        let groupDebts = debts.filter { $0.name.lowercased() == name.lowercased() && !$0.isSettled }
        let totalAmount = groupDebts.reduce(0) { $0 + $1.amount }
        let transactionCount = groupDebts.count
        let oldestDate = groupDebts.map(\.dateAdded).min()
        return (totalAmount: totalAmount, transactionCount: transactionCount, oldestDate: oldestDate)
    }
    
    func checkAndScheduleReminders() {
        let overdueThreshold = 7 // days
        let calendar = Calendar.current
        let now = Date()
        
        for i in debts.indices {
            guard !debts[i].isSettled && debts[i].reminderEnabled && debts[i].amount > 0 else { continue }
            
            let daysOverdue = calendar.dateComponents([.day], from: debts[i].dateAdded, to: now).day ?? 0
            
            if daysOverdue >= overdueThreshold {
                let shouldSendReminder: Bool
                
                if let lastReminder = debts[i].lastReminderDate {
                    let daysSinceLastReminder = calendar.dateComponents([.day], from: lastReminder, to: now).day ?? 0
                    shouldSendReminder = daysSinceLastReminder >= getReminderFrequency(daysOverdue: daysOverdue)
                } else {
                    shouldSendReminder = true
                }
                
                if shouldSendReminder {
                    scheduleNotification(for: debts[i])
                    debts[i].lastReminderDate = now
                }
            }
        }
        saveDebts()
    }
    
    private func getReminderFrequency(daysOverdue: Int) -> Int {
        switch daysOverdue {
        case 7...14: return 3   // Every 3 days
        case 15...30: return 2  // Every 2 days
        case 31...60: return 1  // Daily
        default: return 1       // Daily for 60+ days
        }
    }
    
    func scheduleNotification(for debt: DebtRecord) {
        let content = UNMutableNotificationContent()
        content.title = "Payment Reminder"
        content.body = "\(debt.name) owes $\(String(format: "%.2f", debt.amount)). Debt is \(getDaysOverdue(debt)) days overdue."
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "debt-\(debt.id.uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func getDaysOverdue(_ debt: DebtRecord) -> Int {
        return Calendar.current.dateComponents([.day], from: debt.dateAdded, to: Date()).day ?? 0
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else {
                print("Notification permission denied")
            }
        }
    }
    
    var activeDebts: [DebtRecord] {
        debts.filter { !$0.isSettled }
    }
    
    var overdueDebts: [DebtRecord] {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return activeDebts.filter { $0.dateAdded < thirtyDaysAgo }
    }
    
    var groupedDebtors: [GroupedDebtor] {
        let grouped = Dictionary(grouping: activeDebts) { $0.name.lowercased() }
        return grouped.map { nameKey, debts in
            let name = debts.first?.name ?? nameKey.capitalized
            let totalAmount = debts.reduce(0) { $0 + $1.amount }
            let oldestDate = debts.map(\.dateAdded).min() ?? Date()
            let daysOverdue = max(0, Calendar.current.dateComponents([.day], from: oldestDate, to: Date()).day ?? 0)
            let hasOverdue = debts.contains { debt in
                let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
                return debt.dateAdded < thirtyDaysAgo
            }
            
            return GroupedDebtor(
                name: name,
                totalAmount: totalAmount,
                transactionCount: debts.count,
                daysOverdue: daysOverdue,
                hasOverdueTransactions: hasOverdue,
                transactions: debts.sorted { $0.dateAdded > $1.dateAdded }
            )
        }.sorted { $0.totalAmount > $1.totalAmount }
    }
}

// MARK: - Data Models
struct DebtRecord: Identifiable, Codable {
    let id: UUID
    var name: String
    var amount: Double
    var note: String
    let dateAdded: Date
    var isSettled: Bool
    var dateSettled: Date?
    var lastReminderDate: Date?
    var reminderEnabled: Bool = true
}

struct GroupedDebtor: Identifiable {
    let id = UUID()
    let name: String
    let totalAmount: Double
    let transactionCount: Int
    let daysOverdue: Int
    let hasOverdueTransactions: Bool
    let transactions: [DebtRecord]
}

// MARK: - Main App
struct MainTabView: View {
    @StateObject private var debtStore = DebtStore()
    @State private var selectedTab = 0
    @State private var showingNotificationAlert = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            LedgerView()
                .environmentObject(debtStore)
                .tabItem {
                    Label("THE LEDGER", systemImage: "book.closed")
                }
                .tag(0)
            
            AddDebtView()
                .environmentObject(debtStore)
                .tabItem {
                    Label("ADD DEBT", systemImage: "plus.circle.fill")
                }
                .tag(1)
                
            CollectionsView()
                .environmentObject(debtStore)
                .tabItem {
                    Label("COLLECTIONS", systemImage: "exclamationmark.triangle.fill")
                }
                .tag(2)
                
            HistoryView()
                .environmentObject(debtStore)
                .tabItem {
                    Label("HISTORY", systemImage: "list.bullet")
                }
                .tag(3)
        }
        .tint(Color(hex: "8B0000"))
        .onAppear {
            setupNotifications()
        }
        .onChange(of: selectedTab) { _ in
            // Check for reminders when user switches tabs
            debtStore.checkAndScheduleReminders()
        }
        .alert("Overdue Debts Found", isPresented: $showingNotificationAlert) {
            Button("OK") { }
            Button("View Collections") {
                selectedTab = 2
            }
        } message: {
            Text("You have \(debtStore.overdueDebts.count) overdue debt(s). Tap 'View Collections' to take action.")
        }
    }
    
    private func setupNotifications() {
        debtStore.requestNotificationPermission()
        
        // Check for overdue debts and show alert if any
        if !debtStore.overdueDebts.isEmpty {
            showingNotificationAlert = true
        }
        
        // Schedule reminders for overdue debts
        debtStore.checkAndScheduleReminders()
        
        // Set up periodic reminder checking (every time app becomes active)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            debtStore.checkAndScheduleReminders()
        }
    }
}

struct AddDebtView: View {
    @EnvironmentObject var debtStore: DebtStore
    @State private var inputText = ""
    
    private func addDebt() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        if let parsed = parseDebtInput(inputText) {
            debtStore.addDebt(name: parsed.name, amount: parsed.amount, note: inputText)
            inputText = ""
        }
    }
    
    private func parseDebtInput(_ text: String) -> (name: String, amount: Double)? {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty, input.count <= 200 else { return nil }
        
        // Shorthand: "name amount" or "name +/-amount"
        let pattern = #"^([a-zA-Z\s]+?)\s*([-+]?)(\d+(?:\.\d{2})?)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: input, range: NSRange(location: 0, length: input.count)),
              let nameRange = Range(match.range(at: 1), in: input),
              let amountRange = Range(match.range(at: 3), in: input) else { return nil }
        
        let name = String(input[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        let sign = match.range(at: 2).length > 0 ? String(input[Range(match.range(at: 2), in: input)!]) : ""
        
        guard name.count >= 2, name.count <= 50,
              let amount = Double(String(input[amountRange])),
              amount > 0, amount <= 999999.99 else { return nil }
        
        return (name: name.capitalized, amount: sign == "-" ? -amount : amount)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("ADD DEBT")
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "1A1A1A"))
                .padding(.top)
            
            TextField("e.g. John 50", text: $inputText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(size: 16, design: .monospaced))
                .onSubmit {
                    addDebt()
                }
                .submitLabel(.done)
            
            Button("ADD DEBT") {
                addDebt()
            }
            .font(.system(size: 18, weight: .bold, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, 40)
            .padding(.vertical, 12)
            .background(Color(hex: "1A1A1A"))
            .cornerRadius(8)
            
            Spacer()
        }
        .padding()
        .background(Color(hex: "F4E8D0"))
    }
}

struct LedgerView: View {
    @EnvironmentObject var debtStore: DebtStore
    @State private var expandedGroups: Set<String> = []
    @State private var showingDeleteAlert = false
    @State private var transactionToDelete: DebtRecord?
    @State private var groupToDelete: String?
    @State private var showingGroupActionSheet = false
    @State private var selectedGroupName: String?
    @State private var showingInterestSheet = false
    @State private var interestRate = "5.0"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("LEDGER")
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                    .foregroundColor(Color(hex: "1A1A1A"))
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)
            
            Rectangle()
                .frame(height: 3)
                .foregroundColor(Color(hex: "1A1A1A"))
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            
            if debtStore.groupedDebtors.isEmpty {
                Text("No active debts")
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundColor(Color(hex: "6B6B6B"))
                    .padding(.top, 40)
            } else {
                List {
                    ForEach(debtStore.groupedDebtors, id: \.id) { group in
                        Section {
                            if expandedGroups.contains(group.name.lowercased()) {
                                ForEach(group.transactions, id: \.id) { transaction in
                                    transactionDetailRow(transaction)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            Button("Delete", role: .destructive) {
                                                transactionToDelete = transaction
                                                showingDeleteAlert = true
                                            }
                                        }
                                }
                            }
                        } header: {
                            groupSummaryRow(group)
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .background(Color(hex: "F4E8D0"))
            }
        }
        .background(Color(hex: "F4E8D0"))
        .alert("Delete Transaction", isPresented: $showingDeleteAlert, presenting: transactionToDelete) { transaction in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                debtStore.removeDebt(transaction)
            }
        } message: { transaction in
            Text("Are you sure you want to delete this \(formatAmount(transaction.amount)) transaction for \(transaction.name)?")
        }
        .alert("Delete All Debts", isPresented: Binding(
            get: { groupToDelete != nil },
            set: { if !$0 { groupToDelete = nil } }
        ), presenting: groupToDelete) { groupName in
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                debtStore.removeAllDebtsFor(name: groupName)
            }
        } message: { groupName in
            Text("Are you sure you want to delete ALL transactions for \(groupName)?")
        }
        .confirmationDialog("Group Actions", isPresented: $showingGroupActionSheet, presenting: selectedGroupName) { groupName in
            Button("Settle All Debts") {
                debtStore.settleAllDebtsFor(name: groupName)
            }
            
            Button("Apply Interest") {
                showingInterestSheet = true
            }
            
            Button("Send Reminder") {
                AlertsAndNotificationsHelper.sendGroupReminder(groupName: groupName, debtStore: debtStore)
            }
            
            Button("Delete All", role: .destructive) {
                groupToDelete = groupName
            }
            
            Button("Cancel", role: .cancel) { }
        } message: { groupName in
            let summary = debtStore.getGroupSummary(name: groupName)
            Text("Manage all \(summary.transactionCount) transactions for \(groupName) (Total: \(formatAmount(summary.totalAmount)))")
        }
        .sheet(isPresented: $showingInterestSheet) {
            InterestSheet(
                groupName: selectedGroupName ?? "",
                interestRate: $interestRate,
                onApply: { rate in
                    if let groupName = selectedGroupName {
                        debtStore.applyInterestToGroup(name: groupName, interestRate: rate)
                    }
                    showingInterestSheet = false
                },
                onCancel: {
                    showingInterestSheet = false
                }
            )
        }
    }
    
    private func groupSummaryRow(_ group: GroupedDebtor) -> some View {
        Button {
            if expandedGroups.contains(group.name.lowercased()) {
                expandedGroups.remove(group.name.lowercased())
            } else {
                expandedGroups.insert(group.name.lowercased())
            }
        } label: {
            HStack(alignment: .center, spacing: 8) {
                HStack {
                    Text(group.name.uppercased())
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "1A1A1A"))
                    
                    if group.hasOverdueTransactions {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(Color(hex: "8B0000"))
                            .font(.system(size: 14))
                    }
                }
                
                Spacer()
                
                Text(formatAmount(group.totalAmount))
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(group.hasOverdueTransactions ? Color(hex: "8B0000") : 
                                   group.totalAmount > 0 ? Color(hex: "1A1A1A") : 
                                   Color(hex: "2E7D32"))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 20)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture {
            selectedGroupName = group.name
            showingGroupActionSheet = true
        }
    }
    
    private func transactionDetailRow(_ transaction: DebtRecord) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(formatAmount(transaction.amount))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(transaction.amount > 0 ? Color(hex: "1A1A1A") : Color(hex: "2E7D32"))
                
                Text(transaction.dateAdded.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Color(hex: "6B6B6B"))
            }
            
            Spacer()
            
            Button("SETTLE") {
                debtStore.settleDebt(transaction)
            }
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Color(hex: "2E7D32"))
            .cornerRadius(3)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Delete", role: .destructive) {
                transactionToDelete = transaction
                showingDeleteAlert = true
            }
        }
    }
    
    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        let amountString = formatter.string(from: abs(amount) as NSNumber) ?? "$0"
        return amount < 0 ? "(\(amountString))" : amountString
    }
}

struct HistoryView: View {
    @EnvironmentObject var debtStore: DebtStore
    @State private var showingDeleteAlert = false
    @State private var transactionToDelete: DebtRecord?
    @State private var showingEditSheet = false
    @State private var transactionToEdit: DebtRecord?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("HISTORY")
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "1A1A1A"))
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            if debtStore.debts.isEmpty {
                Text("No transactions recorded")
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundColor(Color(hex: "6B6B6B"))
                    .padding(.top, 40)
            } else {
                List {
                    ForEach(debtStore.debts.sorted { $0.dateAdded > $1.dateAdded }, id: \.id) { debt in
                        historyRow(debt)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Edit") {
                                    transactionToEdit = debt
                                    showingEditSheet = true
                                }
                                .tint(.blue)
                                
                                Button("Delete", role: .destructive) {
                                    transactionToDelete = debt
                                    showingDeleteAlert = true
                                }
                            }
                    }
                }
                .listStyle(PlainListStyle())
                .background(Color(hex: "F4E8D0"))
            }
        }
        .background(Color(hex: "F4E8D0"))
        .alert("Delete Transaction", isPresented: $showingDeleteAlert, presenting: transactionToDelete) { transaction in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                debtStore.removeDebt(transaction)
            }
        } message: { transaction in
            Text("Are you sure you want to delete this \(formatAmount(transaction.amount)) transaction for \(transaction.name)?")
        }
        .sheet(isPresented: $showingEditSheet, content: {
            if let transaction = transactionToEdit {
                EditTransactionSheet(
                    transaction: transaction,
                    onSave: { updatedTransaction in
                        debtStore.updateDebt(updatedTransaction)
                        showingEditSheet = false
                    },
                    onCancel: {
                        showingEditSheet = false
                    }
                )
            }
        })
    }
    
    private func historyRow(_ debt: DebtRecord) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(debt.name)
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(hex: "1A1A1A"))
                    .lineLimit(1)
                
                Text(debt.dateAdded.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Color(hex: "6B6B6B"))
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatAmount(debt.amount))
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(debt.isSettled ? Color(hex: "6B6B6B") : 
                                   debt.amount > 0 ? Color(hex: "1A1A1A") : Color(hex: "2E7D32"))
                
                Text(debt.isSettled ? "SETTLED" : "ACTIVE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(debt.isSettled ? Color(hex: "2E7D32") : Color(hex: "8B0000"))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.3))
        )
    }
    
    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        let amountString = formatter.string(from: abs(amount) as NSNumber) ?? "$0"
        return amount < 0 ? "(\(amountString))" : amountString
    }
}



struct EditTransactionSheet: View {
    let transaction: DebtRecord
    let onSave: (DebtRecord) -> Void
    let onCancel: () -> Void
    
    @State private var editedName: String
    @State private var editedAmount: String
    @State private var editedNote: String
    @State private var showingError = false
    @State private var errorMessage = ""
    
    init(transaction: DebtRecord, onSave: @escaping (DebtRecord) -> Void, onCancel: @escaping () -> Void) {
        self.transaction = transaction
        self.onSave = onSave
        self.onCancel = onCancel
        self._editedName = State(initialValue: transaction.name)
        self._editedAmount = State(initialValue: String(format: "%.2f", abs(transaction.amount)))
        self._editedNote = State(initialValue: transaction.note)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("EDIT TRANSACTION")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "1A1A1A"))
                    .padding(.top)
                
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name")
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(hex: "1A1A1A"))
                        
                        TextField("Person's name", text: $editedName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 16, design: .monospaced))
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Amount")
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(hex: "1A1A1A"))
                        
                        TextField("0.00", text: $editedAmount)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 16, design: .monospaced))
                            .keyboardType(.decimalPad)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Note")
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(hex: "1A1A1A"))
                        
                        TextField("Optional note", text: $editedNote)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 16, design: .monospaced))
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "1A1A1A"))
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(hex: "1A1A1A"), lineWidth: 2)
                    )
                    
                    Button("Save") {
                        saveTransaction()
                    }
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color(hex: "1A1A1A"))
                    .cornerRadius(8)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .background(Color(hex: "F4E8D0"))
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func saveTransaction() {
        let trimmedName = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, trimmedName.count >= 2, trimmedName.count <= 50 else {
            showError("Name must be between 2-50 characters")
            return
        }
        
        guard let amount = Double(editedAmount), amount > 0, amount <= 999999.99 else {
            showError("Amount must be between $0.01 and $999,999.99")
            return
        }
        
        let trimmedNote = editedNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedNote.count <= 200 else {
            showError("Note must be 200 characters or less")
            return
        }
        
        let finalAmount = transaction.amount < 0 ? -amount : amount
        var updatedTransaction = transaction
        updatedTransaction.name = trimmedName.capitalized
        updatedTransaction.amount = finalAmount
        updatedTransaction.note = trimmedNote.isEmpty ? editedAmount : trimmedNote
        
        onSave(updatedTransaction)
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}


struct InterestSheet: View {
    let groupName: String
    @Binding var interestRate: String
    let onApply: (Double) -> Void
    let onCancel: () -> Void
    
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("APPLY INTEREST")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "1A1A1A"))
                    .padding(.top)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Apply interest to all active debts for \(groupName.uppercased())")
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(hex: "1A1A1A"))
                        .multilineTextAlignment(.center)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Interest Rate (%)")
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(hex: "1A1A1A"))
                        
                        TextField("5.0", text: $interestRate)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 16, design: .monospaced))
                            .keyboardType(.decimalPad)
                    }
                    
                    Text("Interest will be added to positive debt amounts only.")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Color(hex: "6B6B6B"))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "1A1A1A"))
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(hex: "1A1A1A"), lineWidth: 2)
                    )
                    
                    Button("Apply") {
                        applyInterest()
                    }
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color(hex: "1A1A1A"))
                    .cornerRadius(8)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .background(Color(hex: "F4E8D0"))
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func applyInterest() {
        guard let rate = Double(interestRate), rate >= 0, rate <= 100 else {
            showError("Interest rate must be between 0% and 100%")
            return
        }
        
        onApply(rate)
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}

struct AlertsAndNotificationsHelper {
    static func sendGroupReminder(groupName: String, debtStore: DebtStore) {
        let groupDebts = debtStore.debts.filter { 
            $0.name.lowercased() == groupName.lowercased() && !$0.isSettled && $0.amount > 0 
        }
        
        for debt in groupDebts {
            debtStore.scheduleNotification(for: debt)
        }
        
        // Show confirmation
        let content = UNMutableNotificationContent()
        content.title = "Reminder Sent"
        content.body = "Payment reminder sent for all \(groupDebts.count) debt(s) to \(groupName)"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "reminder-sent-\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}


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
