import SwiftUI

struct CancelledView: View {
    let event: Event
    var onDone: () -> Void = {}

    var body: some View {
        ZStack {
            Color(hex: "080808").ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                Text("💀")
                    .font(.system(size: 80))

                VStack(spacing: 4) {
                    Text("It's dead.")
                        .font(.system(size: 32, weight: .heavy))
                        .foregroundColor(BailColor.accentStart)
                        .tracking(-1)
                    Text(event.title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(BailColor.textPrimary)
                        .padding(.top, 4)
                    Text("Enough people bailed.\nPlans have been cancelled.\nNo names. No blame. No drama.")
                        .font(.system(size: 14))
                        .foregroundColor(BailColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.top, 8)
                }

                VStack(spacing: 6) {
                    Text("SENT TO EVERYONE")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(BailColor.textMuted)
                        .tracking(1)
                    Text("\"Hey, plans fell through for \(event.scheduledAt.dayString). Maybe next time! 🤷\"")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "AAAAAA"))
                        .italic()
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(Color(hex: "111111"))
                .cornerRadius(BailRadius.lg)
                .overlay(
                    RoundedRectangle(cornerRadius: BailRadius.lg)
                        .stroke(BailColor.border, lineWidth: 1)
                )

                Spacer()

                Button(action: onDone) {
                    Text("Back to Home")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(BailGradient.accent)
                        .cornerRadius(BailRadius.lg)
                }
                .padding(.bottom, BailSpacing.xl)
            }
            .padding(.horizontal, BailSpacing.lg)
        }
    }
}

// MARK: - Date helper

private extension Date {
    var dayString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: self)
    }
}

#Preview {
    CancelledView(event: PreviewData.sampleEvents[0])
}
