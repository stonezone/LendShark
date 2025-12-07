import Foundation

/// Centralised interest math so everyone agrees on the vig.
/// Uses a weekly rate (e.g. 0.10 = 10%/week) and smooths it over
/// the actual days between loan start and due date.
enum InterestCalculator {
    
    /// Interest that has accrued so far for a single transaction,
    /// as of the given date.
    static func interestSoFar(
        for transaction: Transaction,
        asOf now: Date = Date()
    ) -> Decimal {
        guard
            let rate = transaction.interestRate as? Decimal,
            rate > 0,
            let amount = transaction.amount as? Decimal,
            amount > 0,
            let start = transaction.timestamp
        else {
            return 0
        }
        
        // If there's a due date, smooth the weekly vig over the term.
        if let dueDate = transaction.dueDate, dueDate > start {
            let daysTotal = max(1, days(from: start, to: dueDate))
            let daysSoFar = max(0, min(days(from: start, to: now), daysTotal))
            
            let weeksCharged = weeksChargedForTerm(daysTotal)
            let interestAtDue = amount * rate * weeksCharged
            let perDay = interestAtDue / Decimal(daysTotal)
            return perDay * Decimal(daysSoFar)
        }
        
        // Open‑ended loan: behave like previous logic (weekly simple interest).
        let daysSince = max(0, days(from: start, to: now))
        let weeks = Decimal(daysSince) / 7
        return amount * rate * weeks
    }
    
    /// Total interest that will be owed at the due date, if there is one.
    static func interestAtDueDate(for transaction: Transaction) -> Decimal? {
        guard
            let rate = transaction.interestRate as? Decimal,
            rate > 0,
            let amount = transaction.amount as? Decimal,
            amount > 0,
            let start = transaction.timestamp,
            let dueDate = transaction.dueDate,
            dueDate > start
        else {
            return nil
        }
        
        let daysTotal = max(1, days(from: start, to: dueDate))
        let weeksCharged = weeksChargedForTerm(daysTotal)
        return amount * rate * weeksCharged
    }
    
    // MARK: - Helpers
    
    private static func days(from start: Date, to end: Date) -> Int {
        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }
    
    /// Loan shark rule: round up to whole weeks for the term.
    private static func weeksChargedForTerm(_ days: Int) -> Decimal {
        let weeks = Double(days) / 7.0
        let rounded = Int(ceil(weeks))
        return Decimal(rounded)
    }
}

