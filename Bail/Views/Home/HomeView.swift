import SwiftUI

struct HomeView: View {
    var events: [Event] = []
    var userName: String = "there"
    var isLoading: Bool = false
    var onCreateEvent: () -> Void = {}
    var onSelectEvent: (Event) -> Void = { _ in }
    var onDeleteEvent: (String) -> Void = { _ in }
    var onRefresh: () async -> Void = {}
    var onSignOut: () -> Void = {}

    @State private var activeHomeTab: HomeTab = .upcoming
    @State private var activeBottomTab: BottomTab = .home

    var body: some View {
        ZStack(alignment: .bottom) {
            BailColor.background.ignoresSafeArea()

            Group {
                switch activeBottomTab {
                case .home:
                    homeContent
                case .profile:
                    profileContent
                }
            }

            bottomNav
        }
    }

    // MARK: - Home content

    private var homeContent: some View {
        VStack(spacing: 0) {
            header
            tabRow

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    if isLoading && events.isEmpty {
                        // Skeleton loading cards
                        ForEach(0..<3, id: \.self) { _ in
                            skeletonCard
                        }
                    } else if filteredEvents.isEmpty {
                        emptyState
                    } else {
                        ForEach(filteredEvents) { event in
                            EventCard(event: event)
                                .onTapGesture { onSelectEvent(event) }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        onDeleteEvent(event.id)
                                    } label: {
                                        Label("Delete Plan", systemImage: "trash")
                                    }
                                }
                        }
                    }

