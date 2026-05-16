import SwiftUI
import Contacts

struct EventDetailView: View {
    let event: Event
    var userVote: VoteChoice? = nil
    var isCreator: Bool = false
    var onBack: () -> Void = {}
    var onVote: () -> Void = {}
    var onAddGuests: ([(name: String, phone: String, color: String)]) -> Void = { _ in }
    var onRemoveGuest: (String) -> Void = { _ in }
    var onCancelEvent: () -> Void = {}
    var onEditTitle: (String) -> Void = { _ in }

    @StateObject private var contactsService = ContactsService()
    @State private var showAddGuest = false
    @State private var selectedContactIds: Set<String> = []
    @State private var addSearchText = ""
    @State private var manualName = ""
    @State private var manualPhone = ""
    @State private var showCancelConfirm = false
    @State private var showEditTitle = false
    @State private var editedTitle = ""
    @State private var showingMessageComposer = false
    @State private var messageRecipients: [String] = []
    @State private var messageBody: String = ""

    var body: some View {
        ZStack {
            BailColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                navBar

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        eventHeader
                        guestsCard
                        if event.isBailEvent && event.showBailOMeter {
                            bailOMeterCard
                        }
                        if event.isBailEvent {
                            voteSection
                        }
                        if isCreator && event.status == .active {
                            creatorActions
                        }
                    }
                    .padding(.horizontal, BailSpacing.lg)
                    .padding(.top, BailSpacing.md)
                    .padding(.bottom, BailSpacing.xl)
                }
            }
        }
        .sheet(isPresented: $showAddGuest) {
            addGuestSheet
        }
        .sheet(isPresented: $showEditTitle) {
            editTitleSheet
        }
#if os(iOS)
        .sheet(isPresented: $showingMessageComposer) {
            MessageComposer(recipients: messageRecipients, body: messageBody) {}
                .ignoresSafeArea()
        }
