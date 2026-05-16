import SwiftUI

struct HomeView: View {
    var events: [Event] = PreviewData.sampleEvents
    var onCreateEvent: () -> Void = {}
    var onSelectEvent: (Event) -> Void = { _ in }
    var onRefresh: () async -> Void = {}

    @State private var activeHomeTab: HomeTab = .upcoming
    @State private var activeBottomTab: BottomTab = .home

    var body: some View {
        ZStack(alignment: .bottom) {
            BailColor.background.ignoresSafeArea()

            Group {
                switch activeBottomTab {
                case .home:
                    homeContent
                case .friends:
                    placeholderContent(icon: "👥", title: "Friends")
                case .alerts:
                    placeholderContent(icon: "🔔", title: "Alerts")
                case .profile:
                    placeholderContent(icon: "👤", title: "Profile")
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
                    ForEach(filteredEvents) { event in
                        EventCard(event: event)
                            .onTapGesture { onSelectEvent(event) }
                    }
                    createCTA
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

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Hey Joe 👋")
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
            .background(Color(hex: "0F0F0F"))
            .cornerRadius(BailRadius.xl)
            .overlay(
                RoundedRectangle(cornerRadius: BailRadius.xl)
                    .stroke(BailColor.border, style: StrokeStyle(lineWidth: 1, dash: [6]))
            )
        }
    }

    // MARK: - Placeholder for unbuilt tabs

    private func placeholderContent(icon: String, title: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Text(icon).font(.system(size: 48))
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(BailColor.textPrimary)
            Text("Coming soon")
                .font(.system(size: 14))
                .foregroundColor(BailColor.textSecondary)
            Spacer()
            Color.clear.frame(height: 80)
        }
        .frame(maxWidth: .infinity)
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
        .background(Color(hex: "0F0F0F"))
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
    case home, friends, alerts, profile
    var icon: String {
        switch self {
        case .home:    return "🏠"
        case .friends: return "👥"
        case .alerts:  return "🔔"
        case .profile: return "👤"
        }
    }
    var label: String {
        switch self {
        case .home:    return "Home"
        case .friends: return "Friends"
        case .alerts:  return "Alerts"
        case .profile: return "Profile"
        }
    }
}

#Preview {
    HomeView()
}
