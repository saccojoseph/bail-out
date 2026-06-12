import SwiftUI
import Contacts
import StoreKit

struct CreateEventView: View {
    var onDismiss: () -> Void = {}
    var onComplete: (Event) -> Void = { _ in }

    @Environment(\.requestReview) private var requestReview
    @AppStorage("hasSentFirstInvite") private var hasSentFirstInvite = false

    @StateObject private var contactsService = ContactsService()

    @State private var currentStep = 1
    @State private var title = ""
    @State private var scheduledAt = Date()
    @State private var location = ""
    @State private var locationAddress = ""
    @State private var selectedContactIds: Set<String> = []
    @State private var searchText = ""
    @State private var threshold: BailThreshold = .majority
    @State private var isBailEvent = true
    @State private var isAnonymous = true
    @State private var showBailOMeter = true
    @State private var showVotingStatus = true

    // Location voting
    @State private var locationMode: LocationMode = .fixed
    @State private var locationVoteOptions: [(name: String, address: String)] = []
    @State private var newOptionName = ""
    @State private var newOptionAddress = ""

    @State private var pendingEvent: Event? = nil
    @State private var pendingMessage: PendingMessage? = nil

    enum LocationMode: String {
        case fixed  // single location (current behavior)
        case vote   // guests vote on location
    }

    var body: some View {
        VStack(spacing: 0) {
            navBar
            stepIndicator

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    switch currentStep {
                    case 1: step1
                    case 2: step2
                    case 3: step3
                    default: EmptyView()
                    }
                }
                .padding(.horizontal, BailSpacing.lg)
                .padding(.top, BailSpacing.md)
                .padding(.bottom, BailSpacing.lg)
            }
        }
        .background(BailColor.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            continueButton
                .padding(.horizontal, BailSpacing.lg)
                .padding(.vertical, BailSpacing.md)
                .background(BailColor.background)
        }
        .onChange(of: currentStep) { _, new in
            if new == 2 { Task { await contactsService.requestAccess() } }
        }
#if os(iOS)
        .sheet(item: $pendingMessage) { msg in
            MessageComposer(recipients: msg.recipients, body: msg.body) {
                if let event = pendingEvent { onComplete(event) }
            } onSent: {
                if !hasSentFirstInvite {
                    hasSentFirstInvite = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        requestReview()
                    }
                }
            }
            .ignoresSafeArea()
        }
