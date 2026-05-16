import CloudKit
import Combine
import Foundation

// MARK: - Record type constants

private enum RecordType {
    static let event = "BailEvent"
    static let guest = "BailGuest"
    static let vote  = "BailVote"
}

// MARK: - CloudKitService

@MainActor
final class CloudKitService: ObservableObject {

    static let shared = CloudKitService()

    // MARK: - Published state

    @Published var events: [Event] = []
    @Published var userVotes: [String: VoteChoice] = [:]   // eventId → user's vote
    @Published var currentUserPhone: String = ""            // normalized phone for matching
    @Published var iCloudAvailable = false
    @Published var userRecordID: CKRecord.ID?

    // MARK: - Private

    private let container = CKContainer(identifier: "iCloud.com.sacco.bail-app")
    private var database: CKDatabase { container.publicCloudDatabase }

    private init() {}

    // MARK: - Setup

    /// Call once on app launch. Checks iCloud status and fetches the user record ID.
    func setup() async {
        do {
            let status = try await container.accountStatus()
            iCloudAvailable = (status == .available)

            if iCloudAvailable {
                let recordID = try await container.userRecordID()
                userRecordID = recordID
            }
        } catch {
            iCloudAvailable = false
            print("[CloudKit] Setup error: \(error.localizedDescription)")
        }
    }

    // MARK: - Create Event

    /// Saves a new event + guest records to CloudKit. Returns the created Event.
    func createEvent(
        title: String,
        scheduledAt: Date,
        location: String?,
        threshold: BailThreshold,
        isAnonymous: Bool,
        showBailOMeter: Bool,
        showVotingStatus: Bool,
        guests: [(displayName: String, phoneNumber: String, avatarColor: String)]
    ) async throws -> Event {
        guard let creatorID = userRecordID else {
            throw CloudKitError.notAuthenticated
        }

        // 1. Create the event record
        let eventRecord = CKRecord(recordType: RecordType.event)
        eventRecord["title"] = title
        eventRecord["scheduledAt"] = scheduledAt
        eventRecord["location"] = location
        eventRecord["creatorId"] = creatorID.recordName
        eventRecord["threshold"] = threshold.rawValue
        eventRecord["status"] = EventStatus.active.rawValue
        eventRecord["isAnonymous"] = isAnonymous
        eventRecord["showBailOMeter"] = showBailOMeter
        eventRecord["showVotingStatus"] = showVotingStatus
        eventRecord["createdAt"] = Date()

        let savedEvent = try await database.save(eventRecord)
        let eventID = savedEvent.recordID.recordName

        // 2. Create guest records
        var eventGuests: [EventGuest] = []
        for guest in guests {
            let guestRecord = CKRecord(recordType: RecordType.guest)
            guestRecord["eventId"] = CKRecord.Reference(
                recordID: savedEvent.recordID,
                action: .deleteSelf
            )
            guestRecord["displayName"] = guest.displayName
            guestRecord["phoneNumber"] = PhoneNumberUtils.normalize(guest.phoneNumber)
            guestRecord["avatarColor"] = guest.avatarColor
            guestRecord["status"] = GuestStatus.pending.rawValue

            let savedGuest = try await database.save(guestRecord)
            eventGuests.append(EventGuest(
                id: savedGuest.recordID.recordName,
                eventId: eventID,
                userId: "",
                displayName: guest.displayName,
                phoneNumber: guest.phoneNumber,
                avatarColor: guest.avatarColor,
                status: .pending
            ))
        }

        // 3. Compute required bails
        let requiredBails: Int
        switch threshold {
        case .all:      requiredBails = max(guests.count, 1)
        case .majority: requiredBails = guests.count / 2 + 1
        case .any:      requiredBails = 1
        }

        // 4. Build local Event model
        let event = Event(
            id: eventID,
            title: title,
            scheduledAt: scheduledAt,
            location: location,
            creatorId: creatorID.recordName,
            threshold: threshold,
            status: .active,
            summary: EventSummary(bailCount: 0, totalVotes: 0, requiredBails: requiredBails),
            guests: eventGuests,
            isAnonymous: isAnonymous,
            showBailOMeter: showBailOMeter,
            showVotingStatus: showVotingStatus,
            createdAt: Date()
        )

        // Note: caller is responsible for inserting into events array
        // (ContentView does optimistic local insert before calling this)
        return event
    }

