import Foundation

// MARK: - Supporting Types

enum EventStatus: String, Codable {
    case pending
    case active
    case cancelled
}

enum BailThreshold: String, Codable {
    case all
    case majority
    case any

    var displayName: String {
        switch self {
        case .all:      return "Everyone bails"
        case .majority: return "Majority bails"
        case .any:      return "Anyone bails"
        }
    }

    var description: String {
        switch self {
        case .all:      return "100% must opt out to cancel"
        case .majority: return "More than half opt out"
        case .any:      return "Even one bail cancels it"
        }
    }
}

// MARK: - Event

struct Event: Identifiable, Codable {
    let id: String
    let title: String
    let scheduledAt: Date
    let location: String?
    let creatorId: String
    let threshold: BailThreshold
    let status: EventStatus
    let summary: EventSummary
    let guests: [EventGuest]
    let isAnonymous: Bool
    let showBailOMeter: Bool
    let showVotingStatus: Bool
    let createdAt: Date
}

// MARK: - EventSummary
//
// Aggregate-only view of vote state. Individual votes are never returned by the API —
// the server exposes only these counts, keeping every vote permanently anonymous.

struct EventSummary: Codable {
    let bailCount: Int
    let totalVotes: Int
    let requiredBails: Int

    var progress: Double {
        guard requiredBails > 0 else { return 0 }
        return min(Double(bailCount) / Double(requiredBails), 1)
    }

    var isCancelled: Bool {
        bailCount >= requiredBails
    }
}
