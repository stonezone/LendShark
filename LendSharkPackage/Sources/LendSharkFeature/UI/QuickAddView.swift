import SwiftUI
import CoreData
#if os(iOS)
import Contacts
#endif

/// Quick Add Debt - single field, simple parser + tap-to-build UI
public struct QuickAddView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var settings: SettingsService
    @State private var inputText = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @FocusState private var isInputFocused: Bool

    // Tap-to-build state
    @State private var detectedName: String?
    @State private var selectedDirection: TransactionDTO.TransactionDirection?
    @State private var selectedAmount: Decimal?

    #if os(iOS)
    // Contact-based suggestions (iOS only)
    @State private var contactsLoaded = false
    @State private var contactSuggestions: [ContactCandidate] = []
    @State private var suggestions: [QuickAddSuggestion] = []
    @State private var suggestionWeights: [String: Int] = [:]
    #endif

    public init() {}

    public var body: some View {
        ZStack {
            RuledLinesBackground()
                .onTapGesture {
                    isInputFocused = false
                }

            VStack(alignment: .leading, spacing: 0) {
                // Header with double underline
                VStack(alignment: .leading, spacing: 4) {
                    Text("QUICK ADD")
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .foregroundColor(.inkBlack)
                        .tracking(2)
                    Rectangle().frame(height: 2).foregroundColor(.inkBlack)
                    Rectangle().frame(height: 1).foregroundColor(.inkBlack).padding(.top, 2)
                }
                .padding(.bottom, 24)
                
                // FREQUENT BORROWERS (if enabled)
                if settings.showFrequentBorrowers {
                    frequentBorrowersSection
                        .padding(.bottom, 16)
                }

                // Input field with pencil-style underline
                VStack(alignment: .leading, spacing: 8) {
                    Text("WRITE IT DOWN:")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.pencilGray)
                        .tracking(1)

                    quickAddTextField

                    // Pencil underline effect
                    Rectangle()
                        .frame(height: 2)
                        .foregroundColor(.inkBlack.opacity(0.7))
                }
                .padding(.bottom, 20)
                
                // TAP-TO-BUILD UI (if enabled)
                if settings.enableTapToBuild && detectedName != nil {
                    tapToBuildSection
                        .padding(.bottom, 20)
                }

                // Preview with stamp styling
                if !previewText.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("WILL RECORD:")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.pencilGray)
                            .tracking(1)

                        Text(previewText)
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundColor(.inkBlack)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.inkBlack.opacity(0.05))
                            .overlay(
                                Rectangle()
                                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 2]))
                                    .foregroundColor(.inkBlack.opacity(0.3))
                            )
                    }
                    .padding(.bottom, 24)
                }

                // Add button - bold and direct
                Button(action: add) {
                    HStack {
                        Text("ADD TO LEDGER")
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .tracking(1)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.paperYellow)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.inkBlack)
                }
                .disabled(previewText.isEmpty)
                .opacity(previewText.isEmpty ? 0.5 : 1.0)

                // Help text
                VStack(alignment: .leading, spacing: 8) {
                    Text("EXAMPLES:")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.pencilGray.opacity(0.7))
                        .padding(.top, 24)

                    Group {
                        Text("• john owes 50")
                        Text("• mary owes 100 due 2 weeks")
                        Text("• mike owes 200 at 10%")
                        Text("• john paid 25")
                        Text("• i owe frank 50")
                    }
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.pencilGray.opacity(0.6))
                }

                Spacer()
            }
            .padding(24)
            #if os(iOS)
            .onAppear {
                loadContactsIfNeeded()
                loadSuggestionWeights()
            }
            #endif
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Frequent Borrowers Section
    
    @ViewBuilder
    private var frequentBorrowersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FREQUENT:")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.pencilGray)
                .tracking(1)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(frequentBorrowers, id: \.name) { borrower in
                        Button(action: {
                            inputText = borrower.name.lowercased()
                            detectedName = borrower.name.lowercased()
                        }) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(borrower.name.uppercased())
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(.inkBlack)
                                Text("\(borrower.count)x")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundColor(.pencilGray)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.inkBlack.opacity(0.05))
                            .overlay(
                                Rectangle()
                                    .stroke(Color.inkBlack.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Tap-to-Build Section
    
    @ViewBuilder
    private var tapToBuildSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Direction selection
            if selectedDirection == nil {
                VStack(alignment: .leading, spacing: 6) {
                    Text("DIRECTION:")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.pencilGray)
                        .tracking(1)
                    
                    HStack(spacing: 8) {
                        tapButton("OWES ME", color: .bloodRed) {
                            selectedDirection = .lent
                            inputText = "\(detectedName ?? "") owes"
                        }
                        tapButton("I OWE", color: .cashGreen) {
                            selectedDirection = .borrowed
                            inputText = "i owe \(detectedName ?? "")"
                        }
                    }
                }
            }
            
            // Amount quick picks (after direction selected)
            if selectedDirection != nil && selectedAmount == nil {
                VStack(alignment: .leading, spacing: 6) {
                    Text("AMOUNT:")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.pencilGray)
                        .tracking(1)
                    
                    HStack(spacing: 8) {
                        tapButton("$20") {
                            selectedAmount = 20
                            appendToInput("20")
                        }
                        tapButton("$50") {
                            selectedAmount = 50
                            appendToInput("50")
                        }
                        tapButton("$100") {
                            selectedAmount = 100
                            appendToInput("100")
                        }
                        tapButton("CUSTOM") {
                            isInputFocused = true
                        }
                    }
                }
            }
            
            // Condition buttons (after amount)
            if selectedAmount != nil {
                VStack(alignment: .leading, spacing: 6) {
                    Text("CONDITION:")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.pencilGray)
                        .tracking(1)
                    
                    HStack(spacing: 8) {
                        tapButton("10%") {
                            appendToInput("at 10%")
                        }
                        tapButton("DUE 1WK") {
                            appendToInput("due 1 week")
                        }
                        tapButton("DUE 2WK") {
                            appendToInput("due 2 weeks")
                        }
                        tapButton("DONE", color: .cashGreen) {
                            isInputFocused = false
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color.paperYellow.opacity(0.3))
        .overlay(
            Rectangle()
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 2]))
                .foregroundColor(.inkBlack.opacity(0.2))
        )
    }
    
    private func tapButton(_ label: String, color: Color = .inkBlack, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.paperYellow)
                .overlay(
                    Rectangle()
                        .stroke(color.opacity(0.5), lineWidth: 1)
                )
        }
    }
    
    // MARK: - Computed Properties
    
    private var frequentBorrowers: [(name: String, count: Int)] {
        let request: NSFetchRequest<Transaction> = Transaction.fetchRequest()
        request.predicate = NSPredicate(format: "settled == false AND party != nil")
        
        do {
            let transactions = try viewContext.fetch(request)
            
            // Group by party and count
            var counts: [String: Int] = [:]
            for transaction in transactions {
                if let party = transaction.party {
                    counts[party, default: 0] += 1
                }
            }
            
            // Sort by count and take top 5
            return counts
                .sorted { $0.value > $1.value }
                .prefix(5)
                .map { (name: $0.key, count: $0.value) }
        } catch {
            return []
        }
    }
    
    private var previewText: String {
        let parser = ParserService()
        switch parser.parse(inputText, abbreviations: settings.abbreviations) {
        case .success(let action):
            switch action {
            case .add(let dto):
                let who = dto.party
                let amount = dto.amount ?? 0
                let dollars = String(format: "%.2f", NSDecimalNumber(decimal: amount).doubleValue)
                var base = dto.direction == .lent 
                    ? "\(who.uppercased()) owes $\(dollars)"
                    : "I owe \(who.uppercased()) $\(dollars)"
                
                // Add interest if present
                if let rate = dto.interestRate {
                    let pct = NSDecimalNumber(decimal: rate * 100).intValue
                    base += " @ \(pct)%/wk"
                }
                
                // Add due date if present
                if let due = dto.dueDate {
                    let days = Calendar.current.dateComponents([.day], from: Date(), to: due).day ?? 0
                    base += " (due in \(days)d)"
                }
                
                // Add notes if present
                if let notes = dto.notes, !notes.isEmpty {
                    base += " [\(notes)]"
                }
                
                return base
            case .settle(let name):
                return "Mark \(name.uppercased()) as PAID"
            }
        case .failure:
            return ""
        }
    }
    
    // MARK: - Helper Methods
    
    private func detectNameInInput(_ input: String) {
        // Simple name detection - first word before "owes" or after "i owe"
        let lower = input.lowercased().trimmingCharacters(in: .whitespaces)
        
        if lower.isEmpty {
            detectedName = nil
            selectedDirection = nil
            selectedAmount = nil
            return
        }
        
        // Pattern: "name owes" or "i owe name"
        let words = lower.split(separator: " ")
        if words.count >= 1 && !words[0].starts(with: "i") {
            detectedName = String(words[0])
        } else if words.count >= 3 && words[0] == "i" && words[1] == "owe" {
            detectedName = String(words[2])
        } else if words.count == 1 {
            // Just a name entered
            detectedName = String(words[0])
        }
        
        #if os(iOS)
        updateSuggestions(for: input)
        #endif
    }
    
    private func appendToInput(_ text: String) {
        if inputText.hasSuffix(" ") {
            inputText += text
        } else {
            inputText += " " + text
        }
    }
    
    private func add() {
        let parser = ParserService()
        let result = parser.parse(inputText, abbreviations: settings.abbreviations)
        
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        case .success(let action):
            do {
                switch action {
                case .add(let dto):
                    let t = Transaction(context: viewContext)
                    t.id = dto.id
                    t.party = dto.party
                    t.amount = dto.amount.map { NSDecimalNumber(decimal: $0) }
                    t.direction = Int16(dto.direction == .lent ? 1 : -1)
                    t.isItem = dto.isItem
                    t.settled = dto.settled
                    t.timestamp = dto.timestamp
                    t.dueDate = dto.dueDate
                    t.interestRate = dto.interestRate.map { NSDecimalNumber(decimal: $0) }
                    t.notes = dto.notes
                    t.phoneNumber = dto.phoneNumber // FIX: Save phone number!
                    try viewContext.save()
                case .settle(let name):
                    try Transaction.settleAll(with: name, in: viewContext)
                }
                
                // Reset state
                inputText = ""
                detectedName = nil
                selectedDirection = nil
                selectedAmount = nil
                isInputFocused = false
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    // MARK: - Base TextField + Suggestions (iOS)
    
    @ViewBuilder
    private var quickAddTextField: some View {
        #if os(iOS)
        VStack(alignment: .leading, spacing: 0) {
            baseQuickAddTextField
            
            if !suggestions.isEmpty {
                suggestionPanel
                    .padding(.top, 4)
            }
        }
        #else
        baseQuickAddTextField
        #endif
    }
    
    private var baseQuickAddTextField: some View {
        TextField("john owes 50 due 2 weeks at 10%", text: $inputText)
            .font(.system(size: 17, weight: .medium, design: .monospaced))
            .foregroundColor(.inkBlack)
            .textFieldStyle(.plain)
            .padding(.vertical, 12)
            .focused($isInputFocused)
            .onChange(of: inputText) { oldValue, newValue in
                detectNameInInput(newValue)
            }
            .onSubmit {
                add()
                isInputFocused = false
            }
    }

    // MARK: - Contacts + Suggestion Model (iOS)
    
    #if os(iOS)
    private struct ContactCandidate {
        let name: String
        let phoneNumbers: [String]
    }
    
    private struct QuickAddSuggestion: Identifiable {
        enum Kind {
            case name
            case phone
        }
        
        let id = UUID()
        let kind: Kind
        let contactName: String
        let displayLabel: String
        let completionText: String
        
        var iconSystemName: String {
            switch kind {
            case .name: return "person.fill"
            case .phone: return "phone.fill"
            }
        }
    }
    
    private var suggestionPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(suggestions.prefix(5)) { suggestion in
                Button(action: {
                    applySuggestion(suggestion)
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: suggestion.iconSystemName)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.inkBlack)
                        
                        Text(suggestion.displayLabel)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(.inkBlack)
                            .lineLimit(1)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                
                if suggestion.id != suggestions.prefix(5).last?.id {
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.inkBlack.opacity(0.15))
                        .padding(.horizontal, 4)
                }
            }
        }
        .padding(.vertical, 4)
        .background(Color.paperYellow.opacity(0.9))
        .overlay(
            Rectangle()
                .stroke(Color.inkBlack.opacity(0.4), lineWidth: 1)
        )
    }
    
    private func loadContactsIfNeeded() {
        guard !contactsLoaded else { return }
        
        let store = CNContactStore()
        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor
        ]
        
        let fetchAndUpdate: () -> Void = {
            DispatchQueue.global(qos: .userInitiated).async {
                let results = self.fetchContacts(from: store, keys: keys)
                DispatchQueue.main.async {
                    self.contactSuggestions = results
                    self.contactsLoaded = true
                    self.updateSuggestions(for: self.inputText)
                }
            }
        }
        
        let status = CNContactStore.authorizationStatus(for: .contacts)
        switch status {
        case .notDetermined:
            store.requestAccess(for: .contacts) { granted, _ in
                guard granted else { return }
                fetchAndUpdate()
            }
        case .authorized:
            fetchAndUpdate()
        default:
            break
        }
    }
    
    private func applySuggestion(_ suggestion: QuickAddSuggestion) {
        inputText = suggestion.completionText
        bumpSuggestionWeight(for: suggestion.contactName)
        // Re-run detection and suggestions for the new value
        detectNameInInput(inputText)
    }
    
    nonisolated private func fetchContacts(from store: CNContactStore, keys: [CNKeyDescriptor]) -> [ContactCandidate] {
        let request = CNContactFetchRequest(keysToFetch: keys)
        var results: [ContactCandidate] = []
        
        do {
            try store.enumerateContacts(with: request) { contact, _ in
                var fullName = contact.givenName
                if !contact.familyName.isEmpty {
                    if !fullName.isEmpty {
                        fullName += " "
                    }
                    fullName += contact.familyName
                }
                // If there is no given/family name, skip this contact entirely
                guard !fullName.isEmpty else { return }
                
                let phones = contact.phoneNumbers.map { $0.value.stringValue }.filter { !$0.isEmpty }
                guard !phones.isEmpty else { return }
                
                results.append(ContactCandidate(name: fullName, phoneNumbers: phones))
            }
        } catch {
            // Ignore contact errors – suggestions are optional
        }
        
        return results
    }
    
    private func loadSuggestionWeights() {
        if let dict = UserDefaults.standard.dictionary(forKey: "QuickAddSuggestionWeights") as? [String: Int] {
            suggestionWeights = dict
        } else {
            suggestionWeights = [:]
        }
    }
    
    private func bumpSuggestionWeight(for name: String) {
        var weights = suggestionWeights
        weights[name, default: 0] += 1
        suggestionWeights = weights
        UserDefaults.standard.set(weights, forKey: "QuickAddSuggestionWeights")
    }
    
    private func updateSuggestions(for text: String) {
        guard contactsLoaded, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            suggestions = []
            return
        }
        
        let lower = text.lowercased()
        
        // Find first keyword position to split name segment
        let keywords = [" owes", " owe", " lent", " borrowed", " paid", " pay "]
        var nameEndIndex: String.Index? = nil
        for keyword in keywords {
            if let range = lower.range(of: keyword) {
                if nameEndIndex == nil || range.lowerBound < nameEndIndex! {
                    nameEndIndex = range.lowerBound
                }
            }
        }
        
        let nameSegmentRange = text.startIndex ..< (nameEndIndex ?? text.endIndex)
        let nameSegment = text[nameSegmentRange].trimmingCharacters(in: .whitespaces)
        
        let tokens = text.split(whereSeparator: { $0.isWhitespace })
        let currentToken = tokens.last.map(String.init) ?? ""
        let digitSet = CharacterSet.decimalDigits.union(CharacterSet(charactersIn: "+()-." ))
        let isPhoneContext = !currentToken.isEmpty &&
            currentToken.unicodeScalars.allSatisfy { digitSet.contains($0) }
        
        var newSuggestions: [QuickAddSuggestion] = []
        let normalizedNameSegment = nameSegment.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Name suggestions when we're still in the leading segment
        if !nameSegment.isEmpty, !isPhoneContext {
            let query = normalizedNameSegment
            
            var matches = contactSuggestions.filter { candidate in
                let lowerName = candidate.name.lowercased()
                // Skip if we've already fully typed this name
                guard lowerName != normalizedNameSegment else { return false }
                return lowerName.hasPrefix(query) || lowerName.contains(query)
            }
            
            // Sort by: prefix match, weight, then name
            matches.sort { lhs, rhs in
                let lhsLower = lhs.name.lowercased()
                let rhsLower = rhs.name.lowercased()
                let lhsIsPrefix = lhsLower.hasPrefix(query)
                let rhsIsPrefix = rhsLower.hasPrefix(query)
                if lhsIsPrefix != rhsIsPrefix {
                    return lhsIsPrefix
                }
                let lhsWeight = suggestionWeights[lhs.name] ?? 0
                let rhsWeight = suggestionWeights[rhs.name] ?? 0
                if lhsWeight != rhsWeight {
                    return lhsWeight > rhsWeight
                }
                return lhs.name < rhs.name
            }
            
            for candidate in matches.prefix(5) {
                let rest = text[nameSegmentRange.upperBound...]
                let completion = candidate.name + rest
                let label = candidate.name.uppercased()
                newSuggestions.append(
                    QuickAddSuggestion(
                        kind: .name,
                        contactName: candidate.name,
                        displayLabel: label,
                        completionText: completion
                    )
                )
            }
        }
        
        // Phone suggestions when user is typing digits
        if isPhoneContext, !currentToken.isEmpty {
            let digitsOnly = currentToken.filter { $0.isNumber }
            guard let tokenRange = lower.range(of: currentToken.lowercased(), options: .backwards) else {
                suggestions = newSuggestions
                return
            }
            
            // If we have a name segment that matches a contact, prioritize their numbers
            let nameQuery = nameSegment.lowercased()
            var prioritizedContacts: [ContactCandidate]
            if !nameQuery.isEmpty {
                let matching = contactSuggestions.filter { $0.name.lowercased().contains(nameQuery) }
                prioritizedContacts = matching.isEmpty ? contactSuggestions : matching
            } else {
                prioritizedContacts = contactSuggestions
            }
            
            // Sort phone suggestions by weight and name
            prioritizedContacts.sort { lhs, rhs in
                let lhsWeight = suggestionWeights[lhs.name] ?? 0
                let rhsWeight = suggestionWeights[rhs.name] ?? 0
                if lhsWeight != rhsWeight {
                    return lhsWeight > rhsWeight
                }
                return lhs.name < rhs.name
            }
            
            for candidate in prioritizedContacts {
                for phone in candidate.phoneNumbers {
                    let phoneDigits = phone.filter { $0.isNumber }
                    guard phoneDigits.hasPrefix(digitsOnly) else { continue }
                    
                    let before = text[..<tokenRange.lowerBound]
                    let after = text[tokenRange.upperBound...]
                    let completion = before + phone + after
                    let label = "\(candidate.name.uppercased()) • \(phone)"
                    
                    newSuggestions.append(
                        QuickAddSuggestion(
                            kind: .phone,
                            contactName: candidate.name,
                            displayLabel: label,
                            completionText: String(completion)
                        )
                    )
                }
            }
        }
        
        suggestions = newSuggestions
    }
    #endif
}