    // MARK: - Cast Vote

    /// Records a vote for the current user on an event.
    /// Returns the updated Event with recalculated summary.
    func castVote(eventId: String, choice: VoteChoice) async throws -> Event {
        guard let voterID = userRecordID else {
            throw CloudKitError.notAuthenticated
        }

        let previousChoice = userVotes[eventId]

        // Check if user already has a vote record for this event
        let predicate = NSPredicate(
            format: "eventId == %@ AND voterId == %@",
            CKRecord.Reference(
                recordID: CKRecord.ID(recordName: eventId),
                action: .deleteSelf
            ),
            voterID.recordName
        )
        let query = CKQuery(recordType: RecordType.vote, predicate: predicate)
        let (existingVotes, _) = try await database.records(matching: query)

        if let (existingID, existingResult) = existingVotes.first,
           let existingRecord = try? existingResult.get() {
            // Update existing vote
            existingRecord["choice"] = choice.rawValue
            try await database.save(existingRecord)
        } else {
            // Create new vote
            let voteRecord = CKRecord(recordType: RecordType.vote)
            voteRecord["eventId"] = CKRecord.Reference(
                recordID: CKRecord.ID(recordName: eventId),
                action: .deleteSelf
            )
            voteRecord["voterId"] = voterID.recordName
            voteRecord["choice"] = choice.rawValue
            try await database.save(voteRecord)
        }

        // Update local state
        userVotes[eventId] = choice

        // Refresh the event's vote aggregates
        return try await refreshEventSummary(eventId: eventId)
    }

    // MARK: - Fetch Events

    /// Fetches all events the current user created OR is invited to.
    func fetchEvents() async throws {
        guard let userID = userRecordID else {
            throw CloudKitError.notAuthenticated
        }

        // 1. Fetch events the user created
        let createdPredicate = NSPredicate(format: "creatorId == %@", userID.recordName)
        let createdQuery = CKQuery(recordType: RecordType.event, predicate: createdPredicate)
        createdQuery.sortDescriptors = [NSSortDescriptor(key: "scheduledAt", ascending: true)]
        let (createdResults, _) = try await database.records(matching: createdQuery)

        var allEventRecords: [CKRecord] = []
        for (_, result) in createdResults {
            if let record = try? result.get() {
                allEventRecords.append(record)
            }
        }

        // 2. Fetch events the user is invited to (by phone number)
        if !currentUserPhone.isEmpty {
            let invitedPredicate = NSPredicate(
                format: "phoneNumber == %@",
                PhoneNumberUtils.normalize(currentUserPhone)
            )
            let guestQuery = CKQuery(recordType: RecordType.guest, predicate: invitedPredicate)
            let (guestResults, _) = try await database.records(matching: guestQuery)

            for (_, result) in guestResults {
                if let guestRecord = try? result.get(),
                   let eventRef = guestRecord["eventId"] as? CKRecord.Reference {
                    do {
                        let eventRecord = try await database.record(for: eventRef.recordID)
                        // Avoid duplicates (user might be creator AND invited)
                        if !allEventRecords.contains(where: {
                            $0.recordID.recordName == eventRecord.recordID.recordName
                        }) {
                            allEventRecords.append(eventRecord)
                        }
                    } catch {
                        // Event may have been deleted
                        continue
                    }
                }
            }
        }

        // 3. Convert each record to an Event with guests and summary
        var loadedEvents: [Event] = []
        for record in allEventRecords {
            let event = try await buildEvent(from: record)
            loadedEvents.append(event)
        }

        // 4. Fetch user's votes for these events
        for event in loadedEvents {
            let votePredicate = NSPredicate(
                format: "eventId == %@ AND voterId == %@",
                CKRecord.Reference(
                    recordID: CKRecord.ID(recordName: event.id),
                    action: .deleteSelf
                ),
                userID.recordName
            )
            let voteQuery = CKQuery(recordType: RecordType.vote, predicate: votePredicate)
            let (voteResults, _) = try await database.records(matching: voteQuery)

            if let (_, voteResult) = voteResults.first,
               let voteRecord = try? voteResult.get(),
               let choiceRaw = voteRecord["choice"] as? String,
               let choice = VoteChoice(rawValue: choiceRaw) {
                userVotes[event.id] = choice
            }
        }

        events = loadedEvents.sorted { $0.scheduledAt < $1.scheduledAt }
    }

