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
    @State private var screen: AppScreen = .splash
    @State private var events: [Event] = PreviewData.sampleEvents
    @State private var selectedEvent: Event?
    @State private var userVotes: [String: VoteChoice] = [:]

    var body: some View {
        ZStack {
            switch screen {
            case .splash:
                SplashView(
                    onGetStarted: { screen = .home },
                    onSignIn:     { screen = .home }
                )
                .transition(.opacity)

            case .home:
                HomeView(
                    events: events,
                    onCreateEvent: { screen = .createEvent },
                    onSelectEvent: { event in
                        selectedEvent = event
                        screen = .eventDetail
                    }
                )
                .transition(.opacity)

            case .createEvent:
                CreateEventView(
                    onDismiss: { screen = .home },
                    onComplete: { newEvent in
                        events.insert(newEvent, at: 0)
                        NotificationService.shared.scheduleReminder(for: newEvent)
                        screen = .home
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))

            case .eventDetail:
                if let event = selectedEvent {
                    EventDetailView(
                        event: event,
                        userVote: userVotes[event.id],
                        onBack: { screen = .home },
                        onVote: { screen = .vote }
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }

            case .vote:
                if let event = selectedEvent {
                    VoteView(
                        event: event,
                        existingVote: userVotes[event.id],
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
        }
        .animation(.easeInOut(duration: 0.25), value: screen)
        .preferredColorScheme(.dark)
        .task {
            await NotificationService.shared.requestPermission()
        }
    }

    // MARK: - Local vote handling (no backend)

    private func handleVote(eventId: String, choice: VoteChoice) {
        guard let index = events.firstIndex(where: { $0.id == eventId }) else {
            screen = .home
            return
        }
        let old = events[index]
        let previous = userVotes[eventId]

        // Adjust bail count based on previous vote
        var newBailCount = old.summary.bailCount
        var newTotalVotes = old.summary.totalVotes
        if let prev = previous {
            // Changing an existing vote
            if prev == .bail && choice == .in  { newBailCount -= 1 }
            if prev == .in  && choice == .bail { newBailCount += 1 }
        } else {
            // First-time vote
            if choice == .bail { newBailCount += 1 }
            newTotalVotes += 1
        }

        userVotes[eventId] = choice

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
            showBailOMeter: old.showBailOMeter,
            showVotingStatus: old.showVotingStatus,
            createdAt: old.createdAt
        )
        events[index] = updated
        selectedEvent = updated

        if newSummary.isCancelled {
            NotificationService.shared.cancelPending(for: eventId)
            NotificationService.shared.scheduleCancellation(for: updated)
            screen = .cancelled
        } else {
            screen = .home
        }
    }
}

#Preview {
    ContentView()
}
