import SwiftUI

private struct OnboardingPage {
    let emoji: String
    let title: String
    let subtitle: String
}

private let pages: [OnboardingPage] = [
    OnboardingPage(
        emoji: "🗓️",
        title: "Make a plan",
        subtitle: "Create an event and invite your crew. They get a text with a link to see the details."
    ),
    OnboardingPage(
        emoji: "🔒",
        title: "Vote in secret",
        subtitle: "Everyone votes to bail or stay in. Anonymous, always. Nobody ever sees who chose what — not even you."
    ),
    OnboardingPage(
        emoji: "🚪",
        title: "Bail without the drama",
        subtitle: "When enough people bail, the plan auto-cancels. A neutral message goes out. Nobody's the bad guy."
    ),
]

struct OnboardingView: View {
    var onDone: () -> Void = {}

    @State private var currentPage = 0
    @State private var showNameEntry = false
    @State private var nameInput = ""
    @AppStorage("userDisplayName") private var userDisplayName = ""
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        ZStack {
            BailColor.background.ignoresSafeArea()

            if showNameEntry {
                nameEntryView
            } else {
                tutorialView
            }
        }
    }

    private var tutorialView: some View {
        VStack(spacing: 0) {
            // Skip button
            HStack {
                Spacer()
                Button(action: { withAnimation { showNameEntry = true } }) {
                    Text("Skip")
                        .font(.system(size: 15))
                        .foregroundColor(BailColor.textSecondary)
                }
                .padding(.horizontal, BailSpacing.lg)
                .padding(.top, BailSpacing.md)
            }

            // Swipeable pages
            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { i in
                    pageView(pages[i])
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Dots + button
            VStack(spacing: BailSpacing.lg) {
                dotsIndicator

                if currentPage < pages.count - 1 {
                    Button(action: {
                        withAnimation { currentPage += 1 }
                    }) {
                        Text("Next")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(BailGradient.accent)
                            .cornerRadius(BailRadius.lg)
                            .shadow(color: BailColor.accentStart.opacity(0.3), radius: 15, x: 0, y: 8)
                    }
                } else {
                    Button(action: { withAnimation { showNameEntry = true } }) {
                        Text("Get Started")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(BailGradient.accent)
                            .cornerRadius(BailRadius.lg)
                            .shadow(color: BailColor.accentStart.opacity(0.3), radius: 15, x: 0, y: 8)
                    }
                }
            }
            .padding(.horizontal, BailSpacing.lg)
            .padding(.bottom, BailSpacing.xl)
        }
    }

    // MARK: - Name entry

    private var nameEntryView: some View {
        VStack(spacing: BailSpacing.lg) {
            Spacer()

            Text("👋")
                .font(.system(size: 72))

            VStack(spacing: 12) {
                Text("What should friends call you?")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundColor(BailColor.textPrimary)
                    .tracking(-0.5)
                    .multilineTextAlignment(.center)

                Text("Shown on guest lists and location votes.\nBail votes stay anonymous, always.")
                    .font(.system(size: 15))
                    .foregroundColor(BailColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            TextField("Your first name", text: $nameInput)
                .focused($nameFieldFocused)
                .textContentType(.givenName)
                .autocorrectionDisabled()
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(BailColor.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.vertical, 18)
                .background(BailColor.surface)
                .cornerRadius(BailRadius.lg)
                .overlay(
                    RoundedRectangle(cornerRadius: BailRadius.lg)
                        .stroke(BailColor.border, lineWidth: 1)
                )

            Spacer()

            Button(action: finish) {
                Text("Done")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        trimmedName.isEmpty
                            ? AnyShapeStyle(BailColor.surface2)
                            : AnyShapeStyle(BailGradient.accent)
                    )
                    .cornerRadius(BailRadius.lg)
            }
            .disabled(trimmedName.isEmpty)
            .padding(.bottom, BailSpacing.xl)
        }
        .padding(.horizontal, BailSpacing.lg)
        .onAppear { nameFieldFocused = true }
    }

    private var trimmedName: String {
        nameInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func finish() {
        guard !trimmedName.isEmpty else { return }
        userDisplayName = trimmedName
        onDone()
    }

    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: BailSpacing.lg) {
            Spacer()

            Text(page.emoji)
                .font(.system(size: 72))

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundColor(BailColor.textPrimary)
                    .tracking(-0.5)
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.system(size: 16))
                    .foregroundColor(BailColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.horizontal, BailSpacing.lg)
            }

            Spacer()
        }
        .padding(.horizontal, BailSpacing.lg)
    }

    private var dotsIndicator: some View {
        HStack(spacing: 8) {
            ForEach(pages.indices, id: \.self) { i in
                Capsule()
                    .fill(i == currentPage ? BailColor.accentStart : BailColor.surface2)
                    .frame(width: i == currentPage ? 20 : 8, height: 8)
                    .animation(.easeInOut(duration: 0.25), value: currentPage)
            }
        }
    }
}

#Preview {
    OnboardingView()
}
