# bail. — iOS App

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
├── PreviewData.swift          — #if DEBUG sample data
├── Bail.entitlements          — CloudKit + push entitlements
├── Info.plist                 — Background Modes + URL scheme (bail://)
├── Assets.xcassets/           — App icon (gradient "b.")
├── Design/
│   ├── DesignTokens.swift     — colors, gradients, spacing, radii
│   └── DateFormatting.swift   — shared Date extensions
├── Models/
│   ├── User.swift
│   ├── Event.swift            — Event (+ isBailEvent field), EventSummary, BailThreshold, EventStatus
│   ├── EventGuest.swift
│   └── Vote.swift             — VoteChoice + CastVoteRequest (Encodable only)
├── Views/
│   ├── Splash/SplashView.swift          — single "Sign in with Apple" button
│   ├── Onboarding/OnboardingView.swift  — 3-screen swipeable tutorial, shown once
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
- **Record types**: BailEvent (has isBailEvent field), BailGuest, BailVote
- **Local-first**: UI updates optimistically, syncs to CloudKit in background
- **Anonymity**: CloudKit stores individual votes for aggregation, but app only queries counts
- **Real-time**: CKQuerySubscription on BailVote → silent push → AppDelegate → fetchEvents()
- **Guest matching**: Phone numbers normalized via PhoneNumberUtils for cross-device matching
- **Deep links**: SMS includes `bail://event/<id>`, handled by .onOpenURL
- **isBailEvent**: when false, no voting UI shown, no auto-cancel — plain event mode

## CloudKitService Methods
- `setup()` — checks iCloud status, fetches userRecordID
- `createEvent(title:scheduledAt:location:threshold:isAnonymous:showBailOMeter:showVotingStatus:isBailEvent:guests:)` 
- `castVote(eventId:choice:)` — wraps initial query in try-catch (schema may not exist on first vote)
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
[x] All 6 screens + Onboarding screen
[x] Design tokens + shared date formatting
[x] Models with anonymity contract enforced in types
[x] CloudKit backend (events, guests, votes, cancel, edit title)
[x] Real-time vote sync via silent push
[x] Contacts integration + SMS invites with deep links
[x] Local notifications (reminders + cancellation alerts)
[x] Pull-to-refresh on Home
[x] App icon (light + dark variants)
[x] Portrait lock
[x] Profile tab (name, stats, sign out)
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

## Next Steps
1. Verify vote CloudKit sync on real device (fixed try-catch, needs confirmation)
2. Test SMS invite + deep link end-to-end on real device
3. Test push notifications on real device
4. App Store prep (screenshots, description, privacy policy)

## Commands
- Build: Cmd+B in Xcode (or `xcodebuild -scheme Bail -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`)
- Run: Cmd+R in Xcode
- Test: Cmd+U in Xcode
