import SwiftUI

/// Full-screen view where guests vote on a location option.
/// Location votes are VISIBLE — shows who voted for what and vote counts.
/// Supports changing your vote after initial selection.
struct LocationVoteView: View {
    let event: Event
    let currentUserId: String
    var onBack: () -> Void = {}
    var onVote: (String) -> Void = { _ in }

    @State private var selectedOptionId: String?
    @State private var isChangingVote = false

    var body: some View {
        ZStack {
            BailColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                navBar

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        optionsList

                        if canVote {
                            voteButton
                        } else if hasExistingVote && !isChangingVote {
                            changeVoteSection
                        }
                    }
                    .padding(.horizontal, BailSpacing.lg)
                    .padding(.top, BailSpacing.md)
                    .padding(.bottom, BailSpacing.xl)
                }
            }
        }
        .onAppear {
            // Pre-select current vote if exists
            if let existingId = existingVoteOptionId {
                selectedOptionId = existingId
            }
        }
    }

    /// The option the user already voted for (nil if not voted yet).
    private var existingVoteOptionId: String? {
        event.locationOptions.first { option in
            option.voters.contains { $0.guestId == currentUserId }
        }?.id
    }

    private var hasExistingVote: Bool {
        existingVoteOptionId != nil
    }

    /// User can vote if: no existing vote, OR actively changing their vote AND picked something different.
    private var canVote: Bool {
        if !hasExistingVote {
            // New voter — just need a selection
            return selectedOptionId != nil
        }
        // Changing vote — need to be in change mode with a different selection
        return isChangingVote && selectedOptionId != nil && selectedOptionId != existingVoteOptionId
    }

    /// Options are tappable when user hasn't voted yet, or is in change-vote mode.
    private var optionsInteractive: Bool {
        !hasExistingVote || isChangingVote
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
            Text("Pick your favorite spot. You can change your vote anytime.")
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
        let isMyExistingVote = existingVoteOptionId == option.id && !isChangingVote
        let highlighted = isSelected || isMyExistingVote
        let totalVotes = event.locationOptions.reduce(0) { $0 + $1.voteCount }
        let percentage: Double = totalVotes > 0 ? Double(option.voteCount) / Double(totalVotes) : 0

        return Button(action: {
            if optionsInteractive {
                selectedOptionId = option.id
            }
        }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(highlighted ? BailColor.accentStart : BailColor.textSecondary)

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
                                .fill(highlighted ? AnyShapeStyle(BailGradient.accentHorizontal) : AnyShapeStyle(BailColor.teal.opacity(0.6)))
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

                // "Your vote" badge
                if isMyExistingVote {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(BailColor.teal)
                        Text("Your vote")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(BailColor.teal)
                    }
                }
            }
            .padding(16)
            .background(highlighted ? BailColor.surface2 : BailColor.surface)
            .cornerRadius(BailRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: BailRadius.lg)
                    .stroke(
                        highlighted ? BailColor.accentStart : BailColor.cardBorder,
                        lineWidth: highlighted ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!optionsInteractive)
    }

    // MARK: - Vote button (new vote or confirming change)

    private var voteButton: some View {
        Button(action: {
            guard let optionId = selectedOptionId else { return }
            onVote(optionId)
        }) {
            Text(hasExistingVote ? "Confirm New Vote" : "Lock In My Vote")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(BailGradient.accent)
                .cornerRadius(BailRadius.lg)
                .shadow(color: BailColor.accentStart.opacity(0.3), radius: 15, x: 0, y: 8)
        }
        .padding(.top, 8)
    }

    // MARK: - Change vote section (shown after voting)

    private var changeVoteSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(BailColor.teal)
                Text("You've voted!")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(BailColor.textSecondary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(BailColor.surface)
            .cornerRadius(BailRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: BailRadius.lg)
                    .stroke(BailColor.teal.opacity(0.3), lineWidth: 1)
            )

            Button(action: {
                isChangingVote = true
            }) {
                Text("Change Your Vote")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(BailColor.accentStart)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(BailColor.surface2)
                    .cornerRadius(BailRadius.lg)
                    .overlay(
                        RoundedRectangle(cornerRadius: BailRadius.lg)
                            .stroke(BailColor.border, lineWidth: 1)
                    )
            }
        }
        .padding(.top, 8)
    }
}

#if DEBUG
#Preview {
    LocationVoteView(
        event: PreviewData.sampleEvents[2],
        currentUserId: "u0"
    )
}
#endif
