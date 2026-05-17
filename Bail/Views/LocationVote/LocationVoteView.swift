import SwiftUI

/// Full-screen view where guests vote on a location option.
/// Location votes are VISIBLE — shows who voted for what and vote counts.
struct LocationVoteView: View {
    let event: Event
    let currentUserId: String
    var onBack: () -> Void = {}
    var onVote: (String) -> Void = { _ in }

    @State private var selectedOptionId: String?
    @State private var hasVoted = false

    var body: some View {
        ZStack {
            BailColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                navBar

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        optionsList
                        if !hasVoted && !alreadyVoted {
                            voteButton
                        } else {
                            votedConfirmation
                        }
                    }
                    .padding(.horizontal, BailSpacing.lg)
                    .padding(.top, BailSpacing.md)
                    .padding(.bottom, BailSpacing.xl)
                }
            }
        }
        .onAppear {
            // Check if user already voted
            hasVoted = alreadyVoted
        }
    }

    private var alreadyVoted: Bool {
        event.locationOptions.contains { option in
            option.voters.contains { $0.guestId == currentUserId }
        }
    }

    private var currentVoteOptionId: String? {
        event.locationOptions.first { option in
            option.voters.contains { $0.guestId == currentUserId }
        }?.id
    }

    // MARK: - Nav bar

    private var navBar: some View {
        HStack {
            Button(action: onBack) {
                Text("\u{2039}")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(BailColor.accentStart)
            }
            Spacer()
        }
        .padding(.horizontal, BailSpacing.lg)
        .padding(.vertical, 12)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("VOTE ON LOCATION")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(BailColor.accentStart)
                .tracking(1)
            Text("Where should we go?")
                .font(.system(size: 24, weight: .heavy))
                .foregroundColor(BailColor.textPrimary)
                .tracking(-0.5)
            Text("Pick your favorite spot. Once everyone votes, the location locks in.")
                .font(.system(size: 14))
                .foregroundColor(BailColor.textSecondary)
                .lineSpacing(3)
        }
    }

    // MARK: - Options list

    private var optionsList: some View {
        VStack(spacing: 12) {
            ForEach(event.locationOptions) { option in
                optionCard(option)
            }
        }
    }

    private func optionCard(_ option: LocationOption) -> some View {
        let isSelected = selectedOptionId == option.id
        let isMyVote = currentVoteOptionId == option.id
        let totalVotes = event.locationOptions.reduce(0) { $0 + $1.voteCount }
        let percentage: Double = totalVotes > 0 ? Double(option.voteCount) / Double(totalVotes) : 0

        return Button(action: {
            if !hasVoted && !alreadyVoted {
                selectedOptionId = option.id
            }
        }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(isSelected || isMyVote ? BailColor.accentStart : BailColor.textSecondary)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(option.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(BailColor.textPrimary)
                            .lineLimit(1)
                        if let address = option.address, !address.isEmpty {
                            Text(address)
                                .font(.system(size: 12))
                                .foregroundColor(BailColor.textSecondary)
                                .lineLimit(2)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(option.voteCount)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(BailColor.textPrimary)
                        Text(option.voteCount == 1 ? "vote" : "votes")
                            .font(.system(size: 11))
                            .foregroundColor(BailColor.textMuted)
                    }
                }

                // Vote progress bar
                if totalVotes > 0 {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(BailColor.cardBorder)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(isMyVote || isSelected ? AnyShapeStyle(BailGradient.accentHorizontal) : AnyShapeStyle(BailColor.teal.opacity(0.6)))
                                .frame(width: geo.size.width * percentage)
                        }
                    }
                    .frame(height: 4)
                }

                // Voter names (visible!)
                if !option.voters.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 10))
                            .foregroundColor(BailColor.textMuted)
                        Text(option.voters.map(\.displayName).joined(separator: ", "))
                            .font(.system(size: 11))
                            .foregroundColor(BailColor.textMuted)
                            .lineLimit(1)
                    }
                }
            }
            .padding(16)
            .background(isSelected || isMyVote ? BailColor.surface2 : BailColor.surface)
            .cornerRadius(BailRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: BailRadius.lg)
                    .stroke(
                        isSelected || isMyVote ? BailColor.accentStart : BailColor.cardBorder,
                        lineWidth: isSelected || isMyVote ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(hasVoted || alreadyVoted)
    }

    // MARK: - Vote button

    private var voteButton: some View {
        Button(action: {
            guard let optionId = selectedOptionId else { return }
            hasVoted = true
            onVote(optionId)
        }) {
            Text("Lock In My Vote")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(selectedOptionId != nil ? AnyShapeStyle(BailGradient.accent) : AnyShapeStyle(BailColor.surface2))
                .cornerRadius(BailRadius.lg)
                .shadow(color: selectedOptionId != nil ? BailColor.accentStart.opacity(0.3) : .clear, radius: 15, x: 0, y: 8)
        }
        .disabled(selectedOptionId == nil)
        .padding(.top, 8)
    }

    // MARK: - Voted confirmation

    private var votedConfirmation: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(BailColor.teal)
            Text("You've voted! Waiting for others...")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(BailColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(BailColor.surface)
        .cornerRadius(BailRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: BailRadius.lg)
                .stroke(BailColor.teal.opacity(0.3), lineWidth: 1)
        )
        .padding(.top, 8)
    }
}

#Preview {
    LocationVoteView(
        event: PreviewData.sampleEvents[2],
        currentUserId: "u0"
    )
}
