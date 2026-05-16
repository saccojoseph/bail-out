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
    case cancelled
}

struct ContentView: View {
    @StateObject private var cloudKit = CloudKitService.shared
    @State private var screen: AppScreen = .splash
    @State private var selectedEvent: Event?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var errorTitle: String = "Something went wrong"
    @State private var userName: String = "there"
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        ZStack {
            switch screen {
            case .splash:
                SplashView(
                    onSignIn: { startApp() }
                )
                .transition(.opacity)
                .onAppear {
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
                    userName: userName,
                    isLoading: isLoading,
                    onCreateEvent: { screen = .createEvent },
                    onSelectEvent: { event in
                        selectedEvent = event
                        screen = .eventDetail
                    },
                    onDeleteEvent: { eventId in
                        handleDeleteEvent(eventId: eventId)
                    },
                    onRefresh: {
                        try? await cloudKit.fetchEvents()
                    },
                    onSignOut: { handleSignOut() }
                )
                .transition(.opacity)

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
                            handleVote(eventId: event.id, choice: choice)
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
        .preferredColorScheme(.dark)
        .task {
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
        // Device names are typically "Joseph's iPhone" or "Joseph's iPhone 16 Pro"
        if let firstName = deviceName.components(separatedBy: "'").first,
           !firstName.isEmpty {
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
            do {
                let guests = localEvent.guests.map {
                    (displayName: $0.displayName,
                     phoneNumber: $0.phoneNumber ?? "",
                     avatarColor: $0.avatarColor)
                }
                let cloudEvent = try await cloudKit.createEvent(
                    title: localEvent.title,
                    scheduledAt: localEvent.scheduledAt,
                    location: localEvent.location,
                    threshold: localEvent.threshold,
                    isAnonymous: localEvent.isAnonymous,
                    showBailOMeter: localEvent.showBailOMeter,
                    showVotingStatus: localEvent.showVotingStatus,
                    isBailEvent: localEvent.isBailEvent,
                    guests: guests
                )
                // Replace local placeholder with CloudKit version (has real IDs)
                if let index = cloudKit.events.firstIndex(where: { $0.id == localEvent.id }) {
                    cloudKit.events[index] = cloudEvent
                }
            } catch {
                errorTitle = "Couldn't save plan"
                errorMessage = "Your plan was created locally but couldn't sync to iCloud. It'll try again next time you open the app."
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
                createdAt: old.createdAt
            )
            cloudKit.events[index] = updated
            selectedEvent = updated

            if newSummary.isCancelled {
                NotificationService.shared.cancelPending(for: eventId)
                NotificationService.shared.scheduleCancellation(for: updated)
                screen = .cancelled
            } else {
                screen = .home
            }
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
                isBailEvent: old.isBailEvent, createdAt: old.createdAt
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
                isBailEvent: old.isBailEvent, createdAt: old.createdAt
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

    // MARK: - Delete Event

    private func handleDeleteEvent(eventId: String) {
        // Optimistic local removal
        cloudKit.events.removeAll { $0.id == eventId }

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

    // MARK: - Deep Links (bail://event/<id>)

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "bail",
              url.host == "event",
              let eventId = url.pathComponents.dropFirst().first else {
            return
        }

        // If the event is already loaded locally, navigate to it
        if let event = cloudKit.events.first(where: { $0.id == eventId }) {
            selectedEvent = event
            screen = .eventDetail
            return
        }

        // Otherwise fetch from CloudKit, then navigate
        Task {
            do {
                try await cloudKit.fetchEvents()
                if let event = cloudKit.events.first(where: { $0.id == eventId }) {
                    selectedEvent = event
                    screen = .eventDetail
                } else {
                    errorTitle = "Plan not found"
                    errorMessage = "That plan may have been deleted or you don't have access to it."
                }
            } catch {
                errorTitle = "Couldn't open plan"
                errorMessage = "There was a problem loading that plan from iCloud. Check your connection and try again."
            }
        }
    }
}

#Preview {
    ContentView()
}
