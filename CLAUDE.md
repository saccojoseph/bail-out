# bail. — iOS App

## What This Is
Social app where friend groups anonymously vote to cancel plans. If enough people bail, the event auto-cancels with a neutral canned message. Nobody ever knows who bailed.

## Tech Stack
- Swift 5.9+, SwiftUI (all UI), Xcode 26 beta
- Backend: CloudKit (public database, iCloud.com.sacco.bail-app container)
- Auth: iCloud automatic (no sign-in screen — every iPhone user is authenticated)
- Push: Silent push via CKSubscription for real-time vote sync
- Local notifications: UNUserNotificationCenter
- Contacts: CNContactStore + MFMessageComposeViewController for SMS invites
- No third-party UI libraries — pure SwiftUI only
- Bundle ID: com.josephsacco.bail-app

## Project Structure
```
Bail/
├── BailApp.swift              — @main entry + AppDelegate for push
├── ContentView.swift          — screen routing, CloudKit state, deep links
├── PreviewData.swift          — #if DEBUG sample data
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
│   └── Vote.swift             — VoteChoice + CastVoteRequest (Encodable only)
├── Views/
│   ├── Splash/SplashView.swift
│   ├── Home/HomeView.swift + EventCard.swift
│   ├── CreateEvent/CreateEventView.swift
│   ├── EventDetail/EventDetailView.swift
│   ├── Vote/VoteView.swift
│   └── Cancelled/CancelledView.swift
└── Services/
    ├── CloudKitService.swift      — CRUD, subscriptions, real-time sync
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
3. Votes are write-once. No editing, no deleting.
4. Auto-cancel message is always the same neutral template — never hints at how many bailed.
5. Use SwiftUI previews for every View file.
6. No force unwraps (!). Use guard let / if let.
7. All API calls are async/await, never callbacks.

## CloudKit Architecture
- **Public database** — all users can read events they're invited to
- **Record types**: BailEvent, BailGuest, BailVote (auto-created in Development environment)
- **Local-first**: UI updates optimistically, syncs to CloudKit in background
- **Anonymity**: CloudKit stores individual votes for aggregation, but app only queries counts
- **Real-time**: CKQuerySubscription on BailVote → silent push → AppDelegate → fetchEvents()
- **Guest matching**: Phone numbers normalized via PhoneNumberUtils for cross-device matching
- **Deep links**: SMS includes `bail://event/<id>`, handled by .onOpenURL

## Project Location
- Xcode project: `/Users/josephsacco/Documents/Bail/Bail.xcodeproj`
- Source files (write here): `/Users/josephsacco/Documents/Bail/Bail/`
- Always write Swift files to the source path above — never to a worktree

## Xcode Notes
- Xcode 26 beta with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (strict concurrency)
- PBXFileSystemSynchronizedRootGroup: files added to disk are auto-included in target
- Portrait lock via INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone in pbxproj
- Simulators: iPhone 17 series (iOS 26.5)
- No physical device registered yet — simulator-only development

## Current Status
[x] All 6 screens built (Splash, Home, CreateEvent, EventDetail, Vote, Cancelled)
[x] Design tokens + shared date formatting
[x] Models with anonymity contract enforced in types
[x] CloudKit backend (events, guests, votes)
[x] Real-time vote sync via silent push
[x] Contacts integration + SMS invites with deep links
[x] Local notifications (reminders + cancellation alerts)
[x] Pull-to-refresh on Home
[x] App icon (light + dark variants)
[x] Portrait lock

## Next Steps
1. Test on real device (CloudKit, contacts, SMS, push need real iPhone)
2. Profile tab (show user's name, event count — currently placeholder)
3. Empty states (friendly message when no events)
4. Delete/archive events (swipe-to-delete or button)
5. Loading states (skeleton cards while CloudKit fetches)
6. Error handling polish (contextual errors instead of generic alerts)

## Commands
- Build: Cmd+B in Xcode (or `xcodebuild -scheme Bail -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`)
- Run: Cmd+R in Xcode
- Test: Cmd+U in Xcode