#endif
        .confirmationDialog("Cancel this plan?", isPresented: $showCancelConfirm, titleVisibility: .visible) {
            Button("Yes, cancel it", role: .destructive) { onCancelEvent() }
            Button("Never mind", role: .cancel) {}
        } message: {
            Text("Everyone will be notified that the plan is off.")
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
            HStack(alignment: .top) {
                Text(event.title)
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundColor(BailColor.textPrimary)
                    .tracking(-1)
                if isCreator && event.status == .active {
                    Button(action: {
                        editedTitle = event.title
                        showEditTitle = true
                    }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 14))
                            .foregroundColor(BailColor.textSecondary)
                            .padding(.top, 6)
                    }
                }
            }
            if let location = event.location {
                Text("📍 \(location)")
                    .font(.system(size: 14))
                    .foregroundColor(BailColor.textSubtle)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Creator actions

    private var creatorActions: some View {
        Button(action: { showCancelConfirm = true }) {
            Text("Cancel Plan")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(BailColor.accentStart)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(BailColor.surface)
                .cornerRadius(BailRadius.xl)
                .overlay(
                    RoundedRectangle(cornerRadius: BailRadius.xl)
                        .stroke(BailColor.cardBorder, lineWidth: 1)
                )
        }
    }

    // MARK: - Edit title sheet

    private var editTitleSheet: some View {
        NavigationStack {
            ZStack {
                BailColor.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 8) {
                    Text("EVENT NAME")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(BailColor.textSecondary)
                        .tracking(1)
                    TextField("Event name", text: $editedTitle)
                        .font(.system(size: 18, weight: .semibold))
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
                    Spacer()
                }
                .padding(.horizontal, BailSpacing.lg)
                .padding(.top, BailSpacing.lg)
            }
            .navigationTitle("Edit Name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showEditTitle = false }
                        .foregroundColor(BailColor.accentStart)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = editedTitle.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty { onEditTitle(trimmed) }
                        showEditTitle = false
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(editedTitle.trimmingCharacters(in: .whitespaces).isEmpty ? BailColor.textMuted : BailColor.accentStart)
                    .disabled(editedTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            
        }
    }

    // MARK: - Guests card

    private var guestsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("INVITED")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(BailColor.textSecondary)
                    .tracking(1)
                Spacer()
                if isCreator {
                    Button(action: { showAddGuest = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .bold))
                            Text("Add")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(BailColor.accentStart)
                    }
                }
            }

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
                    if isCreator {
                        Button(action: { onRemoveGuest(guest.id) }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(BailColor.textMuted)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(18)
        .background(BailColor.surface)
        .cornerRadius(BailRadius.xl)
        .overlay(
            RoundedRectangle(cornerRadius: BailRadius.xl)
                .stroke(BailColor.cardBorder, lineWidth: 1)
        )
    }

    // MARK: - Add guests sheet

    private var addGuestSheet: some View {
        NavigationStack {
            ZStack {
                BailColor.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        switch contactsService.authStatus {
                        case .authorized:
                            contactsPickerContent
                        case .denied, .restricted:
                            permissionDeniedView
                        default:
                            requestPermissionView
                        }
                    }
                    .padding(.horizontal, BailSpacing.lg)
                    .padding(.top, BailSpacing.md)
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("Add People")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismissAddSheet() }
                        .foregroundColor(BailColor.accentStart)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(addButtonLabel) { confirmAddGuests() }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(canConfirmAdd ? BailColor.accentStart : BailColor.textMuted)
                        .disabled(!canConfirmAdd)
                }
            }
            
            .task { await contactsService.requestAccess() }
        }
    }

    private var addButtonLabel: String {
        let count = selectedContactIds.count + (manualName.trimmingCharacters(in: .whitespaces).isEmpty ? 0 : 1)
        return count > 0 ? "Add \(count)" : "Add"
    }

    private var canConfirmAdd: Bool {
        !selectedContactIds.isEmpty || !manualName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var contactsPickerContent: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(BailColor.textSecondary)
                    .font(.system(size: 15))
                TextField("Search contacts...", text: $addSearchText)
                    .font(.system(size: 15))
                    .foregroundColor(BailColor.textPrimary)
                    .tint(BailColor.accentStart)
                if !addSearchText.isEmpty {
                    Button(action: { addSearchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(BailColor.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(BailColor.surface)
            .cornerRadius(BailRadius.md)
            .overlay(RoundedRectangle(cornerRadius: BailRadius.md).stroke(BailColor.border, lineWidth: 1))

            // Contacts list
            let filtered = filteredAddContacts
            if filtered.isEmpty && !addSearchText.isEmpty {
                Text("No contacts found")
                    .font(.system(size: 14))
                    .foregroundColor(BailColor.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, BailSpacing.md)
            } else {
                ForEach(filtered) { contact in
                    addContactRow(contact)
                }
            }

            // Divider + manual entry
            Rectangle().fill(BailColor.border).frame(height: 1).padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 10) {
                Text("NOT IN CONTACTS")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(BailColor.textMuted)
                    .tracking(1)

                TextField("Name", text: $manualName)
                    .font(.system(size: 15))
                    .foregroundColor(BailColor.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(BailColor.surface)
                    .cornerRadius(BailRadius.md)
                    .overlay(RoundedRectangle(cornerRadius: BailRadius.md).stroke(BailColor.border, lineWidth: 1))

                TextField("Phone (optional)", text: $manualPhone)
                    .font(.system(size: 15))
                    .foregroundColor(BailColor.textPrimary)
                    .keyboardType(.phonePad)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(BailColor.surface)
                    .cornerRadius(BailRadius.md)
                    .overlay(RoundedRectangle(cornerRadius: BailRadius.md).stroke(BailColor.border, lineWidth: 1))
            }
        }
    }

    private var filteredAddContacts: [AppContact] {
        let alreadyInvited = Set(event.guests.compactMap { $0.phoneNumber }.map { PhoneNumberUtils.normalize($0) })
        let available = contactsService.contacts.filter {
            !alreadyInvited.contains(PhoneNumberUtils.normalize($0.phoneNumber))
        }
        guard !addSearchText.isEmpty else { return available }
        return available.filter { $0.displayName.localizedCaseInsensitiveContains(addSearchText) }
    }

    private func addContactRow(_ contact: AppContact) -> some View {
        let isSelected = selectedContactIds.contains(contact.id)
        return Button(action: {
            if isSelected { selectedContactIds.remove(contact.id) }
            else { selectedContactIds.insert(contact.id) }
        }) {
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
                        .font(.system(size: 15))
                        .foregroundColor(BailColor.textPrimary)
                    Text(contact.phoneNumber)
                        .font(.system(size: 12))
                        .foregroundColor(BailColor.textSecondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(BailColor.accentStart)
                }
            }
            .padding(.horizontal, 14)
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
            Text("👥").font(.system(size: 40))
            Text("Access your contacts to invite friends")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(BailColor.textPrimary)
                .multilineTextAlignment(.center)
            Button(action: { Task { await contactsService.requestAccess() } }) {
                Text("Allow Contacts")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24).padding(.vertical, 12)
                    .background(BailGradient.accent)
                    .cornerRadius(BailRadius.lg)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, BailSpacing.xl)
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 12) {
            Text("🔒").font(.system(size: 40))
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

    private func confirmAddGuests() {
        var toAdd: [(name: String, phone: String, color: String)] = []

        // Selected contacts
        for contact in contactsService.contacts where selectedContactIds.contains(contact.id) {
            toAdd.append((name: contact.displayName, phone: contact.phoneNumber, color: contact.avatarColor))
        }

        // Manual entry
        let trimmedName = manualName.trimmingCharacters(in: .whitespaces)
        if !trimmedName.isEmpty {
            toAdd.append((name: trimmedName, phone: manualPhone, color: ContactsService.color(for: trimmedName)))
        }

        if !toAdd.isEmpty { onAddGuests(toAdd) }

        // Collect phone numbers to text (skip manual entries with no phone)
        let phones = toAdd.compactMap { $0.phone.isEmpty ? nil : $0.phone }
        dismissAddSheet()

#if os(iOS)
        if MessageComposer.canSend && !phones.isEmpty {
            messageRecipients = phones
            messageBody = "Hey! You're invited to \"\(event.title)\" on \(event.scheduledAt.inviteString). Open in bail. to vote: bail://event/\(event.id) 👀"
            // Small delay so the add-guest sheet finishes dismissing before iMessage slides up
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                showingMessageComposer = true
            }
        }
#endif
    }

    private func dismissAddSheet() {
        selectedContactIds = []
        addSearchText = ""
        manualName = ""
        manualPhone = ""
        showAddGuest = false
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
                        .fill(BailColor.cardBorder)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(BailGradient.accentHorizontal)
                        .frame(width: geo.size.width * event.summary.progress)
                        .shadow(color: BailColor.accentStart.opacity(0.4), radius: 6)
                }
            }
            .frame(height: 8)
            Text("\(event.summary.bailCount) anonymous bail\(event.summary.bailCount == 1 ? "" : "s") recorded")
                .font(.system(size: 12))
                .foregroundColor(BailColor.textSubtle)
        }
        .padding(18)
        .background(BailColor.surface)
        .cornerRadius(BailRadius.xl)
        .overlay(
            RoundedRectangle(cornerRadius: BailRadius.xl)
                .stroke(BailColor.cardBorder, lineWidth: 1)
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
                    Text("You voted: \(vote == .bail ? "Bail" : "I'm In")")
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
