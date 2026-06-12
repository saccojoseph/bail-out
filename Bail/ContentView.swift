import SwiftUI
import UserNotifications
import UIKit
import CloudKit

enum AppScreen {
    case splash
    case onboarding
    case home
    case createEvent
    case eventDetail
    case vote
    case locationVote
    case cancelled
}

struct ContentView: View {
    @StateObject private var cloudKit = CloudKitService.shared
    @State private var screen: AppScreen = {
        let completed = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        let seen = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
        return (completed && seen) ? .home : .splash
    }()
    @State private var selectedEvent: Event?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var errorTitle: String = "Something went wrong"
    @State private var userName: String = "there"
    @State private var handlingDeepLinkId: String?
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("userDisplayName") private var storedDisplayName = ""

    /// Name shown in the UI and attached to visible (location) votes.
    /// Prefers the name the user typed during onboarding; falls back to the
    /// device-name heuristic for users who skipped it.
    private var effectiveUserName: String {
        storedDisplayName.isEmpty ? userName : storedDisplayName
    }

    var body: some View {
        ZStack {
            switch screen {
            case .splash:
                SplashView(
                    onSignIn: { startApp() }
                )
                .transition(.opacity)
                .onAppear {
#if DEBUG
                    // Screenshot mode handles its own routing via applyScreenshotMode()
                    if ProcessInfo.processInfo.arguments.contains("-ScreenshotMode") { return }
#endif
                    // Only auto-skip splash for returning users who've completed onboarding
                    if hasCompletedOnboarding && hasSeenOnboarding {
                        startApp()
                    }
                }

            case .onboarding:
                OnboardingView(onDone: {
                    hasSeenOnboarding = true
                    screen = .home
                })
                .transition(.opacity)

            case .home:
                HomeView(
                    events: cloudKit.events,
                    userName: effectiveUserName,
                    currentUserId: cloudKit.userRecordID?.recordName ?? "",
                    isLoading: isLoading,
                    onCreateEvent: { screen = .createEvent },
                    onSelectEvent: { event in
                        selectedEvent = event
                        screen = .eventDetail
                    },
                    onDeleteEvent: { eventId in
                        handleDeleteEvent(eventId: eventId)
                    },
                    onLeaveEvent: { eventId in
                        handleLeaveEvent(eventId: eventId)
                    },
                    onRefresh: {
                        try? await cloudKit.fetchEvents()
                        scheduleRemindersForVisibleEvents()
                    },
                    onSignOut: { handleSignOut() }
                )
                .transition(.opacity)
                .task {
                    // Returning users skip splash — kick off CloudKit setup here
                    if cloudKit.userRecordID == nil {
                        await cloudKit.setup()
                        await fetchUserName()
                        isLoading = true
                        try? await cloudKit.fetchEvents()
                        scheduleRemindersForVisibleEvents()
                        await cloudKit.subscribeToVoteChanges()
                        isLoading = false
                    }
                }

            case .createEvent:
                CreateEventView(
                    onDismiss: { screen = .home },
                    onComplete: { newEvent in
                        handleNewEvent(newEvent)
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))

            case .eventDetail:
                if let event = selectedEvent {
                    EventDetailView(
                        event: event,
                        userVote: cloudKit.userVotes[event.id],
                        isCreator: cloudKit.userRecordID?.recordName == event.creatorId,
                        onBack: { screen = .home },
                        onVote: { screen = .vote },
                        onLocationVote: { screen = .locationVote },
                        onAddGuests: { guests in
                            for g in guests {
                                handleAddGuest(eventId: event.id, name: g.name, phone: g.phone, color: g.color)
                            }
                        },
                        onRemoveGuest: { guestId in
                            handleRemoveGuest(guestId: guestId, eventId: event.id)
                        },
                        onCancelEvent: { handleCancelEvent(eventId: event.id) },
                        onEditTitle: { newTitle in handleEditTitle(eventId: event.id, newTitle: newTitle) }
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }

            case .vote:
                if let event = selectedEvent {
                    VoteView(
                        event: event,
                        existingVote: cloudKit.userVotes[event.id],
                        onBack: { screen = .eventDetail },
                        onVoteCast: { choice in
                            // Commits the vote; navigation happens in onDone so
                            // the user sees the confirmation screen first.
                            handleVote(eventId: event.id, choice: choice)
                        },
                        onDone: {
                            let nowCancelled = cloudKit.events
                                .first(where: { $0.id == event.id })?.status == .cancelled
                            screen = nowCancelled ? .cancelled : .home
                        }
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }

            case .locationVote:
                if let event = selectedEvent {
                    LocationVoteView(
                        event: event,
                        currentUserId: cloudKit.userRecordID?.recordName ?? "",
                        onBack: { screen = .eventDetail },
                        onVote: { optionId in
                            handleLocationVote(eventId: event.id, locationOptionId: optionId)
                        }
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }

            case .cancelled:
                if let event = selectedEvent {
                    CancelledView(
                        event: event,
                        onDone: { screen = .home }
                    )
                    .transition(.opacity)
                }
            }

            // Loading overlay
            if isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.2)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: screen)

        .task {
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-ScreenshotMode") {
                applyScreenshotMode()
                return
            }
#endif
            await NotificationService.shared.requestPermission()
        }
        .alert(errorTitle, isPresented: showingError) {
            Button("OK") {
                errorMessage = nil
                errorTitle = "Something went wrong"
            }
        } message: {
            Text(errorMessage ?? "Something went wrong.")
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }

    /// Derives a first name from the device name (e.g. "Joseph's iPhone" → "Joseph").
    private func fetchUserName() async {
        let deviceName = await UIDevice.current.name
        // Device names are typically "Joseph's iPhone" or "Joseph's iPhone 16 Pro".
        // Generic names like "iPhone" would read as "Hey iPhone 👋" — fall back
        // to "there" instead.
        if let firstName = deviceName.components(separatedBy: "'").first,
           !firstName.isEmpty,
           !["iphone", "ipad", "ipod"].contains(where: { firstName.lowercased().hasPrefix($0) }) {
            userName = firstName
        }
    }

    private var showingError: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    // MARK: - App Launch

    private func startApp() {
        isLoading = true
        hasCompletedOnboarding = true
        Task {
            await cloudKit.setup()
            await fetchUserName()

            if cloudKit.iCloudAvailable {
                do {
                    try await cloudKit.fetchEvents()
                    scheduleRemindersForVisibleEvents()
                    await cloudKit.subscribeToVoteChanges()
                } catch {
                    print("[ContentView] Fetch error: \(error.localizedDescription)")
                    // Non-fatal — user just sees empty list
                }
            }

            isLoading = false
            screen = hasSeenOnboarding ? .home : .onboarding
        }
    }

    /// Schedules the 1-hour reminder for every upcoming event the user can see,
    /// including ones they were invited to (not just ones they created).
    /// Idempotent — UNUserNotificationCenter dedupes by identifier.
    private func scheduleRemindersForVisibleEvents() {
        for event in cloudKit.events where event.status != .cancelled && event.scheduledAt > Date() {
            NotificationService.shared.scheduleReminder(for: event)
        }
    }

    // MARK: - New Event (local-first, then sync)

    /// CreateEventView still builds the Event locally.
    /// We take that local event and also push it to CloudKit.
    private func handleNewEvent(_ localEvent: Event) {
        // Immediately add to local list so the UI feels instant
        cloudKit.events.insert(localEvent, at: 0)
        NotificationService.shared.scheduleReminder(for: localEvent)
        screen = .home

        // Sync to CloudKit in background
        Task {
            // Re-run setup if userRecordID isn't ready yet (handles cold-launch race condition)
            if cloudKit.userRecordID == nil {
                await cloudKit.setup()
            }
            do {
                let guests = localEvent.guests.map {
                    (displayName: $0.displayName,
                     phoneNumber: $0.phoneNumber ?? "",
                     avatarColor: $0.avatarColor)
                }
                let locationOpts = localEvent.locationOptions.map {
                    (name: $0.name, address: $0.address)
                }
                let cloudEvent = try await cloudKit.createEvent(
                    eventId: localEvent.id,
                    title: localEvent.title,
                    scheduledAt: localEvent.scheduledAt,
                    location: localEvent.location,
                    threshold: localEvent.threshold,
                    isAnonymous: localEvent.isAnonymous,
                    showBailOMeter: localEvent.showBailOMeter,
                    showVotingStatus: localEvent.showVotingStatus,
                    isBailEvent: localEvent.isBailEvent,
                    locationVotingStatus: localEvent.locationVotingStatus,
                    locationOptions: locationOpts,
                    guests: guests
                )
                // Replace local placeholder with CloudKit version (has real IDs)
                if let index = cloudKit.events.firstIndex(where: { $0.id == localEvent.id }) {
                    cloudKit.events[index] = cloudEvent
                }
                // Subscribe to pushes for the new event
                await cloudKit.subscribeToVoteChanges()
            } catch {
                print("[CloudKit] createEvent failed: \(error)")
                if let ckError = error as? CKError {
                    print("[CloudKit] CKError code: \(ckError.code.rawValue) — \(ckError.localizedDescription)")
                }
                errorTitle = "Couldn't save plan"
                if case CloudKitError.notAuthenticated = error {
                    errorMessage = "iCloud is not available. Make sure you're signed into iCloud in Settings and try again."
                } else {
                    errorMessage = "Your plan was created locally but couldn't sync to iCloud. Check your connection and try again."
                }
            }
        }
    }

    // MARK: - Vote Handling

    private func handleVote(eventId: String, choice: VoteChoice) {
        // Optimistic local update for instant UI feedback
        let previousChoice = cloudKit.userVotes[eventId]
        cloudKit.userVotes[eventId] = choice

        if let index = cloudKit.events.firstIndex(where: { $0.id == eventId }) {
            let old = cloudKit.events[index]
            var newBailCount = old.summary.bailCount
            var newTotalVotes = old.summary.totalVotes

            if let prev = previousChoice {
                if prev == .bail && choice == .in  { newBailCount -= 1 }
                if prev == .in  && choice == .bail { newBailCount += 1 }
            } else {
                if choice == .bail { newBailCount += 1 }
                newTotalVotes += 1
            }

            let newSummary = EventSummary(
                bailCount: max(0, newBailCount),
                totalVotes: newTotalVotes,
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
                isBailEvent: old.isBailEvent,
                locationVotingStatus: old.locationVotingStatus,
                locationOptions: old.locationOptions,
                resolvedLocationId: old.resolvedLocationId,
                createdAt: old.createdAt
            )
            cloudKit.events[index] = updated
            selectedEvent = updated

            if newSummary.isCancelled {
                NotificationService.shared.cancelPending(for: eventId)
                NotificationService.shared.scheduleCancellation(for: updated)
            }
            // Navigation is handled by VoteView's onDone so the voter sees
            // the confirmation screen before returning.
        }

        // Sync to CloudKit in background
        Task {
            do {
                _ = try await cloudKit.castVote(eventId: eventId, choice: choice)
            } catch {
                errorTitle = "Vote didn't sync"
                errorMessage = "Your vote was saved locally but couldn't reach iCloud. Don't worry — it'll sync automatically."
            }
        }
    }

    // MARK: - Sign Out

    private func handleSignOut() {
        // Clear all local state
        cloudKit.events = []
        cloudKit.userVotes = [:]
        selectedEvent = nil
        userName = "there"
        hasCompletedOnboarding = false
        hasSeenOnboarding = false
        screen = .splash
    }

    // MARK: - Add / Remove Guest

    private func handleAddGuest(eventId: String, name: String, phone: String, color: String) {
        Task {
            do {
                try await cloudKit.addGuest(eventId: eventId, displayName: name,
                                            phoneNumber: phone, avatarColor: color)
                selectedEvent = cloudKit.events.first { $0.id == eventId }
            } catch {
                errorTitle = "Couldn't add person"
                errorMessage = "There was a problem saving to iCloud. Try again."
            }
        }
    }

    private func handleRemoveGuest(guestId: String, eventId: String) {
        // Optimistic local removal
        if let index = cloudKit.events.firstIndex(where: { $0.id == eventId }) {
            let old = cloudKit.events[index]
            let updated = Event(
                id: old.id, title: old.title, scheduledAt: old.scheduledAt,
                location: old.location, creatorId: old.creatorId,
                threshold: old.threshold, status: old.status, summary: old.summary,
                guests: old.guests.filter { $0.id != guestId },
                isAnonymous: old.isAnonymous, showBailOMeter: old.showBailOMeter,
                showVotingStatus: old.showVotingStatus, isBailEvent: old.isBailEvent,
                locationVotingStatus: old.locationVotingStatus,
                locationOptions: old.locationOptions,
                resolvedLocationId: old.resolvedLocationId,
                createdAt: old.createdAt
            )
            cloudKit.events[index] = updated
            selectedEvent = updated
        }
        Task {
            do {
                try await cloudKit.removeGuest(guestId: guestId, eventId: eventId)
            } catch {
                errorTitle = "Couldn't remove person"
                errorMessage = "There was a problem syncing to iCloud."
                try? await cloudKit.fetchEvents()
                selectedEvent = cloudKit.events.first { $0.id == eventId }
            }
        }
    }

    // MARK: - Cancel Event (creator)

    private func handleCancelEvent(eventId: String) {
        // Optimistic update
        if let index = cloudKit.events.firstIndex(where: { $0.id == eventId }) {
            let old = cloudKit.events[index]
            let updated = Event(
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
            cloudKit.events[index] = updated
            selectedEvent = updated
            NotificationService.shared.cancelPending(for: eventId)
            NotificationService.shared.scheduleCancellation(for: updated)
            screen = .cancelled
        }
        Task {
            do { try await cloudKit.cancelEvent(eventId: eventId) }
            catch {
                errorTitle = "Couldn't cancel plan"
                errorMessage = "The plan was cancelled locally but couldn't sync to iCloud."
            }
        }
    }

    // MARK: - Edit Event Title (creator)

    private func handleEditTitle(eventId: String, newTitle: String) {
        // Optimistic update
        if let index = cloudKit.events.firstIndex(where: { $0.id == eventId }) {
            let old = cloudKit.events[index]
            let updated = Event(
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
            cloudKit.events[index] = updated
            selectedEvent = updated
        }
        Task {
            do { try await cloudKit.updateEventTitle(eventId: eventId, newTitle: newTitle) }
            catch {
                errorTitle = "Couldn't update title"
                errorMessage = "The name was saved locally but couldn't sync to iCloud."
            }
        }
    }

    // MARK: - Location Vote

    private func handleLocationVote(eventId: String, locationOptionId: String) {
        let myUserId = cloudKit.userRecordID?.recordName ?? ""

        // Optimistic local update — handle both new votes and vote changes
        if let index = cloudKit.events.firstIndex(where: { $0.id == eventId }) {
            let old = cloudKit.events[index]
            var updatedOptions = old.locationOptions

            // 1. Remove existing vote from any option (handles vote changes)
            for i in updatedOptions.indices {
                if let voterIdx = updatedOptions[i].voters.firstIndex(where: { $0.guestId == myUserId }) {
                    updatedOptions[i].voters.remove(at: voterIdx)
                    updatedOptions[i].voteCount = max(0, updatedOptions[i].voteCount - 1)
                }
            }

            // 2. Add vote to selected option
            if let optIdx = updatedOptions.firstIndex(where: { $0.id == locationOptionId }) {
                updatedOptions[optIdx].voteCount += 1
                updatedOptions[optIdx].voters.append(
                    LocationVoter(id: UUID().uuidString, guestId: myUserId, displayName: effectiveUserName)
                )
            }

            // 3. Check if all guests have voted
            let totalVotes = updatedOptions.reduce(0) { $0 + $1.voteCount }
            let allVoted = totalVotes >= old.guests.count && old.guests.count > 0

            let newStatus: LocationVotingStatus = allVoted ? .resolved : old.locationVotingStatus
            let winningId: String? = allVoted
                ? updatedOptions.max(by: { $0.voteCount < $1.voteCount })?.id
                : old.resolvedLocationId
            let resolvedLocation: String? = allVoted
                ? (updatedOptions.first(where: { $0.id == winningId })
                    .map { opt in opt.address != nil ? "\(opt.name), \(opt.address!)" : opt.name } ?? old.location)
                : old.location

            let updated = Event(
                id: old.id, title: old.title, scheduledAt: old.scheduledAt,
                location: resolvedLocation, creatorId: old.creatorId,
                threshold: old.threshold, status: old.status, summary: old.summary,
                guests: old.guests, isAnonymous: old.isAnonymous,
                showBailOMeter: old.showBailOMeter, showVotingStatus: old.showVotingStatus,
                isBailEvent: old.isBailEvent,
                locationVotingStatus: newStatus,
                locationOptions: updatedOptions,
                resolvedLocationId: winningId,
                createdAt: old.createdAt
            )
            cloudKit.events[index] = updated
            selectedEvent = updated
            screen = .eventDetail
        }

        // Sync to CloudKit
        Task {
            do {
                try await cloudKit.castLocationVote(
                    eventId: eventId,
                    locationOptionId: locationOptionId,
                    voterDisplayName: effectiveUserName
                )
                // Re-fetch to get accurate state from server
                try? await cloudKit.fetchEvents()
                if let refreshed = cloudKit.events.first(where: { $0.id == eventId }) {
                    selectedEvent = refreshed
                    // Auto-resolve if all guests voted
                    if refreshed.locationVotingStatus == .voting {
                        let totalVotes = refreshed.locationOptions.reduce(0) { $0 + $1.voteCount }
                        if totalVotes >= refreshed.guests.count && refreshed.guests.count > 0 {
                            try await cloudKit.resolveLocationVote(eventId: eventId)
                            try? await cloudKit.fetchEvents()
                            if let resolved = cloudKit.events.first(where: { $0.id == eventId }) {
                                selectedEvent = resolved
                            }
                        }
                    }
                }
            } catch {
                errorTitle = "Vote didn't sync"
                errorMessage = "Your location vote was saved locally but couldn't reach iCloud."
            }
        }
    }

    // MARK: - Delete Event

    /// Guest removes a plan from their own list. Purely local — the event
    /// itself is untouched; we just stop fetching and showing it.
    private func handleLeaveEvent(eventId: String) {
        CloudKitService.removeAccessedEventId(eventId)
        CloudKitService.hideEvent(eventId)
        cloudKit.events.removeAll { $0.id == eventId }
        NotificationService.shared.cancelPending(for: eventId)
        if selectedEvent?.id == eventId {
            selectedEvent = nil
            screen = .home
        }
    }

    private func handleDeleteEvent(eventId: String) {
        // Optimistic local removal
        cloudKit.events.removeAll { $0.id == eventId }
        CloudKitService.removeAccessedEventId(eventId)

        // If we were viewing this event, go back home
        if selectedEvent?.id == eventId {
            selectedEvent = nil
            screen = .home
        }

        // Sync deletion to CloudKit
        Task {
            do {
                try await cloudKit.deleteEvent(eventId: eventId)
            } catch {
                errorTitle = "Couldn't delete plan"
                errorMessage = "The plan couldn't be removed from iCloud. Refreshing your list…"
                // Re-fetch to restore state since local delete already happened
                try? await cloudKit.fetchEvents()
            }
        }
    }

#if DEBUG
    // MARK: - Screenshot Mode
    /// Drives the app to a specific screen with PreviewData for App Store screenshots.
    /// Triggered via `-ScreenshotMode` launch arg + `SCREENSHOT_SCREEN` env var.
    private func applyScreenshotMode() {
        cloudKit.events = PreviewData.sampleEvents
        cloudKit.userVotes = [:]
        userName = "Joseph"
        hasCompletedOnboarding = true
        hasSeenOnboarding = true

        // Launch args of the form `-SCREENSHOT_SCREEN detail` show up as UserDefaults.
        let target = UserDefaults.standard.string(forKey: "SCREENSHOT_SCREEN")
            ?? ProcessInfo.processInfo.environment["SCREENSHOT_SCREEN"]
            ?? "home"
        switch target {
        case "splash":
            hasCompletedOnboarding = false
            hasSeenOnboarding = false
            screen = .splash
        case "onboarding":
            hasSeenOnboarding = false
            screen = .onboarding
        case "home":
            screen = .home
        case "detail":
            selectedEvent = PreviewData.sampleEvents.first
            screen = .eventDetail
        case "vote":
            selectedEvent = PreviewData.sampleEvents.first
            screen = .vote
        case "create":
            screen = .createEvent
        case "cancelled":
            if let e = PreviewData.sampleEvents.first {
                let cancelled = Event(
                    id: e.id, title: e.title, scheduledAt: e.scheduledAt,
                    location: e.location, creatorId: e.creatorId,
                    threshold: e.threshold, status: .cancelled, summary: e.summary,
                    guests: e.guests, isAnonymous: e.isAnonymous,
                    showBailOMeter: e.showBailOMeter, showVotingStatus: e.showVotingStatus,
                    isBailEvent: e.isBailEvent,
                    locationVotingStatus: e.locationVotingStatus,
                    locationOptions: e.locationOptions,
                    resolvedLocationId: e.resolvedLocationId,
                    createdAt: e.createdAt
                )
                selectedEvent = cancelled
                screen = .cancelled
            }
        default:
            screen = .home
        }
    }
#endif

    // MARK: - Deep Links (bail://event/<id>)

    private func handleDeepLink(_ url: URL) {
        guard let eventId = Self.eventId(from: url) else { return }

        // If the event is already loaded locally, navigate to it
        if let event = cloudKit.events.first(where: { $0.id == eventId }) {
            selectedEvent = event
            screen = .eventDetail
            return
        }

        // Guard against onOpenURL firing twice for the same link on cold launch
        if handlingDeepLinkId == eventId { return }
        handlingDeepLinkId = eventId

        // Otherwise fetch directly by ID from CloudKit
        Task {
            defer { handlingDeepLinkId = nil }
            if cloudKit.userRecordID == nil {
                await cloudKit.setup()
            }
            do {
                let event = try await cloudKit.fetchEvent(byId: eventId)
                // Persist this event ID so it stays in the user's list across refreshes.
                // Tapping an invite link also re-joins a plan the user previously left.
                CloudKitService.addAccessedEventId(eventId)
                CloudKitService.unhideEvent(eventId)
                // Add to local events list if not already there
                if !cloudKit.events.contains(where: { $0.id == eventId }) {
                    cloudKit.events.append(event)
                }
                // Schedule the 1-hour reminder for guests who joined via the link
                if event.status != .cancelled && event.scheduledAt > Date() {
                    NotificationService.shared.scheduleReminder(for: event)
                }
                selectedEvent = event
                screen = .eventDetail
                // Subscribe to pushes for the joined event
                await cloudKit.subscribeToVoteChanges()
            } catch {
                // Only surface the error if the event truly isn't available —
                // a concurrent fetch may have already loaded it (avoids
                // spurious "Plan not found" on cold launch).
                if !cloudKit.events.contains(where: { $0.id == eventId }) {
                    errorTitle = "Plan not found"
                    errorMessage = "That plan may have been deleted or you don't have access to it."
                }
            }
        }
    }

    /// Extracts an event ID from either link form:
    /// - Custom scheme: bail://event/<id>
    /// - Universal link: https://saccojoseph.github.io/e/?id=<id>
    static func eventId(from url: URL) -> String? {
        if url.scheme == "bail", url.host == "event" {
            return url.pathComponents.dropFirst().first
        }
        if url.scheme == "https",
           url.host == "saccojoseph.github.io",
           url.path.hasPrefix("/e"),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let id = components.queryItems?.first(where: { $0.name == "id" })?.value,
           !id.isEmpty {
            return id
        }
        return nil
    }
}

#Preview {
    ContentView()
}
