import SwiftUI
import MessageUI

#if os(iOS)

/// Result of SMS composition attempt
public enum SMSResult {
    case sent
    case cancelled
    case failed
    case notAvailable
}

/// SwiftUI wrapper for MFMessageComposeViewController
/// Presents native SMS composer with pre-filled recipient and message
public struct SMSComposerView: UIViewControllerRepresentable {
    let recipients: [String]
    let body: String
    let onComplete: (SMSResult) -> Void
    
    @Environment(\.presentationMode) var presentationMode
    
    public init(
        recipients: [String],
        body: String,
        onComplete: @escaping (SMSResult) -> Void = { _ in }
    ) {
        self.recipients = recipients
        self.body = body
        self.onComplete = onComplete
    }
    
    /// Convenience init for single recipient
    public init(
        recipient: String,
        body: String,
        onComplete: @escaping (SMSResult) -> Void = { _ in }
    ) {
        self.recipients = [recipient]
        self.body = body
        self.onComplete = onComplete
    }
    
    public func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.messageComposeDelegate = context.coordinator
        controller.recipients = recipients
        controller.body = body
        return controller
    }
    
    public func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {
        // No updates needed
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    @MainActor
    public class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        var parent: SMSComposerView
        
        init(_ parent: SMSComposerView) {
            self.parent = parent
        }
        
        nonisolated public func messageComposeViewController(
            _ controller: MFMessageComposeViewController,
            didFinishWith result: MessageComposeResult
        ) {
            let smsResult: SMSResult
            switch result {
            case .sent:
                smsResult = .sent
            case .cancelled:
                smsResult = .cancelled
            case .failed:
                smsResult = .failed
            @unknown default:
                smsResult = .failed
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.parent.onComplete(smsResult)
                self?.parent.presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

/// View modifier for presenting SMS composer as a sheet
extension View {
    /// Present SMS composer when binding is true
    /// Automatically handles device capability check
    public func smsComposer(
        isPresented: Binding<Bool>,
        recipient: String,
        body: String,
        onComplete: @escaping (SMSResult) -> Void = { _ in }
    ) -> some View {
        sheet(isPresented: isPresented) {
            if SMSService.canSendText() {
                SMSComposerView(
                    recipient: recipient,
                    body: body,
                    onComplete: onComplete
                )
                .ignoresSafeArea()
            } else {
                // Fallback UI when SMS not available
                SMSNotAvailableView(message: body) {
                    isPresented.wrappedValue = false
                    onComplete(.notAvailable)
                }
            }
        }
    }
}

/// Fallback view when device can't send SMS
struct SMSNotAvailableView: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.paperYellow
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("SMS NOT AVAILABLE")
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundColor(Color.bloodRed)
                
                Text("Copy this message and send manually:")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.inkBlack)
                
                Text(message)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(Color.inkBlack)
                    .padding()
                    .background(Color.white.opacity(0.5))
                    .overlay(
                        Rectangle()
                            .stroke(Color.inkBlack, lineWidth: 1)
                    )
                
                Button(action: {
                    UIPasteboard.general.string = message
                }) {
                    Text("COPY MESSAGE")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(Color.paperYellow)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.inkBlack)
                }
                
                Button(action: onDismiss) {
                    Text("DISMISS")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.pencilGray)
                }
            }
            .padding()
        }
    }
}

#endif
