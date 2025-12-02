import SwiftUI

#if os(iOS)
import Contacts
import ContactsUI

/// ContactPicker - Wraps CNContactPickerViewController to select a contact
/// Returns full name (givenName + familyName) and phone number via Bindings
struct ContactPicker: UIViewControllerRepresentable {
    @Binding var selectedName: String?
    @Binding var selectedPhone: String?
    @Environment(\.presentationMode) var presentationMode

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.displayedPropertyKeys = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactPhoneNumbersKey
        ]
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    @MainActor
    class Coordinator: NSObject, CNContactPickerDelegate {
        var parent: ContactPicker

        init(_ parent: ContactPicker) {
            self.parent = parent
        }

        nonisolated func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            // Build full name from given and family name
            var fullName = contact.givenName
            if !contact.familyName.isEmpty {
                if !fullName.isEmpty {
                    fullName += " "
                }
                fullName += contact.familyName
            }

            // If no name at all, use organization name if available
            if fullName.isEmpty && !contact.organizationName.isEmpty {
                fullName = contact.organizationName
            }

            let name = fullName.isEmpty ? nil : fullName
            
            // Extract phone number (prefer mobile, then first available)
            var phone: String? = nil
            if !contact.phoneNumbers.isEmpty {
                // Try to find mobile first
                let mobileLabel = CNLabelPhoneNumberMobile
                if let mobileNumber = contact.phoneNumbers.first(where: { $0.label == mobileLabel }) {
                    phone = mobileNumber.value.stringValue
                } else {
                    // Fall back to first phone number
                    phone = contact.phoneNumbers.first?.value.stringValue
                }
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.parent.selectedName = name
                self?.parent.selectedPhone = phone
                self?.parent.presentationMode.wrappedValue.dismiss()
            }
        }

        nonisolated func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            DispatchQueue.main.async { [weak self] in
                self?.parent.presentationMode.wrappedValue.dismiss()
            }
        }
    }
}
#endif
