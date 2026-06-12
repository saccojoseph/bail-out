import SwiftUI

struct CancelledView: View {
    let event: Event
    var onDone: () -> Void = {}
    /// Creator-only one-tap "text the group" action; nil hides the button.
    var onTextEveryone: (() -> Void)? = nil

    @State private var shareImage: UIImage?

    var body: some View {
        ZStack {
            BailColor.surfaceDeep.ignoresSafeArea()
                .onAppear {
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    shareImage = renderShareCard()
                }

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
                    Text("THE NEUTRAL MESSAGE")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(BailColor.textMuted)
                        .tracking(1)
                    Text("\"Hey, plans fell through for \(event.scheduledAt.dayString). Maybe next time! 🤷\"")
                        .font(.system(size: 14))
                        .foregroundColor(BailColor.textMuted)
                        .italic()
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(BailColor.surface)
                .cornerRadius(BailRadius.lg)
                .overlay(
                    RoundedRectangle(cornerRadius: BailRadius.lg)
                        .stroke(BailColor.border, lineWidth: 1)
                )

                if let onTextEveryone {
                    Button(action: onTextEveryone) {
                        HStack(spacing: 8) {
                            Image(systemName: "message.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Text the Group")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(BailColor.textPrimary)
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

                Spacer()

                VStack(spacing: 12) {
                    if let shareImage {
                        ShareLink(
                            item: Image(uiImage: shareImage),
                            preview: SharePreview("It's dead. 💀", image: Image(uiImage: shareImage))
                        ) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 15, weight: .semibold))
                                Text("Share the Moment")
                                    .font(.system(size: 16, weight: .semibold))
                            }
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

                    Button(action: onDone) {
                        Text("Back to Home")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(BailGradient.accent)
                            .cornerRadius(BailRadius.lg)
                    }
                }
                .padding(.bottom, BailSpacing.xl)
            }
            .padding(.horizontal, BailSpacing.lg)
        }
    }

    // MARK: - Share card

    /// Square card rendered to an image for group chats and stories.
    /// Deliberately shows no names and no vote counts — only the outcome.
    private var shareCard: some View {
        VStack(spacing: 36) {
            Spacer()

            Text("💀")
                .font(.system(size: 180))

            VStack(spacing: 14) {
                Text("It's dead.")
                    .font(.system(size: 88, weight: .heavy))
                    .foregroundColor(BailColor.accentStart)
                    .tracking(-2)
                Text(event.title)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text("no names. no blame. no drama.")
                    .font(.system(size: 32))
                    .foregroundColor(Color(hex: "9A9A9A"))
            }

            Spacer()

            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(BailGradient.accent)
                    .frame(width: 64, height: 64)
                    .overlay(
                        Text("b.")
                            .font(.system(size: 32, weight: .heavy))
                            .foregroundColor(.white)
                    )
                Text("bail.out")
                    .font(.system(size: 40, weight: .heavy))
                    .foregroundColor(.white)
                    .tracking(-1)
            }
            .padding(.bottom, 56)
        }
        .padding(48)
        .frame(width: 1080, height: 1080)
        .background(Color(hex: "0A0A0A"))
    }

    private func renderShareCard() -> UIImage? {
        let renderer = ImageRenderer(content: shareCard)
        renderer.scale = 1
        return renderer.uiImage
    }
}

#if DEBUG
#Preview {
    CancelledView(event: PreviewData.sampleEvents[0])
}
#endif
