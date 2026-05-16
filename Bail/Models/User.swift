import Foundation

struct User: Identifiable, Codable {
    let id: String
    let appleUserId: String
    let displayName: String
    let createdAt: Date
}