                    if !isLoading && !(filteredEvents.isEmpty && activeHomeTab == .past) {
                        createCTA
                    }
                }
                .padding(.horizontal, BailSpacing.lg)
                .padding(.top, BailSpacing.sm)
                .padding(.bottom, 96)
            }
            .refreshable { await onRefresh() }
        }
    }

    private var filteredEvents: [Event] {
        switch activeHomeTab {
        case .upcoming: return events.filter { $0.status != .cancelled }
        case .past:     return events.filter { $0.status == .cancelled }
        }
    }

    // MARK: - Empty states

    private var emptyState: some View {
        VStack(spacing: 16) {
            if activeHomeTab == .past {
                Text("💀")
                    .font(.system(size: 48))
                    .padding(.top, BailSpacing.xl)
            } else {
                Color.clear.frame(height: BailSpacing.xl)
            }

            Text(activeHomeTab == .upcoming
                 ? "No plans yet"
                 : "No cancelled plans")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(BailColor.textPrimary)

            Text(activeHomeTab == .upcoming
                 ? "Create your first plan and invite\nyour friends to vote on it."
                 : "Plans that get enough bails\nwill show up here.")
                .font(.system(size: 14))
                .foregroundColor(BailColor.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            if activeHomeTab == .upcoming {
                Button(action: onCreateEvent) {
                    Text("Create a Plan")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(BailGradient.accent)
                        .cornerRadius(BailRadius.lg)
                        .shadow(color: BailColor.accentStart.opacity(0.3), radius: 12, x: 0, y: 6)
                }
                .padding(.top, BailSpacing.sm)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, BailSpacing.lg)
    }

    // MARK: - Skeleton loading card

    private var skeletonCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(BailColor.surface2)
                    .frame(width: 140, height: 16)
                Spacer()
                RoundedRectangle(cornerRadius: 8)
                    .fill(BailColor.surface2)
                    .frame(width: 60, height: 22)
            }
            RoundedRectangle(cornerRadius: 4)
                .fill(BailColor.surface2)
                .frame(width: 100, height: 12)
            HStack(spacing: -8) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(BailColor.surface2)
                        .frame(width: 32, height: 32)
                        .overlay(Circle().stroke(BailColor.surface, lineWidth: 2))
                }
            }
        }
        .padding(20)
        .background(BailColor.surface)
        .cornerRadius(BailRadius.xl)
        .overlay(
            RoundedRectangle(cornerRadius: BailRadius.xl)
                .stroke(BailColor.cardBorder, lineWidth: 1)
        )
        .shimmer(isActive: true)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Hey \(userName) 👋")
                    .font(.system(size: 13))
                    .foregroundColor(BailColor.textSecondary)
                Text("Your Plans")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundColor(BailColor.textPrimary)
                    .tracking(-1)
            }
            Spacer()
            Button(action: onCreateEvent) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(BailGradient.accent)
                        .frame(width: 42, height: 42)
                    Text("+")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal, BailSpacing.lg)
        .padding(.top, BailSpacing.md)
    }

    // MARK: - Tab row

    private var tabRow: some View {
        HStack(spacing: BailSpacing.sm) {
            ForEach(HomeTab.allCases, id: \.self) { tab in
                Button(action: { activeHomeTab = tab }) {
                    Text(tab.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(activeHomeTab == tab ? .white : BailColor.textSecondary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(
                            Group {
                                if activeHomeTab == tab {
                                    AnyView(BailGradient.accent)
                                } else {
                                    AnyView(BailColor.surface2)
                                }
                            }
                        )
                        .cornerRadius(BailRadius.full)
                }
            }
            Spacer()
        }
        .padding(.horizontal, BailSpacing.lg)
        .padding(.vertical, BailSpacing.sm)
    }

    // MARK: - Create CTA

    private var createCTA: some View {
        Button(action: onCreateEvent) {
            VStack(spacing: BailSpacing.sm) {
                Text("＋")
                    .font(.system(size: 28))
                    .foregroundColor(BailColor.textMuted)
                Text("Create new plan")
                    .font(.system(size: 14))
                    .foregroundColor(BailColor.textMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, BailSpacing.lg)
            .background(BailColor.surfaceDeep)
            .cornerRadius(BailRadius.xl)
            .overlay(
                RoundedRectangle(cornerRadius: BailRadius.xl)
                    .stroke(BailColor.border, style: StrokeStyle(lineWidth: 1, dash: [6]))
            )
        }
    }

    // MARK: - Profile tab

    private var profileContent: some View {
        VStack(spacing: 0) {
            // Profile header
            HStack {
                Text("Profile")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundColor(BailColor.textPrimary)
                    .tracking(-1)
                Spacer()
            }
            .padding(.horizontal, BailSpacing.lg)
            .padding(.top, BailSpacing.md)
            .padding(.bottom, BailSpacing.md)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Avatar + name
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(BailGradient.accent)
                                .frame(width: 80, height: 80)
                            Text(String(userName.prefix(1)).uppercased())
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                        }
                        Text(userName)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(BailColor.textPrimary)
                    }
                    .padding(.top, BailSpacing.md)

                    // Stats row
                    HStack(spacing: 0) {
                        statItem(
                            count: events.filter { $0.status != .cancelled }.count,
                            label: "Active"
                        )
                        Rectangle()
                            .fill(BailColor.border)
                            .frame(width: 1, height: 40)
                        statItem(
                            count: events.count,
                            label: "Total"
                        )
                        Rectangle()
                            .fill(BailColor.border)
                            .frame(width: 1, height: 40)
                        statItem(
                            count: events.filter { $0.status == .cancelled }.count,
                            label: "Cancelled"
                        )
                    }
                    .padding(.vertical, 18)
                    .background(BailColor.surface)
                    .cornerRadius(BailRadius.xl)
                    .overlay(
                        RoundedRectangle(cornerRadius: BailRadius.xl)
                            .stroke(BailColor.cardBorder, lineWidth: 1)
                    )

                    // Info card
                    VStack(alignment: .leading, spacing: 14) {
                        Text("ABOUT BAIL.OUT")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(BailColor.textSecondary)
                            .tracking(1)

                        infoRow(icon: "🔒", text: "Votes are always anonymous")
                        infoRow(icon: "☁️", text: "Plans sync via iCloud")
                        infoRow(icon: "📱", text: "Invite friends via text message")
                        infoRow(icon: "🔔", text: "Get notified when plans change")
                    }
                    .padding(18)
                    .background(BailColor.surface)
                    .cornerRadius(BailRadius.xl)
                    .overlay(
                        RoundedRectangle(cornerRadius: BailRadius.xl)
                            .stroke(BailColor.cardBorder, lineWidth: 1)
                    )

                    // Feedback
                    VStack(spacing: 10) {
                        Link(destination: URL(string: "mailto:bail.out.app.official@gmail.com?subject=Bail%20-%20Report%20Bug")!) {
                            HStack {
                                Text("🐛")
                                Text("Report Bug")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(BailColor.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(BailColor.textMuted)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 16)
                            .background(BailColor.surface)
                            .cornerRadius(BailRadius.xl)
                            .overlay(
                                RoundedRectangle(cornerRadius: BailRadius.xl)
                                    .stroke(BailColor.cardBorder, lineWidth: 1)
                            )
                        }

                        Link(destination: URL(string: "mailto:bail.out.app.official@gmail.com?subject=Bail%20-%20Request%20Feature")!) {
                            HStack {
                                Text("💡")
                                Text("Request Feature")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(BailColor.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(BailColor.textMuted)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 16)
                            .background(BailColor.surface)
                            .cornerRadius(BailRadius.xl)
                            .overlay(
                                RoundedRectangle(cornerRadius: BailRadius.xl)
                                    .stroke(BailColor.cardBorder, lineWidth: 1)
                            )
                        }
                    }

                    // Sign out
                    Button(action: onSignOut) {
                        Text("Sign Out")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(BailColor.accentStart)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(BailColor.surface)
                            .cornerRadius(BailRadius.xl)
                            .overlay(
                                RoundedRectangle(cornerRadius: BailRadius.xl)
                                    .stroke(BailColor.cardBorder, lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, BailSpacing.lg)
                .padding(.bottom, 96)
            }
        }
    }

    private func statItem(count: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 22, weight: .heavy))
                .foregroundColor(BailColor.textPrimary)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(BailColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func infoRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Text(icon).font(.system(size: 16))
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(BailColor.textPrimary)
        }
    }

    // MARK: - Bottom nav

    private var bottomNav: some View {
        HStack {
            ForEach(BottomTab.allCases, id: \.self) { tab in
                Spacer()
                Button(action: { activeBottomTab = tab }) {
                    VStack(spacing: 3) {
                        Text(tab.icon)
                            .font(.system(size: 20))
                        Text(tab.label)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(
                                activeBottomTab == tab ? BailColor.accentStart : BailColor.textMuted
                            )
                    }
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .frame(height: 80)
        .background(BailColor.surfaceDeep)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(BailColor.surface2),
            alignment: .top
        )
    }
}

// MARK: - Enums

enum HomeTab: CaseIterable {
    case upcoming, past
    var label: String {
        switch self {
        case .upcoming: return "Upcoming"
        case .past:     return "Past"
        }
    }
}

enum BottomTab: CaseIterable {
    case home, profile
    var icon: String {
        switch self {
        case .home:    return "🏠"
        case .profile: return "👤"
        }
    }
    var label: String {
        switch self {
        case .home:    return "Home"
        case .profile: return "Profile"
        }
    }
}

// MARK: - Shimmer modifier

struct ShimmerModifier: ViewModifier {
    let isActive: Bool
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        if isActive {
            content
                .opacity(0.4 + 0.3 * sin(phase))
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                        phase = .pi
                    }
                }
        } else {
            content
        }
    }
}

extension View {
    func shimmer(isActive: Bool) -> some View {
        modifier(ShimmerModifier(isActive: isActive))
    }
}

#Preview {
    HomeView()
}
