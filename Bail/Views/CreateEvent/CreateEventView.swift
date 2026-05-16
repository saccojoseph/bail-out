import SwiftUI
import Contacts

struct CreateEventView: View {
    var onDismiss: () -> Void = {}
    var onComplete: (Event) -> Void = { _ in }

    @StateObject private var contactsService = ContactsService()

    @State private var currentStep = 1
    @State private var title = ""
    @State private var scheduledAt = Date()
    @State private var location = ""
    @State private var selectedContactIds: Set<String> = []
    @State private var searchText = ""
    @State private var threshold: BailThreshold = .majority
    @State private var isAnonymous = true
    @State private var showBailOMeter = true
    @State private var showVotingStatus = true

    @State private var pendingEvent: Event? = nil
    @State private var showingMessageComposer = false

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
        .sheet(isPresented: $showingMessageComposer) {
            if let event = pendingEvent {
                let phones = contactsService.contacts
                    .filter { selectedContactIds.contains($0.id) }
                    .map { $0.phoneNumber }
                let body = "Hey! You're invited to \"\(event.title)\" on \(event.scheduledAt.inviteString). Open in bail. to vote: bail://event/\(event.id) 👀"
                MessageComposer(recipients: phones, body: body) {
                    onComplete(event)
                }
                .ignoresSafeArea()
            }
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
                            : AnyShapeStyle(Color(hex: "222222"))
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
                inputField(label: "Location (Optional)", placeholder: "Add a location...", text: $location)
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
            .background(isSelected ? BailColor.surface2 : Color(hex: "111111"))
            .cornerRadius(BailRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: BailRadius.lg)
                    .stroke(isSelected ? BailColor.accentStart : Color(hex: "222222"), lineWidth: 1)
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
            Text("bail. only reads names and phone numbers.")
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
            Text("Enable it in Settings → bail. → Contacts")
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

            // Section 1: Bail rules
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bail Rules")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(BailColor.textPrimary)
                    Text("How many bails to auto-cancel?")
                        .font(.system(size: 13))
                        .foregroundColor(BailColor.textSecondary)
                }
                VStack(spacing: 10) {
                    ForEach([BailThreshold.all, .majority, .any], id: \.self) { option in
                        thresholdRow(option)
                    }
                }
            }

            Rectangle()
                .fill(BailColor.border)
                .frame(height: 1)

            // Section 2: Privacy
            VStack(alignment: .leading, spacing: 12) {
                Text("Privacy")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(BailColor.textPrimary)

                anonymityToggle
                bailOMeterToggle
                votingStatusToggle
            }
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
                    .foregroundColor(Color(hex: "555555"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(isSelected ? BailColor.surface2 : Color(hex: "111111"))
            .cornerRadius(BailRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: BailRadius.lg)
                    .stroke(isSelected ? BailColor.accentStart : Color(hex: "222222"), lineWidth: 1)
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
            Text(currentStep < 3 ? "Continue →" : "Send Invites 🚀")
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
                showingMessageComposer = true
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
        return Event(
            id: newId,
            title: title.isEmpty ? "Untitled Plan" : title,
            scheduledAt: scheduledAt,
            location: location.isEmpty ? nil : location,
            creatorId: "u0",
            threshold: threshold,
            status: .active,
            summary: EventSummary(bailCount: 0, totalVotes: 0, requiredBails: requiredBails),
            guests: chosenGuests,
            isAnonymous: isAnonymous,
            showBailOMeter: showBailOMeter,
            showVotingStatus: showVotingStatus,
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
