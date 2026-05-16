import SwiftUI

struct EventDetailView: View {
    let event: Event
    var userVote: VoteChoice? = nil
    var onBack: () -> Void = {}
    var onVote: () -> Void = {}

    var body: some View {
        ZStack {
            BailColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                navBar

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        eventHeader
                        guestsCard
                        if event.showBailOMeter {
                            bailOMeterCard
                        }
                        voteSection
                    }
                    .padding(.horizontal, BailSpacing.lg)
                    .padding(.top, BailSpacing.md)
                    .padding(.bottom, BailSpacing.xl)
                }
            }
        }
    }

    // MARK: - Nav bar

    private var navBar: some View {
        HStack {
            Button(action: onBack) {
                Text("‹")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(BailColor.accentStart)
            }
            Spacer()
        }
        .padding(.horizontal, BailSpacing.lg)
        .padding(.vertical, 12)
    }

    // MARK: - Event header

    private var eventHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.scheduledAt.detailTimeString.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(BailColor.accentStart)
                .tracking(1)
            Text(event.title)
                .font(.system(size: 28, weight: .heavy))
                .foregroundColor(BailColor.textPrimary)
                .tracking(-1)
            if let location = event.location {
                Text("📍 \(location)")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "555555"))
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Guests card

    private var guestsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("INVITED")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(BailColor.textSecondary)
                .tracking(1)

            ForEach(event.guests) { guest in
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color(hex: guest.avatarColor))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Text(String(guest.displayName.prefix(1)))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.black)
                        )
                    Text(guest.displayName)
                        .font(.system(size: 15))
                        .foregroundColor(BailColor.textPrimary)
                    Spacer()
                    if event.showVotingStatus {
                        Text(guest.status == .voted ? "voted ✓" : "pending")
                            .font(.system(size: 12))
                            .foregroundColor(BailColor.textMuted)
                    }
                }
            }
        }
        .padding(18)
        .background(BailColor.surface)
        .cornerRadius(BailRadius.xl)
        .overlay(
            RoundedRectangle(cornerRadius: BailRadius.xl)
                .stroke(Color(hex: "222222"), lineWidth: 1)
        )
    }

    // MARK: - Bail-o-meter card

    private var bailOMeterCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("BAIL-O-METER")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(BailColor.textSecondary)
                    .tracking(1)
                Spacer()
                Text("\(event.summary.bailCount) of \(event.summary.requiredBails) to cancel")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(BailColor.accentStart)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "222222"))
                    RoundedRectangle(cornerRadius: 8)
                        .fill(BailGradient.accentHorizontal)
                        .frame(width: geo.size.width * event.summary.progress)
                        .shadow(color: BailColor.accentStart.opacity(0.4), radius: 6)
                }
            }
            .frame(height: 8)
            Text("\(event.summary.bailCount) anonymous bail\(event.summary.bailCount == 1 ? "" : "s") recorded")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "555555"))
        }
        .padding(18)
        .background(BailColor.surface)
        .cornerRadius(BailRadius.xl)
        .overlay(
            RoundedRectangle(cornerRadius: BailRadius.xl)
                .stroke(Color(hex: "222222"), lineWidth: 1)
        )
    }

    // MARK: - Vote section

    private var voteSection: some View {
        VStack(spacing: 12) {
            if let vote = userVote {
                // Already voted — show current choice + change option
                HStack(spacing: 10) {
                    Text(vote == .bail ? "🚪" : "🙌")
                        .font(.system(size: 20))
                    Text("You voted: \(vote == .bail ? "I'd Bail" : "I'm In")")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(BailColor.textSecondary)
                    Spacer()
                }

                Button(action: onVote) {
                    Text("Change Your Vote")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(BailColor.surface2)
                        .cornerRadius(BailRadius.lg)
                        .overlay(
                            RoundedRectangle(cornerRadius: BailRadius.lg)
                                .stroke(BailColor.border, lineWidth: 1)
                        )
                }
            } else {
                Button(action: onVote) {
                    Text("Cast Your Vote 🗳️")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(BailGradient.accent)
                        .cornerRadius(BailRadius.lg)
                        .shadow(color: BailColor.accentStart.opacity(0.3), radius: 15, x: 0, y: 8)
                }

                Text("Your vote is 100% anonymous. Nobody will ever know what you chose.")
                    .font(.system(size: 12))
                    .foregroundColor(BailColor.textMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

#Preview {
    EventDetailView(event: PreviewData.sampleEvents[0])
}
