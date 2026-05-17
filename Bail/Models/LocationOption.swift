import Foundation

// MARK: - Location Voting Status

enum LocationVotingStatus: String, Codable {
    case disabled       // single fixed location (default, current behavior)
    case voting         // location vote in progress — guests choose a spot
    case resolved       // vote complete, winning location locked in
}

// MARK: - Location Option

/// One of the possible venue choices in a location vote.
struct LocationOption: Identifiable, Codable {
    let id: String
    let eventId: String
    let name: String           // "Joe's Pizza"
    let address: String?       // "123 Main St, Brooklyn, NY"
    let addedBy: String        // creatorId who added it
    var voteCount: Int
    var voters: [LocationVoter]
}

// MARK: - Location Voter

/// Visible attribution — location votes are NOT anonymous.
struct LocationVoter: Identifiable, Codable {
    let id: String             // vote record ID
    let guestId: String
    let displayName: String
}
