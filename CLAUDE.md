# bail.out — iOS App

## What This Is
Social app where friend groups anonymously vote to cancel plans. If enough people bail, the event auto-cancels with a neutral canned message. Nobody ever knows who bailed.

## Tech Stack
- Swift 5.9+, SwiftUI (all UI), Xcode 26 beta
- Backend: CloudKit (public database, iCloud.com.sacco.bail-app container)
- Auth: iCloud automatic — session tracked via @AppStorage("hasCompletedOnboarding") + @AppStorage("hasSeenOnboarding")
- Push: Silent push via CKSubscription for real-time vote sync
- Local notifications: UNUserNotificationCenter
- Contacts: CNContactStore + MFMessageComposeViewController for SMS invites
- No third-party UI libraries — pure SwiftUI only
- Bundle ID: com.josephsacco.bail-app

## Project Structure
```
Bail/
├── BailApp.swift              — @main entry + AppDelegate for push
├── ContentView.swift          — screen routing, CloudKit state, all handlers, deep links
├── PreviewData.swift          — #if DEBUG sample data (includes location voting samples)
├── Bail.entitlements          — CloudKit + push entitlements
├── Info.plist                 — Background Modes + URL scheme (bail://)
├── Assets.xcassets/           — App icon (gradient "b.")
├── Design/
│   ├── DesignTokens.swift     — colors, gradients, spacing, radii
│   └── DateFormatting.swift   — shared Date extensions
├── Models/
│   ├── User.swift
│   ├── Event.swift            — Event, EventSummary, BailThreshold, EventStatus
│   ├── EventGuest.swift
│   ├── LocationOption.swift   — LocationVotingStatus, LocationOption, LocationVoter
│   └── Vote.swift             — VoteChoice + CastVoteRequest (Encodable only)
├── Views/
│   ├── Splash/SplashView.swift          — single "Sign in with Apple" button
│   ├── Onboarding/OnboardingView.swift  — 3-screen swipeable tutorial, shown once
│   ├── Home/HomeView.swift + EventCard.swift
│   ├── CreateEvent/
│   │   ├── CreateEventView.swift        — 3-step flow with location mode toggle
│   │   └── LocationSearchField.swift    — reusable MapKit autocomplete component
│   ├── EventDetail/EventDetailView.swift
│   ├── LocationVote/LocationVoteView.swift — guests vote on venue (visible votes)
│   ├── Vote/VoteView.swift
│   └── Cancelled/CancelledView.swift
└── Services/
    ├── CloudKitService.swift      — CRUD, subscriptions, real-time sync, location votes
    ├── LocationSearchService.swift — MKLocalSearchCompleter wrapper for place autocomplete
    ├── ContactsService.swift      — phone contacts loader
    ├── MessageComposer.swift      — SMS invite composer (#if os(iOS))
    ├── NotificationService.swift  — local notification scheduling
    └── PhoneNumberUtils.swift     — phone number normalization
```

## Design Tokens (always use these, never hardcode colors)
- Background: #0A0A0A
- Surface: #141414
- Surface2: #1A1A1A
- Border: #2A2A2A
- AccentStart: #FF4458
- AccentEnd: #FF6B35
- Teal: #4ECDC4
- TextPrimary: #FFFFFF
- TextSecondary: #666666
- TextMuted: #444444
- Corner radius: 16–20pt
- Font: SF Pro Display (system default)

## Non-Negotiable Rules
1. Vote choices are NEVER returned by any API call — ever. Only aggregate bail_count is exposed.
2. The creator has NO special visibility into votes. Same view as everyone else.
3. Votes can be changed until the event starts or cancels (castVote upserts). Individual votes are never shown, before or after a change.
4. Auto-cancel message is always the same neutral template — never hints at how many bailed.
5. Use SwiftUI previews for every View file.
6. No force unwraps (!). Use guard let / if let.
7. All API calls are async/await, never callbacks.

## CloudKit Architecture
- **Public database** — all users can read events they're invited to
- **Record types**: BailEvent, BailGuest, BailVote, BailLocationOption, BailLocationVote
- **Local-first**: UI updates optimistically, syncs to CloudKit in background
- **Anonymity**: CloudKit stores individual bail votes for aggregation, but app only queries counts
- **Location votes are VISIBLE**: who voted for what is shown (not anonymous like bail votes)
- **Real-time**: CKQuerySubscription on BailVote → silent push → AppDelegate → fetchEvents()
- **Guest matching**: Phone numbers normalized via PhoneNumberUtils for cross-device matching
- **Deep links**: SMS includes `bail://event/<id>`, handled by .onOpenURL
- **isBailEvent**: when false, no voting UI shown, no auto-cancel — plain event mode

## CloudKitService Methods
- `setup()` — checks iCloud status, fetches userRecordID
- `createEvent(title:scheduledAt:location:threshold:isAnonymous:showBailOMeter:showVotingStatus:isBailEvent:locationVotingStatus:locationOptions:guests:)` 
- `castVote(eventId:choice:)` — wraps initial query in try-catch (schema may not exist on first vote)
- `castLocationVote(eventId:locationOptionId:voterDisplayName:)` — upserts location vote
- `resolveLocationVote(eventId:)` — picks winner, updates event location + status
- `fetchLocationOptions(eventRecordID:)` — fetches options + votes for an event
- `fetchEvents()` — fetches created + invited events, aggregates votes
- `addGuest(eventId:displayName:phoneNumber:avatarColor:)`
- `removeGuest(guestId:eventId:)`
- `deleteEvent(eventId:)` — cascades via .deleteSelf references
- `cancelEvent(eventId:)` — sets status to .cancelled
- `updateEventTitle(eventId:newTitle:)`
- `subscribeToVoteChanges()` — CKQuerySubscription, silent push