    // MARK: - Refresh Summary

    /// Re-queries vote aggregates for a single event and updates local state.
    @discardableResult
    func refreshEventSummary(eventId: String) async throws -> Event {
        // Count all votes for this event
        let allVotesPredicate = NSPredicate(
            format: "eventId == %@",
            CKRecord.Reference(
                recordID: CKRecord.ID(recordName: eventId),
                action: .deleteSelf
            )
        )
        let allVotesQuery = CKQuery(recordType: RecordType.vote, predicate: allVotesPredicate)
        let (allResults, _) = try await database.records(matching: allVotesQuery)

        var bailCount = 0
        var totalVotes = 0
        for (_, result) in allResults {
            if let record = try? result.get(),
               let choiceRaw = record["choice"] as? String {
                totalVotes += 1
                if choiceRaw == VoteChoice.bail.rawValue {
                    bailCount += 1
                }
            }
        }

        // Update the local event
        guard let index = events.firstIndex(where: { $0.id == eventId }) else {
            throw CloudKitError.eventNotFound
        }
        let old = events[index]
        let newSummary = EventSummary(
            bailCount: bailCount,
            totalVotes: totalVotes,
            requiredBails: old.summary.requiredBails
        )
        let updated = Event(
            id: old.id,
            title: old.title,
            scheduledAt: old.scheduledAt,
            location: old.location,
            creatorId: old.creatorId,
            threshold: old.threshold,
            status: newSummary.isCancelled ? .cancelled : old.status,
            summary: newSummary,
            guests: old.guests,
            isAnonymous: old.isAnonymous,
            showBailOMeter: old.showBailOMeter,
            showVotingStatus: old.showVotingStatus,
            createdAt: old.createdAt
        )
        events[index] = updated

        // If newly cancelled, update the event status in CloudKit
        if newSummary.isCancelled && old.status != .cancelled {
            try await markEventCancelled(eventId: eventId)
        }

        return updated
    }

    // MARK: - Delete Event

    /// Deletes an event and its associated guest/vote records from CloudKit.
    func deleteEvent(eventId: String) async throws {
        let recordID = CKRecord.ID(recordName: eventId)

        // Delete the event record (guests and votes use .deleteSelf action,
        // so CloudKit automatically cascades the delete)
        try await database.deleteRecord(withID: recordID)

        // Remove from local state
        events.removeAll { $0.id == eventId }
        userVotes.removeValue(forKey: eventId)
    }

    // MARK: - Cancel Event in CloudKit

    private func markEventCancelled(eventId: String) async throws {
        let recordID = CKRecord.ID(recordName: eventId)
        let record = try await database.record(for: recordID)
        record["status"] = EventStatus.cancelled.rawValue
        try await database.save(record)
    }

    // MARK: - Subscribe to vote changes

