import Foundation

// MARK: - VoteChoice

// The two options a guest can choose when voting.
enum VoteChoice: String, Codable {
    case `in` = "in"
    case bail  = "bail"
}

// MARK: - CastVoteRequest
//
// Write-only payload sent to the server when a user casts their vote.
//
// ANONYMITY CONTRACT: The server creates and persists the Vote record.
// The client NEVER receives individual vote data back — only an updated EventSummary
// with aggregate counts. There is intentionally no Vote response type on the client.

struct CastVoteRequest: Encodable {
    let eventId: String
    let choice: VoteChoice
}
