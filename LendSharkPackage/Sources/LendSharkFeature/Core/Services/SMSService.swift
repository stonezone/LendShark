import Foundation
#if canImport(MessageUI)
import MessageUI
#endif

/// SMS Service for sending collection reminders
/// Uses ReminderSystem message templates for consistent messaging
public struct SMSService {
    
    /// Check if device can send text messages
    public static func canSendText() -> Bool {
        #if canImport(MessageUI)
        return MFMessageComposeViewController.canSendText()
        #else
        return false
        #endif
    }
    
    /// Generate reminder message based on days overdue
    /// Uses escalating tone like ReminderSystem
    public static func composeReminder(
        name: String,
        amount: Decimal,
        daysOverdue: Int
    ) -> String {
        let formattedAmount = formatCurrency(amount)
        let firstName = name.components(separatedBy: " ").first ?? name
        
        switch daysOverdue {
        case ..<0:
            // Due in the future - day-before reminder
            return "Hey \(firstName), just a heads up - that \(formattedAmount) is due tomorrow."
            
        case 0:
            // Due today
            return "Hey \(firstName), that \(formattedAmount) is due today. Let's square up."
            
        case 1...7:
            // 1-7 days overdue - friendly
            return "Hey \(firstName), about that \(formattedAmount) you still owe me."
            
        case 8...14:
            // 8-14 days overdue - firmer
            return "\(firstName), your \(formattedAmount) is overdue. Let's get this sorted."
            
        case 15...30:
            // 15-30 days overdue - serious
            return "\(firstName). \(formattedAmount). \(daysOverdue) days. Call me."
            
        default:
            // 30+ days - final notice
            return "Final notice \(firstName). \(formattedAmount). Handle it."
        }
    }
    
    /// Generate day-before reminder message
    public static func composeDayBeforeReminder(
        name: String,
        amount: Decimal
    ) -> String {
        let firstName = name.components(separatedBy: " ").first ?? name
        let formattedAmount = formatCurrency(amount)
        return "Hey \(firstName), just a heads up - that \(formattedAmount) is due tomorrow."
    }
    
    /// Format currency for display
    private static func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? "$\(amount)"
    }
    
    /// Calculate days overdue from due date
    public static func daysOverdue(from dueDate: Date?) -> Int {
        guard let due = dueDate else { return 0 }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dueDay = calendar.startOfDay(for: due)
        let components = calendar.dateComponents([.day], from: dueDay, to: today)
        return components.day ?? 0
    }
}