## Session / Auth Flow
- `@AppStorage("hasCompletedOnboarding")` — true after first "Sign in" tap
- `@AppStorage("hasSeenOnboarding")` — true after completing 3-screen tutorial
- Auto-skip splash only when BOTH are true (returning user)
- Sign out resets both to false → back to splash
- userName derived from UIDevice.current.name ("Joseph's iPhone" → "Joseph")

## Project Location
- Xcode project: `/Users/josephsacco/Documents/Bail/Bail.xcodeproj`
- Source files (write here): `/Users/josephsacco/Documents/Bail/Bail/`
- Always write Swift files to the source path above — never to a worktree

## Xcode Notes
- Xcode 26 beta with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (strict concurrency)
- PBXFileSystemSynchronizedRootGroup: files added to disk are auto-included in target
- Portrait lock via INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone in pbxproj
- Deployment target: iOS 26.0 (supports real device on 26.4.2)
- Real device: iPhone 16 Pro Max, iOS 26.4.2, Developer Mode enabled

## Current Status
[x] All 7 screens + Onboarding screen (splash, home, create, detail, vote, location vote, cancelled)
[x] Design tokens + shared date formatting
[x] Models with anonymity contract enforced in types
[x] CloudKit backend (events, guests, votes, cancel, edit title, location votes)
[x] Real-time vote sync via silent push
[x] Contacts integration + SMS invites with deep links
[x] Local notifications (reminders + cancellation alerts)
[x] Pull-to-refresh on Home
[x] App icon (light + dark variants)
[x] Portrait lock
[x] Profile tab (name, stats, sign out, report bug, request feature)
[x] Empty states (upcoming + past tabs)
[x] Skeleton loading cards with shimmer
[x] Delete events (long-press context menu)
[x] Contextual error messages
[x] Add/remove guests after creation (contacts picker, multi-select)
[x] Creator can cancel event or edit event name
[x] "Just an event" mode — isBailEvent toggle in create flow
[x] Vote button label: "Bail" (not "I'd Bail")
[x] Single "Sign in with Apple" button on splash
[x] 3-screen onboarding tutorial (shown once)
[x] Tested on real device (iPhone 16 Pro Max, iOS 26.4.2)
[x] Location autocomplete (MKLocalSearchCompleter) in create flow
[x] Location voting — creator adds 2+ places, guests vote, winner locks in
[x] Bail voting gated behind location resolution (location vote first)
[x] App Store review prompt after first invite send
[x] iMessage triggered after adding guests to existing events
[x] App Store submission package (metadata, GitHub Pages site, privacy manifest, screenshots)
[x] Renamed from "bail." to "bail.out" (App Store name, UI, emails)
[x] App Store LIVE since May 19, 2026 — https://apps.apple.com/app/bail-out/id6770131851 (1.0.5 published; 1.0.6 has critical invite-link fix: createEvent uses local event ID as CKRecord name)
[x] App Store copy reframed for Guideline 1.1 — subtitle "Group polls for plans"; never use "flake/drama/bail on plans" in metadata
[x] Splash button is "Get Started" (Apple flagged fake "Sign in with Apple")
[x] Notifications: dual CK subscriptions (vote + event changes), cancellation + location-resolved alerts on all devices, reminders for invited guests
[x] Age rating: 4+ (User-Generated Content declared)
[x] App Privacy published (Name, Phone Number, Other User Content, User ID — all App Functionality, not linked to identity, not tracked)
[x] Export compliance: None of the algorithms (OS-level encryption only via CloudKit/HTTPS)
[x] TARGETED_DEVICE_FAMILY = "1" (iPhone only)
[x] App icon alpha stripped (sips JPEG roundtrip)
[x] GitHub Pages live: https://saccojoseph.github.io/bail-out/

## Location Voting Architecture
- **Separate from bail voting** — location vote happens FIRST, is a prerequisite
- **Visible votes** — who voted for what is shown (unlike anonymous bail votes)
- **Flow**: Creator picks "Let Guests Vote" → adds 2+ places → guests see LocationVoteView → once all vote, winner resolves → bail voting unlocks
- **Auto-resolve**: when total location votes == guest count, winner is determined automatically
- **Creator override**: creator can resolve early via CloudKit (resolveLocationVote)
- **Models**: LocationVotingStatus (.disabled/.voting/.resolved), LocationOption, LocationVoter
- **Event fields**: locationVotingStatus, locationOptions, resolvedLocationId

## Next Steps
1. Wait for Apple review (typically 24–48 hours)
2. If approved → app goes live on App Store automatically (or manually release if "Manual Release" was selected)
3. Test on real device while waiting: location voting, CloudKit bail vote sync, SMS deep link, push notifications
4. If rejected → read Apple's notes, fix, resubmit from same version page

## Commands
- Build: Cmd+B in Xcode (or `xcodebuild -scheme Bail -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`)
- Run: Cmd+R in Xcode
- Test: Cmd+U in Xcode
