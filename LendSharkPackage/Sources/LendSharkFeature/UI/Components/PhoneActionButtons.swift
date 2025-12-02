import SwiftUI

#if os(iOS)

/// Reusable phone action buttons (CALL and TEXT) in notebook style
/// Shows only if phone number exists
public struct PhoneActionButtons: View {
    let phoneNumber: String
    let personName: String
    let amount: Decimal
    let dueDate: Date?
    
    @State private var showingSMSComposer = false
    
    public init(
        phoneNumber: String,
        personName: String,
        amount: Decimal,
        dueDate: Date? = nil
    ) {
        self.phoneNumber = phoneNumber
        self.personName = personName
        self.amount = amount
        self.dueDate = dueDate
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            // CALL button
            Button(action: makePhoneCall) {
                HStack(spacing: 4) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 10))
                    Text("CALL")
                }
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundColor(Color.paperYellow)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.inkBlack)
            }
            
            // TEXT button
            Button(action: { showingSMSComposer = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 10))
                    Text("TEXT")
                }
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundColor(Color.paperYellow)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.inkBlack)
            }
        }
        .smsComposer(
            isPresented: $showingSMSComposer,
            recipient: phoneNumber,
            body: generateMessage()
        )
    }
    
    private func makePhoneCall() {
        let digits = phoneNumber.filter { $0.isNumber }
        guard let url = URL(string: "tel://\(digits)") else { return }
        UIApplication.shared.open(url)
    }
    
    private func generateMessage() -> String {
        let daysOverdue = SMSService.daysOverdue(from: dueDate)
        return SMSService.composeReminder(
            name: personName,
            amount: amount,
            daysOverdue: daysOverdue
        )
    }
}

/// Compact version - just icons, no text labels
public struct PhoneActionButtonsCompact: View {
    let phoneNumber: String
    let personName: String
    let amount: Decimal
    let dueDate: Date?
    
    @State private var showingSMSComposer = false
    
    public init(
        phoneNumber: String,
        personName: String,
        amount: Decimal,
        dueDate: Date? = nil
    ) {
        self.phoneNumber = phoneNumber
        self.personName = personName
        self.amount = amount
        self.dueDate = dueDate
    }
    
    public var body: some View {
        HStack(spacing: 6) {
            Button(action: makePhoneCall) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Color.paperYellow)
                    .frame(width: 28, height: 28)
                    .background(Color.inkBlack)
            }
            
            Button(action: { showingSMSComposer = true }) {
                Image(systemName: "message.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Color.paperYellow)
                    .frame(width: 28, height: 28)
                    .background(Color.inkBlack)
            }
        }
        .smsComposer(
            isPresented: $showingSMSComposer,
            recipient: phoneNumber,
            body: generateMessage()
        )
    }
    
    private func makePhoneCall() {
        let digits = phoneNumber.filter { $0.isNumber }
        guard let url = URL(string: "tel://\(digits)") else { return }
        UIApplication.shared.open(url)
    }
    
    private func generateMessage() -> String {
        let daysOverdue = SMSService.daysOverdue(from: dueDate)
        return SMSService.composeReminder(
            name: personName,
            amount: amount,
            daysOverdue: daysOverdue
        )
    }
}

#endif