#endif
    }

    // MARK: - Nav bar

    private var navBar: some View {
        HStack(spacing: 12) {
            Button(action: {
                if currentStep == 1 { onDismiss() }
                else { currentStep -= 1 }
            }) {
                Text("‹")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(BailColor.accentStart)
            }
            Text(stepTitle)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(BailColor.textPrimary)
                .tracking(-0.5)
            Spacer()
        }
        .padding(.horizontal, BailSpacing.lg)
        .padding(.vertical, 12)
    }

    private var stepTitle: String {
        switch currentStep {
        case 1: return "New Plan"
        case 2: return "Invite Friends"
        case 3: return "Bail Rules"
        default: return ""
        }
    }

    // MARK: - Step indicator

    private var stepIndicator: some View {
        HStack(spacing: 6) {
            ForEach(1...3, id: \.self) { step in
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        step <= currentStep
                            ? AnyShapeStyle(BailGradient.accentHorizontal)
                            : AnyShapeStyle(BailColor.cardBorder)
                    )
                    .frame(height: 3)
            }
        }
        .padding(.horizontal, BailSpacing.lg)
        .padding(.bottom, BailSpacing.sm)
    }

    // MARK: - Step 1: Event details

    private var step1: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("What's the plan?")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(BailColor.textPrimary)
                .tracking(-0.5)

            VStack(spacing: 12) {
                inputField(label: "Event Name", placeholder: "e.g. Dinner at Zinc", text: $title)
                dateField
                locationModeSection
            }
        }
    }

    // MARK: - Location mode

    private var locationModeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LOCATION")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(BailColor.textSecondary)
                .tracking(1)

            // Mode picker
            HStack(spacing: 8) {
                locationModeButton(mode: .fixed, label: "Fixed Place", icon: "mappin")
                locationModeButton(mode: .vote, label: "Let Guests Vote", icon: "hand.raised")
            }

            if locationMode == .fixed {
                fixedLocationPicker
            } else {
                locationVotePicker
            }
        }
    }

    private func locationModeButton(mode: LocationMode, label: String, icon: String) -> some View {
        let isSelected = locationMode == mode
        return Button(action: { locationMode = mode }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(isSelected ? .white : BailColor.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? AnyShapeStyle(BailGradient.accent) : AnyShapeStyle(BailColor.surface))
            .cornerRadius(BailRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: BailRadius.md)
                    .stroke(isSelected ? Color.clear : BailColor.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var fixedLocationPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            LocationSearchField(
                locationName: $location,
                locationAddress: $locationAddress,
                placeholder: "Search for a place..."
            )
            Text("Optional — leave blank if undecided")
                .font(.system(size: 11))
                .foregroundColor(BailColor.textMuted)
        }
    }

    // MARK: - Location vote picker (multi-option)

    private var locationVotePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add 2+ places for guests to vote on:")
                .font(.system(size: 13))
                .foregroundColor(BailColor.textSecondary)

            // Current options
            ForEach(Array(locationVoteOptions.enumerated()), id: \.offset) { index, option in
                HStack(spacing: 10) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(BailColor.accentStart)
                        .font(.system(size: 16))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(option.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(BailColor.textPrimary)
                            .lineLimit(1)
                        if !option.address.isEmpty {
                            Text(option.address)
                                .font(.system(size: 11))
                                .foregroundColor(BailColor.textMuted)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    Button(action: { locationVoteOptions.remove(at: index) }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(BailColor.textMuted)
                            .font(.system(size: 16))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(BailColor.surface)
                .cornerRadius(BailRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: BailRadius.md)
                        .stroke(BailColor.border, lineWidth: 1)
                )
            }

            // Add new option search
            LocationSearchField(
                locationName: $newOptionName,
                locationAddress: $newOptionAddress,
                placeholder: "Search to add a place..."
            ) { name, address in
                locationVoteOptions.append((name: name, address: address))
                newOptionName = ""
                newOptionAddress = ""
            }

            if locationVoteOptions.count < 2 {
                Text("Add at least \(2 - locationVoteOptions.count) more place\(locationVoteOptions.count == 1 ? "" : "s")")
                    .font(.system(size: 12))
                    .foregroundColor(BailColor.accentStart)
            }
        }
    }

    private func inputField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(BailColor.textSecondary)
                .tracking(1)
            TextField(placeholder, text: text)
                .font(.system(size: 16))
                .foregroundColor(BailColor.textPrimary)
                .tint(BailColor.accentStart)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(BailColor.surface)
                .cornerRadius(BailRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: BailRadius.md)
                        .stroke(BailColor.border, lineWidth: 1)
                )
        }
    }

    private var dateField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DATE & TIME")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(BailColor.textSecondary)
                .tracking(1)
            DatePicker("", selection: $scheduledAt, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.compact)
                .labelsHidden()
                .colorScheme(.dark)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(BailColor.surface)
                .cornerRadius(BailRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: BailRadius.md)
                        .stroke(BailColor.border, lineWidth: 1)
                )
        }
    }

    // MARK: - Step 2: Contacts

    private var step2: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Who's invited?")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(BailColor.textPrimary)
                .tracking(-0.5)

            switch contactsService.authStatus {
            case .authorized:
                contactsContent
            case .denied, .restricted:
                permissionDeniedView
            default:
                requestPermissionView
            }
        }
    }

    private var contactsContent: some View {
        VStack(spacing: 10) {
            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(BailColor.textSecondary)
                    .font(.system(size: 15))
                TextField("Search contacts...", text: $searchText)
                    .font(.system(size: 15))
                    .foregroundColor(BailColor.textPrimary)
                    .tint(BailColor.accentStart)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(BailColor.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(BailColor.surface)
            .cornerRadius(BailRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: BailRadius.md)
                    .stroke(BailColor.border, lineWidth: 1)
            )

            if filteredContacts.isEmpty {
                Text("No contacts found")
                    .font(.system(size: 14))
                    .foregroundColor(BailColor.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, BailSpacing.lg)
            } else {
                ForEach(filteredContacts) { contact in
                    contactRow(contact)
                }
            }
        }
    }

    private var filteredContacts: [AppContact] {
        guard !searchText.isEmpty else { return contactsService.contacts }
        return contactsService.contacts.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func contactRow(_ contact: AppContact) -> some View {
        let isSelected = selectedContactIds.contains(contact.id)
        return Button(action: { toggleContact(contact.id) }) {
            HStack(spacing: 14) {
                Circle()
                    .fill(Color(hex: contact.avatarColor))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(contact.displayName.prefix(1)))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.displayName)
                        .font(.system(size: 16))
                        .foregroundColor(BailColor.textPrimary)
                    Text(contact.phoneNumber)
                        .font(.system(size: 12))
                        .foregroundColor(BailColor.textSecondary)
                }
                Spacer()
                if isSelected {
                    Text("✓")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(BailColor.accentStart)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? BailColor.surface2 : BailColor.surface)
            .cornerRadius(BailRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: BailRadius.lg)
                    .stroke(isSelected ? BailColor.accentStart : BailColor.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var requestPermissionView: some View {
        VStack(spacing: 12) {
            Text("👥")
                .font(.system(size: 40))
            Text("Access your contacts to invite friends")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(BailColor.textPrimary)
                .multilineTextAlignment(.center)
            Text("bail.out only reads names and phone numbers.")
                .font(.system(size: 13))
                .foregroundColor(BailColor.textSecondary)
                .multilineTextAlignment(.center)
            Button(action: { Task { await contactsService.requestAccess() } }) {
                Text("Allow Contacts")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(BailGradient.accent)
                    .cornerRadius(BailRadius.lg)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, BailSpacing.xl)
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 12) {
            Text("🔒")
                .font(.system(size: 40))
            Text("Contacts access denied")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(BailColor.textPrimary)
            Text("Enable it in Settings → bail.out → Contacts")
                .font(.system(size: 13))
                .foregroundColor(BailColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, BailSpacing.xl)
    }

    private func toggleContact(_ id: String) {
        if selectedContactIds.contains(id) {
            selectedContactIds.remove(id)
        } else {
            selectedContactIds.insert(id)
        }
    }

    // MARK: - Step 3: Bail rules + privacy

    private var step3: some View {
        VStack(alignment: .leading, spacing: 24) {

            // "Just an event" master toggle
            privacyToggle(
                title: "Enable bail voting",
                subtitle: isBailEvent
                    ? "Friends can vote to bail — plan auto-cancels if enough do"
                    : "This is just an event — no voting, no auto-cancel",
                isOn: $isBailEvent
            )

            // Section 1: Bail rules (greyed out when bail voting is off)
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bail Rules")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(isBailEvent ? BailColor.textPrimary : BailColor.textMuted)
                    Text("How many bails to auto-cancel?")
                        .font(.system(size: 13))
                        .foregroundColor(isBailEvent ? BailColor.textSecondary : BailColor.textMuted)
                }
                VStack(spacing: 10) {
                    ForEach([BailThreshold.all, .majority, .any], id: \.self) { option in
                        thresholdRow(option)
                    }
                }
            }
            .opacity(isBailEvent ? 1 : 0.35)
            .disabled(!isBailEvent)

            Rectangle()
                .fill(BailColor.border)
                .frame(height: 1)

            // Section 2: Privacy (greyed out when bail voting is off)
            VStack(alignment: .leading, spacing: 12) {
                Text("Privacy")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(isBailEvent ? BailColor.textPrimary : BailColor.textMuted)

                anonymityToggle
                bailOMeterToggle
                votingStatusToggle
            }
            .opacity(isBailEvent ? 1 : 0.35)
            .disabled(!isBailEvent)
        }
    }

    private func thresholdRow(_ option: BailThreshold) -> some View {
        let isSelected = threshold == option
        return Button(action: { threshold = option }) {
            VStack(alignment: .leading, spacing: 3) {
                Text(option.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(BailColor.textPrimary)
                Text(option.description)
                    .font(.system(size: 12))
                    .foregroundColor(BailColor.textSubtle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(isSelected ? BailColor.surface2 : BailColor.surface)
            .cornerRadius(BailRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: BailRadius.lg)
                    .stroke(isSelected ? BailColor.accentStart : BailColor.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var anonymityToggle: some View {
        privacyToggle(
            title: "Anonymous voting",
            subtitle: isAnonymous
                ? "Nobody ever sees who voted — only the outcome"
                : "Everyone can see how each person voted",
            isOn: $isAnonymous,
            note: isAnonymous
                ? "Votes are encrypted. Nobody — not even the creator — can see individual choices."
                : nil
        )
    }

    private var bailOMeterToggle: some View {
        privacyToggle(
            title: "Show Bail-o-meter",
            subtitle: showBailOMeter
                ? "Guests can see how close the plan is to cancelling"
                : "Bail count is hidden until the plan is cancelled",
            isOn: $showBailOMeter
        )
    }

    private var votingStatusToggle: some View {
        privacyToggle(
            title: "Show who has voted",
            subtitle: showVotingStatus
                ? "Guests can see who has voted (not what they chose)"
                : "Voting status is hidden from all guests",
            isOn: $showVotingStatus
        )
    }

    private func privacyToggle(title: String, subtitle: String, isOn: Binding<Bool>, note: String? = nil) -> some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(BailColor.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(BailColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Toggle("", isOn: isOn)
                    .tint(BailColor.accentStart)
                    .labelsHidden()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(BailColor.surface2)
            .cornerRadius(BailRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: BailRadius.lg)
                    .stroke(BailColor.border, lineWidth: 1)
            )

            if let note {
                HStack(alignment: .top, spacing: 8) {
                    Text("🔒").font(.system(size: 12))
                    Text(note)
                        .font(.system(size: 12))
                        .foregroundColor(BailColor.textSecondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(BailColor.accentStart.opacity(0.08))
                .cornerRadius(BailRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: BailRadius.md)
                        .stroke(BailColor.accentStart.opacity(0.15), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Continue / submit

    private var continueButton: some View {
        Button(action: advance) {
            Text(currentStep < 3 ? "Continue →" : "Send Invites")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(BailGradient.accent)
                .cornerRadius(BailRadius.lg)
                .shadow(color: BailColor.accentStart.opacity(0.3), radius: 15, x: 0, y: 8)
        }
    }

    private func advance() {
        if currentStep < 3 {
            currentStep += 1
        } else {
            let event = buildEvent()
            pendingEvent = event
#if os(iOS)
            if MessageComposer.canSend && !selectedContactIds.isEmpty {
                let recipients = contactsService.contacts
                    .filter { selectedContactIds.contains($0.id) }
                    .map { $0.phoneNumber }
                let body = InviteLink.body(
                    title: event.title,
                    dateString: event.scheduledAt.inviteString,
                    eventId: event.id
                )
                pendingMessage = PendingMessage(recipients: recipients, body: body)
            } else {
                onComplete(event)
            }
#else
            onComplete(event)
#endif
        }
    }

    private func buildEvent() -> Event {
        let newId = UUID().uuidString
        let chosenGuests = contactsService.contacts
            .filter { selectedContactIds.contains($0.id) }
            .map { c in
                EventGuest(
                    id: UUID().uuidString,
                    eventId: newId,
                    userId: "",
                    displayName: c.displayName,
                    phoneNumber: c.phoneNumber,
                    avatarColor: c.avatarColor,
                    status: .pending
                )
            }
        let requiredBails: Int
        switch threshold {
        case .all:      requiredBails = max(chosenGuests.count, 1)
        case .majority: requiredBails = chosenGuests.count / 2 + 1
        case .any:      requiredBails = 1
        }

        let votingStatus: LocationVotingStatus = locationMode == .vote && locationVoteOptions.count >= 2
            ? .voting : .disabled
        let options: [LocationOption] = votingStatus == .voting
            ? locationVoteOptions.map { opt in
                LocationOption(
                    id: UUID().uuidString,
                    eventId: newId,
                    name: opt.name,
                    address: opt.address.isEmpty ? nil : opt.address,
                    addedBy: "u0",
                    voteCount: 0,
                    voters: []
                )
            }
            : []

        let eventLocation: String? = locationMode == .fixed
            ? (location.isEmpty ? nil : location)
            : nil  // location determined by vote

        return Event(
            id: newId,
            title: title.isEmpty ? "Untitled Plan" : title,
            scheduledAt: scheduledAt,
            location: eventLocation,
            creatorId: "u0",
            threshold: threshold,
            status: .active,
            summary: EventSummary(bailCount: 0, totalVotes: 0, requiredBails: requiredBails),
            guests: chosenGuests,
            isAnonymous: isAnonymous,
            showBailOMeter: showBailOMeter,
            showVotingStatus: showVotingStatus,
            isBailEvent: isBailEvent,
            locationVotingStatus: votingStatus,
            locationOptions: options,
            resolvedLocationId: nil,
            createdAt: Date()
        )
    }
}

#Preview {
    CreateEventView(
        onDismiss:  {},
        onComplete: { _ in }
    )
}
