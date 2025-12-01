import Foundation

/// Reminder System - Automatic escalation for loan shark collections
struct ReminderSystem {
    
    /// Escalation levels with messages
    enum EscalationLevel: CaseIterable {
        case friendly       // 1-7 days
        case overdue        // 8-14 days  
        case urgent         // 15-30 days
        case final          // 31-60 days
        case collections    // 60+ days
        
        static func level(for daysOverdue: Int) -> EscalationLevel {
            switch daysOverdue {
            case 1...7:
                return .friendly
            case 8...14:
                return .overdue
            case 15...30:
                return .urgent
            case 31...60:
                return .final
            default:
                return .collections
            }
        }
        
        var title: String {
            switch self {
            case .friendly:
                return "Friendly Reminder"
            case .overdue:
                return "Payment Overdue"
            case .urgent:
                return "Urgent Notice"
            case .final:
                return "Final Notice"
            case .collections:
                return "Collections Notice"
            }
        }
        
        var message: String {
            switch self {
            case .friendly:
                return "Just a friendly reminder that your payment is now due. Please settle at your earliest convenience."
                
            case .overdue:
                return "Your payment is now overdue. Please contact us immediately to arrange payment."
                
            case .urgent:
                return "This is an urgent notice regarding your overdue payment. Immediate payment is required to avoid further action."
                
            case .final:
                return "FINAL NOTICE: This debt must be settled immediately. Failure to pay will result in collection proceedings."
                
            case .collections:
                return "COLLECTIONS NOTICE: This account has been turned over for collection. Contact us immediately to resolve this matter."
            }
        }
        
        var severity: String {
            switch self {
            case .friendly:
                return "LOW"
            case .overdue:
                return "MEDIUM"
            case .urgent:
                return "HIGH"
            case .final:
                return "CRITICAL"
            case .collections:
                return "MAXIMUM"
            }
        }
    }
    
    /// Generate reminder message for a debtor
    static func generateReminder(
        for person: String,
        amount: Decimal,
        daysOverdue: Int
    ) -> ReminderMessage {
        let level = EscalationLevel.level(for: daysOverdue)
        
        return ReminderMessage(
            person: person,
            amount: amount,
            daysOverdue: daysOverdue,
            escalationLevel: level,
            title: level.title,
            message: personalizeMessage(level.message, person: person, amount: amount),
            dateSent: Date(),
            severity: level.severity
        )
    }
    
    /// Personalize the message with debtor details
    private static func personalizeMessage(
        _ template: String,
        person: String,
        amount: Decimal
    ) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        let amountString = formatter.string(from: amount as NSDecimalNumber) ?? "$0"
        
        return "Dear \(person),\n\n\(template)\n\nAmount Due: \(amountString)\n\nPlease remit payment immediately.\n\nRegards,\nLendShark Collections"
    }
    
    /// Check if reminder should be sent based on last reminder date
    static func shouldSendReminder(
        daysOverdue: Int,
        lastReminderDate: Date?
    ) -> Bool {
        guard daysOverdue > 0 else { return false }
        
        guard let lastDate = lastReminderDate else {
            return true // Never sent a reminder
        }
        
        let daysSinceLastReminder = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
        
        // Frequency based on escalation level
        let level = EscalationLevel.level(for: daysOverdue)
        let reminderFrequency: Int
        
        switch level {
        case .friendly:
            reminderFrequency = 7   // Weekly
        case .overdue:
            reminderFrequency = 3   // Every 3 days
        case .urgent:
            reminderFrequency = 2   // Every 2 days
        case .final:
            reminderFrequency = 1   // Daily
        case .collections:
            reminderFrequency = 1   // Daily
        }
        
        return daysSinceLastReminder >= reminderFrequency
    }
}

/// Reminder message structure
struct ReminderMessage {
    let person: String
    let amount: Decimal
    let daysOverdue: Int
    let escalationLevel: ReminderSystem.EscalationLevel
    let title: String
    let message: String
    let dateSent: Date
    let severity: String
    
    /// Format for display or sending
    var formattedMessage: String {
        return """
        ═══════════════════════════════════
        \(title.uppercased())
        SEVERITY: \(severity)
        ═══════════════════════════════════
        
        \(message)
        
        Days Overdue: \(daysOverdue)
        Date: \(dateSent.formatted(date: .abbreviated, time: .omitted))
        
        ═══════════════════════════════════
        """
    }
}