    /// Creates a CloudKit subscription so the app gets push notifications
    /// when new votes are cast on events the user is part of.
    func subscribeToVoteChanges() async {
        let subscriptionID = "vote-changes"

        // Check if subscription already exists
        do {
            _ = try await database.subscription(for: subscriptionID)
            return // Already subscribed
        } catch {
            // Doesn't exist yet, create it
        }

        let predicate = NSPredicate(value: true) // All vote records
        let subscription = CKQuerySubscription(
            recordType: RecordType.vote,
            predicate: predicate,
            subscriptionID: subscriptionID,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )

        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true // Silent push
        subscription.notificationInfo = info

        do {
            try await database.save(subscription)
        } catch {
            print("[CloudKit] Subscription error: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Helpers

    /// Builds a full Event model from a CKRecord, including guests and vote summary.
    private func buildEvent(from record: CKRecord) async throws -> Event {
        let eventID = record.recordID.recordName

        // Fetch guests
        let guestPredicate = NSPredicate(
            format: "eventId == %@",
            CKRecord.Reference(recordID: record.recordID, action: .deleteSelf)
        )
        let guestQuery = CKQuery(recordType: RecordType.guest, predicate: guestPredicate)
        let (guestResults, _) = try await database.records(matching: guestQuery)

        var guests: [EventGuest] = []
        for (_, result) in guestResults {
            if let guestRecord = try? result.get() {
                guests.append(EventGuest(
                    id: guestRecord.recordID.recordName,
                    eventId: eventID,
                    userId: "",
                    displayName: guestRecord["displayName"] as? String ?? "Unknown",
                    phoneNumber: guestRecord["phoneNumber"] as? String,
                    avatarColor: guestRecord["avatarColor"] as? String ?? "666666",
                    status: GuestStatus(rawValue: guestRecord["status"] as? String ?? "pending") ?? .pending
                ))
            }
        }

        // Count votes (aggregate only — never expose individual votes)
        let votePredicate = NSPredicate(
            format: "eventId == %@",
            CKRecord.Reference(recordID: record.recordID, action: .deleteSelf)
        )
        let voteQuery = CKQuery(recordType: RecordType.vote, predicate: votePredicate)
        let (voteResults, _) = try await database.records(matching: voteQuery)

        var bailCount = 0
        var totalVotes = 0
        for (_, result) in voteResults {
            if let voteRecord = try? result.get(),
               let choiceRaw = voteRecord["choice"] as? String {
                totalVotes += 1
                if choiceRaw == VoteChoice.bail.rawValue {
                    bailCount += 1
                }
            }
        }

        // Compute required bails from threshold + guest count
        let thresholdRaw = record["threshold"] as? String ?? "majority"
        let threshold = BailThreshold(rawValue: thresholdRaw) ?? .majority
        let requiredBails: Int
        switch threshold {
        case .all:      requiredBails = max(guests.count, 1)
        case .majority: requiredBails = guests.count / 2 + 1
        case .any:      requiredBails = 1
        }

        let statusRaw = record["status"] as? String ?? "active"
        let status = EventStatus(rawValue: statusRaw) ?? .active

        return Event(
            id: eventID,
            title: record["title"] as? String ?? "Untitled",
            scheduledAt: record["scheduledAt"] as? Date ?? Date(),
            location: record["location"] as? String,
            creatorId: record["creatorId"] as? String ?? "",
            threshold: threshold,
            status: status,
            summary: EventSummary(
                bailCount: bailCount,
                totalVotes: totalVotes,
                requiredBails: requiredBails
            ),
            guests: guests,
            isAnonymous: record["isAnonymous"] as? Bool ?? true,
            showBailOMeter: record["showBailOMeter"] as? Bool ?? true,
            showVotingStatus: record["showVotingStatus"] as? Bool ?? true,
            createdAt: record["createdAt"] as? Date ?? Date()
        )
    }
}

// MARK: - Errors

enum CloudKitError: LocalizedError {
    case notAuthenticated
    case eventNotFound

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "iCloud account required. Sign in to iCloud in Settings."
        case .eventNotFound:
            return "Event not found."
        }
    }
}
