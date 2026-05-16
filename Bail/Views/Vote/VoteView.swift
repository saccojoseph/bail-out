import SwiftUI

struct VoteView: View {
    let event: Event
    var existingVote: VoteChoice? = nil
    var onBack: () -> Void = {}
    var onVoteCast: (VoteChoice) -> Void = { _ in }

    @State private var selected: VoteChoice? = nil
    @State private var showConfirmation = false

    var body: some View {
        ZStack {
            BailColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                navBar
                Spacer()

                if showConfirmation {
                    confirmationContent
                } else {
                    votingContent
                }

                Spacer()
            }
            .padding(.horizontal, BailSpacing.lg)
        }
        .onAppear { selected = existingVote }
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
        .padding(.vertical, 12)
    }

    // MARK: - Voting content

    private var votingContent: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text(selected == nil ? "🤔" : selected == .in ? "🙌" : "🚪")
                    .font(.system(size: 48))
                    .animation(.easeInOut(duration: 0.2), value: selected)

                VStack(spacing: 4) {
                    Text(event.title)
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundColor(BailColor.textPrimary)
                        .tracking(-0.5)
                        .multilineTextAlignment(.center)
                    Text(event.scheduledAt.eventTimeString)
                        .font(.system(size: 14))
                        .foregroundColor(BailColor.textSecondary)
                }

                Text("Your vote is completely secret.\nNo one will ever know what you chose.")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "555555"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.top, 4)
            }

            VStack(spacing: 12) {
                voteCard(
                    choice: .in,
                    icon: "🙌",
                    label: "I'm In",
                    subtitle: "Keep the plan"
                )
                voteCard(
                    choice: .bail,
                    icon: "🚪",
                    label: "I'd Bail",
                    subtitle: "Secretly opt out"
                )
            }

            Text("🔒 Encrypted · Anonymous · Nobody sees this")
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "333333"))
        }
    }

    private func voteCard(choice: VoteChoice, icon: String, label: String, subtitle: String) -> some View {
        let isSelected = selected == choice
        let bg: AnyView = isSelected
            ? (choice == .in
                ? AnyView(BailGradient.teal)
                : AnyView(BailGradient.accent))
            : AnyView(BailColor.surface)

        return Button(action: { castVote(choice) }) {
            VStack(spacing: 4) {
                Text("\(icon) \(label)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .white.opacity(0.7) : BailColor.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(bg)
            .cornerRadius(BailRadius.xl)
            .overlay(
                RoundedRectangle(cornerRadius: BailRadius.xl)
                    .stroke(isSelected ? Color.clear : BailColor.border, lineWidth: 1)
            )
            .shadow(
                color: isSelected
                    ? (choice == .in ? BailColor.teal.opacity(0.3) : BailColor.accentStart.opacity(0.3))
                    : .clear,
                radius: 15, x: 0, y: 8
            )
        }
        .buttonStyle(.plain)
        .disabled(showConfirmation)
        .animation(.easeInOut(duration: 0.2), value: selected)
    }

    // MARK: - Confirmation content

    private var confirmationContent: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Text(selected == .bail ? "🚪" : "🙌")
                    .font(.system(size: 64))

                VStack(spacing: 8) {
                    Text(selected == .bail ? "Bail recorded." : "You're in!")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundColor(BailColor.textPrimary)
                    Text(selected == .bail
                         ? "Your secret is safe.\nWe'll let you know if the plan gets cancelled."
                         : "Nice! We'll notify you if anything changes.")
                        .font(.system(size: 14))
                        .foregroundColor(BailColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }

            VStack(spacing: 6) {
                Text("CURRENT STATUS")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(BailColor.textMuted)
                    .tracking(1)
                Text("\(event.summary.bailCount) of \(event.summary.requiredBails) bails needed")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(BailColor.accentStart)
                Text("Still on — for now 👀")
                    .font(.system(size: 12))
                    .foregroundColor(BailColor.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(BailColor.surface)
            .cornerRadius(BailRadius.xl)
            .overlay(
                RoundedRectangle(cornerRadius: BailRadius.xl)
                    .stroke(BailColor.border, lineWidth: 1)
            )

            Button(action: { onVoteCast(selected ?? .in) }) {
                Text("Back to Plans")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(BailColor.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(BailColor.surface2)
                    .cornerRadius(BailRadius.lg)
                    .overlay(
                        RoundedRectangle(cornerRadius: BailRadius.lg)
                            .stroke(BailColor.border, lineWidth: 1)
                    )
            }
        }
    }

    // MARK: - Action

    private func castVote(_ choice: VoteChoice) {
        selected = choice
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showConfirmation = true
            }
        }
    }
}

// MARK: - Date helper

private extension Date {
    var eventTimeString: String {
        let f = DateFormatter()
        f.dateFormat = "EEE h:mm a"
        return f.string(from: self)
    }
}

#Preview {
    VoteView(event: PreviewData.sampleEvents[0])
}
