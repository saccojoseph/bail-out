import SwiftUI
import UserNotifications

enum AppScreen {
    case splash
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

    var body: some View {
        ZStack {
            switch screen {
            case .splash:
                SplashView(
                    onGetStarted: { startApp() },
                    onSignIn:     { startApp() }
                )
                .transition(.opacity)

            case .home:
                HomeView(
                    events: cloudKit.events,
                    onCreateEvent: { screen = .createEvent },
                    onSelectEvent: { event in
                        selectedEvent = event
                        screen = .eventDetail
                    },
                    onRefresh: {
                        try? await cloudKit.fetchEvents()
                    }
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
                        onBack: { screen = .home },
                        onVote: { screen = .vote }
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
        .alert("Oops", isPresented: showingError) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Something went wrong.")
        }
        .onOpenURL { url in
            handleDeepLink(url)
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
        Task {
            await cloudKit.setup()

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
            screen = .home
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
                    guests: guests
                )
                // Replace local placeholder with CloudKit version (has real IDs)
                if let index = cloudKit.events.firstIndex(where: { $0.id == localEvent.id }) {
                    cloudKit.events[index] = cloudEvent
                }
            } catch {
                errorMessage = "Couldn't save to iCloud: \(error.localizedDescription)"
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
                errorMessage = "Vote couldn't sync: \(error.localizedDescription)"
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
                    errorMessage = "Couldn't find that event."
                }
            } catch {
                errorMessage = "Couldn't load event: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    ContentView()
}
