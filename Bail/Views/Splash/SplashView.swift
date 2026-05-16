import SwiftUI

struct SplashView: View {
    var onGetStarted: () -> Void = {}
    var onSignIn: () -> Void = {}

    var body: some View {
        ZStack {
            BailColor.background.ignoresSafeArea()

            VStack(spacing: BailSpacing.lg) {
                Spacer()

                // App icon
                ZStack {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(BailGradient.accent)
                        .frame(width: 100, height: 100)
                        .shadow(
                            color: BailColor.accentStart.opacity(0.4),
                            radius: 30, x: 0, y: 20
                        )
                    Text("🚪")
                        .font(.system(size: 50))
                }

                // Brand text
                VStack(spacing: BailSpacing.sm) {
                    Text("bail.")
                        .font(.system(size: 42, weight: .heavy))
                        .foregroundColor(BailColor.textPrimary)
                        .tracking(-2)

                    Text("no pressure. no drama.")
                        .font(.system(size: 16))
                        .foregroundColor(BailColor.textSecondary)
                        .tracking(0.2)
                }

                Spacer()

                // CTA buttons
                VStack(spacing: 12) {
                    Button(action: onGetStarted) {
                        Text("Get Started")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(BailGradient.accent)
                            .cornerRadius(BailRadius.lg)
                            .shadow(
                                color: BailColor.accentStart.opacity(0.35),
                                radius: 15, x: 0, y: 8
                            )
                    }

                    Button(action: onSignIn) {
                        Text("Sign In")
                            .font(.system(size: 17))
                            .foregroundColor(Color(hex: "AAAAAA"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(BailColor.surface2)
                            .cornerRadius(BailRadius.lg)
                            .overlay(
                                RoundedRectangle(cornerRadius: BailRadius.lg)
                                    .stroke(Color(hex: "333333"), lineWidth: 1)
                            )
                    }
                }

                Text("Everyone secretly votes. No blame. No awkward texts.")
                    .font(.system(size: 12))
                    .foregroundColor(BailColor.textMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.bottom, BailSpacing.lg)
            }
            .padding(.horizontal, BailSpacing.xl)
        }
    }
}

#Preview {
    SplashView(
        onGetStarted: { print("Get Started tapped") },
        onSignIn:     { print("Sign In tapped") }
    )
}
