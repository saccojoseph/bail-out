import Contacts
import Foundation

struct AppContact: Identifiable {
    let id: String
    let displayName: String
    let phoneNumber: String
    let avatarColor: String
}

@MainActor
final class ContactsService: ObservableObject {
    @Published var contacts: [AppContact] = []
    @Published var authStatus: CNAuthorizationStatus = .notDetermined

    func requestAccess() async {
        let store = CNContactStore()
        do {
            let granted = try await store.requestAccess(for: .contacts)
            authStatus = granted ? .authorized : .denied
            if granted { await load(store: store) }
        } catch {
            authStatus = .denied
        }
    }

    private func load(store: CNContactStore) async {
        let keys = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactPhoneNumbersKey
        ] as [CNKeyDescriptor]
        let request = CNContactFetchRequest(keysToFetch: keys)

        var loaded: [AppContact] = []
        try? store.enumerateContacts(with: request) { contact, _ in
            guard let phone = contact.phoneNumbers.first?.value.stringValue,
                  !phone.isEmpty else { return }
            let name = [contact.givenName, contact.familyName]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            guard !name.isEmpty else { return }
            loaded.append(AppContact(
                id: contact.identifier,
                displayName: name,
                phoneNumber: phone,
                avatarColor: Self.color(for: name)
            ))
        }
        contacts = loaded.sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
    }

    static func color(for name: String) -> String {
        let palette = ["FF6B6B","4ECDC4","FFE66D","A8E6CF","FF8B94","6C5CE7","FDCB6E","00B894"]
        return palette[abs(name.hashValue) % palette.count]
    }
}
