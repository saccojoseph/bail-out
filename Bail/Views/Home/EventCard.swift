import SwiftUI

struct EventCard: View {
    let event: Event

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topRow
            avatarRow.padding(.top, 14)
            if event.showBailOMeter {
                bailOMeter.padding(.top, 14)
            }
        }
        .padding(20)
        .background(BailColor.surface)
        .cornerRadius(BailRadius.xl)
        .overlay(
            RoundedRectangle(cornerRadius: BailRadius.xl)
                .stroke(BailColor.cardBorder, lineWidth: 1)
        )
    }

    // MARK: - Top row

    private var topRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(BailColor.textPrimary)
                Text(event.scheduledAt.eventTimeString)
                    .font(.system(size: 13))
                    .foregroundColor(BailColor.textSecondary)
            }
            Spacer()
            statusBadge
        }
    }

    private var statusBadge: some View {
        let hasBails = event.summary.bailCount > 0
        let label    = hasBails ? "\(event.summary.bailCount) bailed" : "All in"
        let fg       = hasBails ? BailColor.accentStart : BailColor.teal
        let bg       = hasBails ? BailColor.accentStart.opacity(0.15) : BailColor.teal.opacity(0.15)
        return Text(label)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(fg)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(bg)
            .cornerRadius(10)
    }

    // MARK: - Avatar row

    private var avatarRow: some View {
        HStack(spacing: 0) {
            HStack(spacing: -8) {
                ForEach(event.guests) { guest in
                    Circle()
                        .fill(Color(hex: guest.avatarColor))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text(String(guest.displayName.prefix(1)))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.black)
                        )
                        .overlay(Circle().stroke(BailColor.surface, lineWidth: 2))
                }
            }
            Text("\(event.guests.count) invited")
                .font(.system(size: 12))
                .foregroundColor(BailColor.textSubtle)
                .padding(.leading, 12)
        }
    }

    // MARK: - Bail-o-meter

    private var bailOMeter: some View {
        VStack(spacing: 6) {
            HStack {
                Text("BAIL-O-METER")
                    .font(.system(size: 11))
                    .foregroundColor(BailColor.textSubtle)
                Spacer()
                Text("\(event.summary.bailCount)/\(event.summary.requiredBails) to cancel")
                    .font(.system(size: 11))
                    .foregroundColor(BailColor.textSubtle)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(BailColor.cardBorder)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(BailGradient.accentHorizontal)
                        .frame(width: geo.size.width * event.summary.progress)
                }
            }
            .frame(height: 4)
        }
    }
}

#if DEBUG
#Preview {
    ZStack {
        BailColor.background.ignoresSafeArea()
        EventCard(event: PreviewData.sampleEvents[0])
            .padding()
    }
}
#endif
