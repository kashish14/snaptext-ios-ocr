import SwiftUI
import Contacts
import ContactsUI

struct ContactCreatorView: UIViewControllerRepresentable {
    let phoneNumber: String?
    let email: String?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> UINavigationController {
        let contact = CNMutableContact()

        if let phone = phoneNumber, !phone.isEmpty {
            contact.phoneNumbers = [CNLabeledValue(
                label: CNLabelPhoneNumberMain,
                value: CNPhoneNumber(stringValue: phone)
            )]
        }

        if let email, !email.isEmpty {
            contact.emailAddresses = [CNLabeledValue(
                label: CNLabelHome,
                value: email as NSString
            )]
        }

        let vc = CNContactViewController(forNewContact: contact)
        vc.delegate = context.coordinator

        let nav = UINavigationController(rootViewController: vc)
        return nav
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    class Coordinator: NSObject, CNContactViewControllerDelegate {
        let dismiss: DismissAction

        init(dismiss: DismissAction) {
            self.dismiss = dismiss
        }

        func contactViewController(_ viewController: CNContactViewController, didCompleteWith contact: CNContact?) {
            dismiss()
        }
    }
}
