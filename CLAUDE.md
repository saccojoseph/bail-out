# bail. — iOS App

## What This Is
Social app where friend groups anonymously vote to cancel plans. If enough people bail, the event auto-cancels with a neutral canned message. Nobody ever knows who bailed.

## Tech Stack
- Swift 5.9+, SwiftUI (all UI), iOS 16 minimum
- Backend: Node.js + Express + PostgreSQL (separate repo, build iOS first)
- Auth: Sign in with Apple (required) 
- Push: APNs via UserNotifications framework
- No third-party UI libraries — pure SwiftUI only

## Project Structure
```
bail/
├── bail/
│   ├── App/
│   │   ├── bailApp.swift
│   │   └── ContentView.swift
│   ├── Models/
│   │   ├── User.swift
│   │   ├── Event.swift
│   │   ├── EventGuest.swift
│   │   └── Vote.swift
│   ├── Views/
│   │   ├── Splash/
│   │   ├── Home/
│   │   ├── CreateEvent/
│   │   ├── EventDetail/
│   │   ├── Vote/
│   │   └── Cancelled/
│   ├── ViewModels/
│   ├── Services/
│   │   ├── APIService.swift
│   │   └── NotificationService.swift
│   └── Design/
│       └── DesignTokens.swift
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

## Screens (build in this order)
1. Splash — brand intro, Get Started / Sign In
2. Home — plan cards with Bail-o-meter, bottom tab bar
3. CreateEvent — 3-step wizard (details → guests → bail rules)
4. EventDetail — guest list, aggregate bail count, vote CTA
5. Vote — I'm In / I'd Bail cards, post-vote confirmation
6. Cancelled — auto-cancel confirmation screen

## Project Location
- Xcode project: `/Users/josephsacco/Documents/Bail/Bail.xcodeproj`
- Source files (write here): `/Users/josephsacco/Documents/Bail/Bail/`
- Always write Swift files to the source path above — never to the worktree

## Xcode Notes
- After creating new folders on disk, manually add them in Xcode: right-click group → Add Files to "Bail" → check "Add to target: Bail"
- Portrait lock: set in Xcode → General → Deployment Info → uncheck Landscape. Do NOT use UIKit/AppDelegate for this.
- A `?` badge on a file means it's not in the target yet — fix via File Inspector → Target Membership

## Current Status
[x] Project scaffolded
[x] DesignTokens.swift created
[x] Models created (User, Event, EventGuest, Vote)
[x] Splash screen
[x] Home screen
[x] CreateEvent flow (3-step wizard)
[x] EventDetail screen
[ ] Vote screen
[ ] Cancelled screen
[ ] APIService (mock first, real later)
[ ] Push notifications

## Commands
- Build: Cmd+B in Xcode
- Run: Cmd+R in Xcode
- Test: Cmd+U in Xcode
- Simulator: iPhone 15 Pro (iOS 17)
