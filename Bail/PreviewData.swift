#if DEBUG
import Foundation

enum PreviewData {

    static let guests: [EventGuest] = [
        EventGuest(id: "g1", eventId: "e1", userId: "u1", displayName: "Sarah", phoneNumber: nil, avatarColor: "FF6B6B", status: .voted),
        EventGuest(id: "g2", eventId: "e1", userId: "u2", displayName: "Mike",  phoneNumber: nil, avatarColor: "4ECDC4", status: .voted),
        EventGuest(id: "g3", eventId: "e1", userId: "u3", displayName: "Jess",  phoneNumber: nil, avatarColor: "FFE66D", status: .pending),
        EventGuest(id: "g4", eventId: "e1", userId: "u4", displayName: "Dan",   phoneNumber: nil, avatarColor: "A8E6CF", status: .pending),
    ]

    static let sampleEvents: [Event] = [
        Event(
            id: "e1",
            title: "Dinner at Zinc",
            scheduledAt: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date(),
            location: "Zinc Restaurant, New Haven",
            creatorId: "u0",
            threshold: .majority,
            status: .active,
            summary: EventSummary(bailCount: 2, totalVotes: 3, requiredBails: 3),
            guests: guests,
            isAnonymous: true,
            showBailOMeter: true,
            showVotingStatus: true,
            isBailEvent: true,
            createdAt: Date()
        ),
        Event(
            id: "e2",
            title: "Bowling Night",
            scheduledAt: Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date(),
            location: nil,
            creatorId: "u0",
            threshold: .majority,
            status: .active,
            summary: EventSummary(bailCount: 0, totalVotes: 1, requiredBails: 2),
            guests: Array(guests.prefix(3)),
            isAnonymous: false,
            showBailOMeter: false,
            showVotingStatus: false,
            isBailEvent: false,
            createdAt: Date()
        ),
    ]

    static let currentUser = User(
        id: "u0",
        appleUserId: "apple.u0",
        displayName: "Joe",
        createdAt: Date()
    )
}
#endif
