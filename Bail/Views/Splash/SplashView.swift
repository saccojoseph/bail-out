import SwiftUI

struct SplashView: View {
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
                    Text("bail.out")
                        .font(.system(size: 42, weight: .heavy))
                        .foregroundColor(BailColor.textPrimary)
                        .tracking(-2)

                    Text("no pressure. no drama.")
                        .font(.system(size: 16))
                        .foregroundColor(BailColor.textSecondary)
                        .tracking(0.2)
                }

                Spacer()

                // Sign in
                VStack(spacing: 12) {
                    Button(action: onSignIn) {
                        HStack(spacing: 10) {
                            Image(systemName: "applelogo")
                                .font(.system(size: 17, weight: .semibold))
                            Text("Sign in with Apple")
                                .font(.system(size: 17, weight: .bold))
                        }
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

                    Text("Uses your iCloud account — no password needed.")
                        .font(.system(size: 12))
                        .foregroundColor(BailColor.textMuted)
                        .multilineTextAlignment(.center)
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
    SplashView(onSignIn: { print("Sign In tapped") })
}
