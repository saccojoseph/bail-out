# bail. — Full Technical Specification

## Data Models

### User
```swift
struct User: Codable, Identifiable {
    let id: UUID
    var name: String
    var phoneOrEmail: String
    var avatarColor: String  // hex string
    let createdAt: Date
}
```

### Event
```swift
struct Event: Codable, Identifiable {
    let id: UUID
    var title: String
    var dateTime: Date
    var location: String?
    let creatorId: UUID
    var thresholdType: ThresholdType
    var status: EventStatus
    let createdAt: Date
    
    enum ThresholdType: String, Codable {
        case all        // 100% must bail
        case majority   // >50% must bail
        case any        // 1 bail cancels it
    }
    
    enum EventStatus: String, Codable {
        case pending    // waiting for votes
        case active     // in progress
        case cancelled  // threshold reached
        case confirmed  // all voted in / time passed
    }
}
```

### EventGuest
```swift
struct EventGuest: Codable, Identifiable {
    let id: UUID
    let eventId: UUID
    let userId: UUID
    var invitedAt: Date
    var votedAt: Date?  // nil = hasn't voted. Direction NEVER stored client-side.
}
```

### EventSummary (what the API actually returns — never individual votes)
```swift
struct EventSummary: Codable {
    let eventId: UUID
    let totalGuests: Int
    let totalVoted: Int
    let bailCount: Int      // aggregate only
    let thresholdCount: Int // how many bails needed to cancel
    var hasCurrentUserVoted: Bool
}
```

### Vote (CLIENT NEVER RECEIVES THIS — server-only concept)
```swift
// NOTE: This type exists only for documentation.
// The iOS app NEVER receives, stores, or displays Vote objects.
// enum VoteChoice { case in_, bail }
```

---

## Bail Threshold Logic (server-side, documented for reference)

| Threshold | Cancel Condition | Example (5 guests) |
|-----------|-----------------|-------------------|
| all | bail_count == guest_count | All 5 must bail |
| majority | bail_count > guest_count / 2 | 3+ must bail |
| any | bail_count >= 1 | 1 bail cancels |

**Edge case:** If not everyone votes and the event datetime passes, server auto-confirms (treat non-votes as "in"). Prevents gaming by abstaining.

---

## API Endpoints

```
POST   /auth/apple              Sign in with Apple
GET    /users/me                Get current user profile

POST   /events                  Create event
GET    /events                  List user's events
GET    /events/:id              Get event detail (EventSummary, never votes)
DELETE /events/:id              Cancel event (creator only)

GET    /events/:id/guests       Guest list — shows voted/not voted, NOT direction
POST   /events/:id/vote         Cast vote { choice: "in" | "bail" } — write-once
```

**Critical API rule:** `GET /events/:id` returns `EventSummary`. It NEVER returns an array of vote choices. NEVER.

---

## Screen Specifications

### Screen 1 — Splash
- Full screen dark bg (#0A0A0A)
- Centered: door emoji in red-orange rounded rect (100×100pt, radius 28)
- App name "bail." — 42pt, weight 800, tracking -2
- Tagline "no pressure. no drama." — 16pt, #666
- "Get Started" button — full width, gradient fill, 18pt bold
- "Sign In" button — full width, #1A1A1A bg, #333 border

### Screen 2 — Home
- Header: greeting + user name, + button top right
- Segment control: Upcoming / Past
- ScrollView of EventCards
- Bottom TabBar: Home, Friends, Alerts, Profile (Home tab active = #FF4458)

**EventCard:**
- Background #141414, radius 20, border #222
- Title 17pt bold white, date/time 13pt #666
- Bail status badge (top right): red bg if bails > 0, teal if all in
- Stacked guest avatars (overlap -8pt)
- Bail-o-meter: label row (BAIL-O-METER | X of Y to cancel), 4pt height bar

### Screen 3 — Create Event (3 steps)
- 3-segment progress bar at top (fills red-orange per step)
- Step 1: Event name input, date/time input, location input (optional)
- Step 2: Friend picker — avatar + name rows, checkmark on select
- Step 3: Threshold picker (3 options as tappable cards), anonymity disclaimer card
- Continue/Send Invites button full width at bottom

### Screen 4 — Event Detail
- Event title 28pt weight 800, date/time/location below
- Guest list: avatar + name + "voted ✓" per row (checkmark = voted, no direction shown)
- Bail-o-meter card with exact count ("2 anonymous bails recorded")
- "Cast Your Vote" CTA button (gradient)
- Anonymity note below button

### Screen 5 — Vote
**Pre-vote:**
- Event name + time centered
- Two large tappable cards (min 80pt height each):
  - "🙌 I'm In" → teal gradient on select
  - "🚪 I'd Bail" → red-orange gradient on select
- Anonymity lock icon + text at bottom

**Post-vote:**
- Large emoji (🙌 or 🚪 based on choice)
- Confirmation message
- Current status card (still on / cancelled)
- Back to Plans button

### Screen 6 — Cancelled
- 💀 emoji large
- "It's dead." in #FF4458, 32pt bold
- Event name
- Explanation copy
- Quoted auto-message card (grey bg): "Hey, plans fell through for [day]. Maybe next time! 🤷"
- Back to Home button

---

## Push Notifications

| Trigger | Message |
|---------|---------|
| Invited to event | "[Name] added you to [Event] — [Day Time]. Vote now." |
| 24hr reminder (not voted) | "[Event] is tomorrow. You haven't voted yet." |
| Event cancelled | "Hey, plans fell through for [day]. Maybe next time! 🤷" |
| Event confirmed | "[Event] is on! Everyone's in. See you [day] 🎉" |

---

## MVP Scope

**In V1:**
- Sign in with Apple
- Create/view/vote on events
- Invite from contacts or by username
- Bail threshold (all / majority / any)
- Anonymous voting
- Bail-o-meter
- Auto-cancel + push notification
- 24hr vote reminder push

**NOT in V1:**
- Android
- Web
- Group chat / comments
- Event editing post-invite
- Recurring events
- Calendar sync
- Monetization
