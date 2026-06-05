import CloudKit
import Combine
import Contacts
import Foundation

// MARK: - Record type constants

private enum RecordType {
    static let event          = "BailEvent"
    static let guest          = "BailGuest"
    static let vote           = "BailVote"
    static let locationOption = "BailLocationOption"
    static let locationVote   = "BailLocationVote"
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

    /// Call once on app launch. Checks iCloud status, fetches user record ID, and resolves phone number.
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

        // Try to get the user's own phone number from their Me contact card
        await resolveCurrentUserPhone()
    }

    /// Loads the stored phone number from UserDefaults (set by user in Profile).
    private func resolveCurrentUserPhone() async {
        if let stored = UserDefaults.standard.string(forKey: "currentUserPhone"), !stored.isEmpty {
            currentUserPhone = stored
            print("[CloudKit] Current user phone loaded: \(stored)")
        }
    }

    /// Call this when the user explicitly provides their phone number (e.g. onboarding).
    func setCurrentUserPhone(_ phone: String) {
        let normalized = PhoneNumberUtils.normalize(phone)
        currentUserPhone = normalized
        UserDefaults.standard.set(normalized, forKey: "currentUserPhone")
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
        isBailEvent: Bool,
        locationVotingStatus: LocationVotingStatus = .disabled,
        locationOptions: [(name: String, address: String?)] = [],
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
        eventRecord["isBailEvent"] = isBailEvent
        eventRecord["locationVotingStatus"] = locationVotingStatus.rawValue
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

        // 3. Create location option records (if location voting enabled)
        var savedLocOptions: [LocationOption] = []
        if locationVotingStatus == .voting {
            for option in locationOptions {
                let optionRecord = CKRecord(recordType: RecordType.locationOption)
                optionRecord["eventId"] = CKRecord.Reference(
                    recordID: savedEvent.recordID, action: .deleteSelf
                )
                optionRecord["name"] = option.name
                optionRecord["address"] = option.address
                optionRecord["addedBy"] = creatorID.recordName

                let saved = try await database.save(optionRecord)
                savedLocOptions.append(LocationOption(
                    id: saved.recordID.recordName,
                    eventId: eventID,
                    name: option.name,
                    address: option.address,
                    addedBy: creatorID.recordName,
                    voteCount: 0,
                    voters: []
                ))
            }
        }

        // 4. Compute required bails
        let requiredBails: Int
        switch threshold {
        case .all:      requiredBails = max(guests.count, 1)
        case .majority: requiredBails = guests.count / 2 + 1
        case .any:      requiredBails = 1
        }

        // 5. Build local Event model
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
            isBailEvent: isBailEvent,
            locationVotingStatus: locationVotingStatus,
            locationOptions: savedLocOptions,
            resolvedLocationId: nil,
            createdAt: Date()
        )

        return event
    }

    // MARK: - Cast Vote

    /// Records a vote for the current user on an event.
    /// Returns the updated Event with recalculated summary.
    func castVote(eventId: String, choice: VoteChoice) async throws -> Event {
        guard let voterID = userRecordID else {
            throw CloudKitError.notAuthenticated
        }

        // Check if user already has a vote record for this event.
        // Wrap in try-catch: if BailVote schema doesn't exist yet (first ever vote
        // on this container), the query throws — treat that as "no existing vote".
        var existingVoteRecord: CKRecord? = nil
        do {
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
            existingVoteRecord = existingVotes.first.flatMap { try? $0.1.get() }
        } catch {
            // Schema doesn't exist yet — first vote will create it
            print("[CloudKit] Vote query failed (likely first vote): \(error.localizedDescription)")
        }

        if let existing = existingVoteRecord {
            // Update existing vote
            existing["choice"] = choice.rawValue
            try await database.save(existing)
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

        // 2b. Fetch events the user has accessed via deep link (persisted by ID)
        // This ensures invited events stay visible even if phone matching fails.
        let accessedIds = Self.accessedEventIds()
        for eventId in accessedIds {
            if allEventRecords.contains(where: { $0.recordID.recordName == eventId }) { continue }
            do {
                let recordID = CKRecord.ID(recordName: eventId)
                let eventRecord = try await database.record(for: recordID)
                allEventRecords.append(eventRecord)
            } catch {
                // Event may have been deleted — remove from accessed list
                Self.removeAccessedEventId(eventId)
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
            id: old.id, title: old.title, scheduledAt: old.scheduledAt,
            location: old.location, creatorId: old.creatorId,
            threshold: old.threshold, status: newSummary.isCancelled ? .cancelled : old.status,
            summary: newSummary, guests: old.guests,
            isAnonymous: old.isAnonymous, showBailOMeter: old.showBailOMeter,
            showVotingStatus: old.showVotingStatus, isBailEvent: old.isBailEvent,
            locationVotingStatus: old.locationVotingStatus,
            locationOptions: old.locationOptions,
            resolvedLocationId: old.resolvedLocationId,
            createdAt: old.createdAt
        )
        events[index] = updated

        // If newly cancelled, update the event status in CloudKit
        if newSummary.isCancelled && old.status != .cancelled {
            try await cancelEvent(eventId: eventId)
        }

        return updated
    }

    // MARK: - Add / Remove Guests

    /// Adds a new guest to an existing event in CloudKit and updates local state.
    func addGuest(eventId: String, displayName: String, phoneNumber: String, avatarColor: String) async throws {
        let eventRecordID = CKRecord.ID(recordName: eventId)

        let guestRecord = CKRecord(recordType: RecordType.guest)
        guestRecord["eventId"] = CKRecord.Reference(recordID: eventRecordID, action: .deleteSelf)
        guestRecord["displayName"] = displayName
        guestRecord["phoneNumber"] = PhoneNumberUtils.normalize(phoneNumber)
        guestRecord["avatarColor"] = avatarColor
        guestRecord["status"] = GuestStatus.pending.rawValue

        let saved = try await database.save(guestRecord)

        let newGuest = EventGuest(
            id: saved.recordID.recordName,
            eventId: eventId,
            userId: "",
            displayName: displayName,
            phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber,
            avatarColor: avatarColor,
            status: .pending
        )

        if let index = events.firstIndex(where: { $0.id == eventId }) {
            let old = events[index]
            // Recalculate requiredBails with the new guest count
            let newGuestCount = old.guests.count + 1
            let requiredBails: Int
            switch old.threshold {
            case .all:      requiredBails = newGuestCount
            case .majority: requiredBails = newGuestCount / 2 + 1
            case .any:      requiredBails = 1
            }
            let newSummary = EventSummary(
                bailCount: old.summary.bailCount,
                totalVotes: old.summary.totalVotes,
                requiredBails: requiredBails
            )
            events[index] = Event(
                id: old.id, title: old.title, scheduledAt: old.scheduledAt,
                location: old.location, creatorId: old.creatorId,
                threshold: old.threshold, status: old.status, summary: newSummary,
                guests: old.guests + [newGuest],
                isAnonymous: old.isAnonymous, showBailOMeter: old.showBailOMeter,
                showVotingStatus: old.showVotingStatus, isBailEvent: old.isBailEvent,
                locationVotingStatus: old.locationVotingStatus,
                locationOptions: old.locationOptions,
                resolvedLocationId: old.resolvedLocationId,
                createdAt: old.createdAt
            )
        }
    }

    /// Removes a guest from an event in CloudKit and updates local state.
    func removeGuest(guestId: String, eventId: String) async throws {
        let recordID = CKRecord.ID(recordName: guestId)
        try await database.deleteRecord(withID: recordID)

        if let index = events.firstIndex(where: { $0.id == eventId }) {
            let old = events[index]
            let updatedGuests = old.guests.filter { $0.id != guestId }
            let requiredBails: Int
            switch old.threshold {
            case .all:      requiredBails = max(updatedGuests.count, 1)
            case .majority: requiredBails = updatedGuests.count / 2 + 1
            case .any:      requiredBails = 1
            }
            let newSummary = EventSummary(
                bailCount: old.summary.bailCount,
                totalVotes: old.summary.totalVotes,
                requiredBails: requiredBails
            )
            events[index] = Event(
                id: old.id, title: old.title, scheduledAt: old.scheduledAt,
                location: old.location, creatorId: old.creatorId,
                threshold: old.threshold, status: old.status, summary: newSummary,
                guests: updatedGuests,
                isAnonymous: old.isAnonymous, showBailOMeter: old.showBailOMeter,
                showVotingStatus: old.showVotingStatus, isBailEvent: old.isBailEvent,
                locationVotingStatus: old.locationVotingStatus,
                locationOptions: old.locationOptions,
                resolvedLocationId: old.resolvedLocationId,
                createdAt: old.createdAt
            )
        }
    }

    // MARK: - Fetch Single Event (for deep links)

    /// Fetches a single event by ID directly — used for deep link navigation.
    /// Works for any user who has the link, regardless of phone matching.
    func fetchEvent(byId eventId: String) async throws -> Event {
        let recordID = CKRecord.ID(recordName: eventId)
        let record = try await database.record(for: recordID)
        return try await buildEvent(from: record)
    }

    // MARK: - Delete Event

    func deleteEvent(eventId: String) async throws {
        let recordID = CKRecord.ID(recordName: eventId)
        try await database.deleteRecord(withID: recordID)
        events.removeAll { $0.id == eventId }
        userVotes.removeValue(forKey: eventId)
    }

    // MARK: - Cancel / Edit Event

    /// Marks an event as cancelled in CloudKit and updates local state.
    func cancelEvent(eventId: String) async throws {
        let recordID = CKRecord.ID(recordName: eventId)
        let record = try await database.record(for: recordID)
        record["status"] = EventStatus.cancelled.rawValue
        try await database.save(record)

        if let index = events.firstIndex(where: { $0.id == eventId }) {
            let old = events[index]
            events[index] = Event(
                id: old.id, title: old.title, scheduledAt: old.scheduledAt,
                location: old.location, creatorId: old.creatorId,
                threshold: old.threshold, status: .cancelled, summary: old.summary,
                guests: old.guests, isAnonymous: old.isAnonymous,
                showBailOMeter: old.showBailOMeter, showVotingStatus: old.showVotingStatus,
                isBailEvent: old.isBailEvent,
                locationVotingStatus: old.locationVotingStatus,
                locationOptions: old.locationOptions,
                resolvedLocationId: old.resolvedLocationId,
                createdAt: old.createdAt
            )
        }
    }

    /// Updates the title of an event in CloudKit and local state.
    func updateEventTitle(eventId: String, newTitle: String) async throws {
        let recordID = CKRecord.ID(recordName: eventId)
        let record = try await database.record(for: recordID)
        record["title"] = newTitle
        try await database.save(record)

        if let index = events.firstIndex(where: { $0.id == eventId }) {
            let old = events[index]
            events[index] = Event(
                id: old.id, title: newTitle, scheduledAt: old.scheduledAt,
                location: old.location, creatorId: old.creatorId,
                threshold: old.threshold, status: old.status, summary: old.summary,
                guests: old.guests, isAnonymous: old.isAnonymous,
                showBailOMeter: old.showBailOMeter, showVotingStatus: old.showVotingStatus,
                isBailEvent: old.isBailEvent,
                locationVotingStatus: old.locationVotingStatus,
                locationOptions: old.locationOptions,
                resolvedLocationId: old.resolvedLocationId,
                createdAt: old.createdAt
            )
        }
    }

    // MARK: - Fetch + detect cancellations

    /// Fetches events and returns any that newly transitioned to `.cancelled`
    /// since the last known local state. Used by the silent-push handler so
    /// every device (including the organizer's) can fire a local cancellation
    /// notification when a plan auto-cancels.
    func fetchEventsDetectingCancellations() async throws -> [Event] {
        let previouslyCancelled = Set(
            events.filter { $0.status == .cancelled }.map { $0.id }
        )
        try await fetchEvents()
        return events.filter {
            $0.status == .cancelled && !previouslyCancelled.contains($0.id)
        }
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

    // MARK: - Location Voting

    /// Cast a vote for a location option (visible, not anonymous).
    func castLocationVote(eventId: String, locationOptionId: String, voterDisplayName: String) async throws {
        guard let voterID = userRecordID else {
            throw CloudKitError.notAuthenticated
        }

        let eventRef = CKRecord.Reference(
            recordID: CKRecord.ID(recordName: eventId), action: .deleteSelf
        )
        let optionRef = CKRecord.Reference(
            recordID: CKRecord.ID(recordName: locationOptionId), action: .deleteSelf
        )

        // Check for existing location vote by this user on this event
        var existingRecord: CKRecord? = nil
        do {
            let pred = NSPredicate(
                format: "eventId == %@ AND voterId == %@",
                eventRef, voterID.recordName
            )
            let query = CKQuery(recordType: RecordType.locationVote, predicate: pred)
            let (results, _) = try await database.records(matching: query)
            existingRecord = results.first.flatMap { try? $0.1.get() }
        } catch {
            // Schema may not exist yet on first vote
            print("[CloudKit] Location vote query failed: \(error.localizedDescription)")
        }

        if let existing = existingRecord {
            existing["locationOptionId"] = optionRef
            try await database.save(existing)
        } else {
            let record = CKRecord(recordType: RecordType.locationVote)
            record["eventId"] = eventRef
            record["locationOptionId"] = optionRef
            record["voterId"] = voterID.recordName
            record["voterDisplayName"] = voterDisplayName
            try await database.save(record)
        }
    }

    /// Resolves location voting: picks the winner, updates the event's location field.
    func resolveLocationVote(eventId: String) async throws {
        guard let index = events.firstIndex(where: { $0.id == eventId }) else {
            throw CloudKitError.eventNotFound
        }
        let event = events[index]

        // Find the option with the most votes
        guard let winner = event.locationOptions.max(by: { $0.voteCount < $1.voteCount }) else {
            return
        }

        let resolvedLocation = winner.address != nil
            ? "\(winner.name), \(winner.address!)"
            : winner.name

        // Update CloudKit
        let recordID = CKRecord.ID(recordName: eventId)
        let record = try await database.record(for: recordID)
        record["locationVotingStatus"] = LocationVotingStatus.resolved.rawValue
        record["resolvedLocationId"] = winner.id
        record["location"] = resolvedLocation
        try await database.save(record)

        // Update local state
        let old = events[index]
        events[index] = Event(
            id: old.id, title: old.title, scheduledAt: old.scheduledAt,
            location: resolvedLocation, creatorId: old.creatorId,
            threshold: old.threshold, status: old.status, summary: old.summary,
            guests: old.guests, isAnonymous: old.isAnonymous,
            showBailOMeter: old.showBailOMeter, showVotingStatus: old.showVotingStatus,
            isBailEvent: old.isBailEvent,
            locationVotingStatus: .resolved,
            locationOptions: old.locationOptions,
            resolvedLocationId: winner.id,
            createdAt: old.createdAt
        )
    }

    /// Fetches location options + votes for an event record, returns LocationOption array.
    private func fetchLocationOptions(eventRecordID: CKRecord.ID) async throws -> [LocationOption] {
        let eventRef = CKRecord.Reference(recordID: eventRecordID, action: .deleteSelf)

        // Fetch options
        let optPred = NSPredicate(format: "eventId == %@", eventRef)
        let optQuery = CKQuery(recordType: RecordType.locationOption, predicate: optPred)

        var options: [LocationOption] = []
        do {
            let (optResults, _) = try await database.records(matching: optQuery)
            for (_, result) in optResults {
                if let rec = try? result.get() {
                    options.append(LocationOption(
                        id: rec.recordID.recordName,
                        eventId: eventRecordID.recordName,
                        name: rec["name"] as? String ?? "",
                        address: rec["address"] as? String,
                        addedBy: rec["addedBy"] as? String ?? "",
                        voteCount: 0,
                        voters: []
                    ))
                }
            }
        } catch {
            // Schema may not exist yet
            return []
        }

        guard !options.isEmpty else { return [] }

        // Fetch votes for these options
        let votePred = NSPredicate(format: "eventId == %@", eventRef)
        let voteQuery = CKQuery(recordType: RecordType.locationVote, predicate: votePred)

        do {
            let (voteResults, _) = try await database.records(matching: voteQuery)
            for (_, result) in voteResults {
                if let voteRec = try? result.get(),
                   let optRef = voteRec["locationOptionId"] as? CKRecord.Reference {
                    let optId = optRef.recordID.recordName
                    if let idx = options.firstIndex(where: { $0.id == optId }) {
                        options[idx].voteCount += 1
                        options[idx].voters.append(LocationVoter(
                            id: voteRec.recordID.recordName,
                            guestId: voteRec["voterId"] as? String ?? "",
                            displayName: voteRec["voterDisplayName"] as? String ?? "Someone"
                        ))
                    }
                }
            }
        } catch {
            // No votes yet
        }

        return options
    }

    // MARK: - Accessed Event Persistence

    private static let accessedEventIdsKey = "accessedEventIds"

    /// Returns the set of event IDs the user has accessed via deep link.
    static func accessedEventIds() -> Set<String> {
        let array = UserDefaults.standard.array(forKey: accessedEventIdsKey) as? [String] ?? []
        return Set(array)
    }

    /// Adds an event ID to the persistent list of accessed events.
    static func addAccessedEventId(_ id: String) {
        var ids = accessedEventIds()
        ids.insert(id)
        UserDefaults.standard.set(Array(ids), forKey: accessedEventIdsKey)
    }

    /// Removes an event ID (e.g. when it has been deleted from CloudKit).
    static func removeAccessedEventId(_ id: String) {
        var ids = accessedEventIds()
        ids.remove(id)
        UserDefaults.standard.set(Array(ids), forKey: accessedEventIdsKey)
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

        // Location voting
        let locVotingRaw = record["locationVotingStatus"] as? String ?? "disabled"
        let locVotingStatus = LocationVotingStatus(rawValue: locVotingRaw) ?? .disabled
        var locOptions: [LocationOption] = []
        if locVotingStatus != .disabled {
            locOptions = try await fetchLocationOptions(eventRecordID: record.recordID)
        }

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
            isBailEvent: record["isBailEvent"] as? Bool ?? true,
            locationVotingStatus: locVotingStatus,
            locationOptions: locOptions,
            resolvedLocationId: record["resolvedLocationId"] as? String,
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
