import SwiftUI

#if os(iOS)
import Contacts
import ContactsUI

/// ContactPicker - Wraps CNContactPickerViewController to select a contact
/// Returns full name (givenName + familyName) via Binding
struct ContactPicker: UIViewControllerRepresentable {
    @Binding var selectedName: String?
    @Environment(\.presentationMode) var presentationMode

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.displayedPropertyKeys = [CNContactGivenNameKey, CNContactFamilyNameKey]
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
            DispatchQueue.main.async { [weak self] in
                self?.parent.selectedName = name
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
