import Foundation

enum GuestStatus: String, Codable {
    case pending
    case voted
}

struct EventGuest: Identifiable, Codable {
    let id: String
    let eventId: String
    let userId: String
    let displayName: String
    let phoneNumber: String?
    let avatarColor: String
    let status: GuestStatus
}
