# bail.out — App Store Listing

Everything you need to copy-paste into App Store Connect.

---

## App Information

**Name** (30 char max)
```
bail.out
```

**Subtitle** (30 char max)
```
Bail on plans, drama-free
```

**Primary Category**: Social Networking
**Secondary Category**: Lifestyle

**Bundle ID**: `com.josephsacco.bail-app`

---

## Promotional Text (170 char max — can change anytime without review)
```
Make plans. Vote in secret. If enough friends bail, the plan auto-cancels — and nobody knows who pulled the plug. No drama, no awkward texts.
```

---

## Description (4000 char max)

```
bail.out is the easiest way to flake on plans without being the bad guy.

Make a plan. Invite your crew. Everyone votes — anonymously — whether to stay in or bail.out If enough people bail, the plan auto-cancels and a neutral text goes out. Nobody ever knows who voted what. Not even you. Not even the creator.

— HOW IT WORKS —

1. CREATE A PLAN
   Pick a date, place, and the friends you want there. Send invites by text.

2. VOTE IN SECRET
   Everyone privately taps "I'm In" or "Bail." Votes are encrypted and never shown — only the count.

3. BAIL WITHOUT THE DRAMA
   You decide the rules: any one bail, a majority, or everyone has to agree. When the threshold hits, the plan auto-cancels with a neutral group text. No blame. No "who was it?"

— WHY PEOPLE LOVE IT —

• Truly anonymous. Apple iCloud handles auth — bail.out never stores names against votes.
• Plain-event mode. Not every plan needs voting. Toggle it off and bail.out works as a clean group event tracker.
• No accounts, no passwords. Sign in with Apple. That's it.
• iMessage-native invites. Friends get a tap-to-open link. They don't need the app to RSVP — but they will once they see it.
• Real-time. The bail-o-meter updates live as votes come in.

— PRIVACY FIRST —

We built bail.out around one rule: nobody ever sees who voted. Votes are aggregated into a count and that's all the app — or anyone — can read. No analytics SDKs. No tracking. No ads. Your contacts never leave your device.

Make plans. Bail with grace. Stay friends.
```

---

## Keywords (100 char max, comma-separated, no spaces after commas)

```
plans,cancel,bail,group,event,vote,anonymous,friends,rsvp,social,flake,hangout
```

---

## What's New in This Version (4000 char max — for version 1.0.0)

```
Welcome to bail.out — the drama-free way to cancel plans.
```

---

## Support & Marketing URLs

**Support URL**: `https://josephsacco.github.io/bail-app/support.html`
**Marketing URL** (optional): `https://josephsacco.github.io/bail-app/`
**Privacy Policy URL**: `https://josephsacco.github.io/bail-app/privacy.html`

> Replace `josephsacco` with your actual GitHub username if different. These pages live in the `bail-app/docs/` folder of this repo.

---

## Age Rating Questionnaire

When App Store Connect asks, answer:

- Cartoon or Fantasy Violence: **None**
- Realistic Violence: **None**
- Sexual Content or Nudity: **None**
- Profanity or Crude Humor: **None**
- Alcohol, Tobacco, or Drug Use or References: **None**
- Mature/Suggestive Themes: **None**
- Horror/Fear Themes: **None**
- Medical/Treatment Information: **None**
- Gambling: **None**
- Contests: **None**
- Unrestricted Web Access: **No**
- User-Generated Content (UGC): **Yes — Infrequent/Mild** (event names are user-typed)
- Social Networking Features: **Yes**

Result: **Rated 12+** (likely) or **4+**. UGC pushes it to 12+ by default.

---

## App Privacy ("Data Collection")

In App Store Connect → App Privacy, declare the following:

### Data Linked to You
- **Identifiers → User ID** (iCloud ID, used for auth)
- **Contacts → Name** (event guests pulled from local contacts — but not uploaded; phones are normalized and hashed-ish for matching)

### Data NOT Collected
Everything else.

### Tracking
- We do NOT track users across apps or websites.

### Use of Data
- Identifiers → App Functionality (linking events to creator/invitees)
- Contacts → App Functionality (sending SMS invites)

> Note: Phone numbers ARE stored in CloudKit for guest matching across devices. Declare under "Contact Info → Phone Number" if Apple asks — purpose: App Functionality, linked to user.

---

## Notes for Reviewer (App Review)

```
Thanks for reviewing bail.out

WHAT IT IS:
A group-plans app where friends anonymously vote whether to keep or cancel a plan. If enough people bail, the plan auto-cancels with a neutral message. The core design promise is that nobody — not even the event creator — can see who voted what.

HOW TO TEST:
1. Sign in with Apple on the splash screen (uses iCloud automatically).
2. Complete the 3-screen onboarding tutorial.
3. Tap the "+" button to create a plan. Pick a title, date, and a few contacts.
4. On the bail rules screen, leave "Enable bail voting" ON.
5. Tap "Send Invites" — iMessage will open with a pre-filled message and a bail:// deep link.

(If you're testing without contacts permission, just skip the invite step — the event will save without guests and you can still see the full event UI.)

PERMISSIONS:
- Contacts: only used to populate the invite picker. We do not upload your contacts. Phone numbers of selected invitees are stored in CloudKit so they can be matched when those invitees open the app.
- Notifications: local reminders before events + alerts when a plan is cancelled. Silent remote pushes via CloudKit subscriptions are used to keep vote counts live across devices.
- iCloud: authentication and event storage (public CloudKit database in the iCloud.com.sacco.bail-app container).

ANONYMITY MODEL:
Votes are stored in a separate CloudKit record type (BailVote) tied to the event but the app never queries individual votes — only the aggregate count. The creator has the exact same view as every other guest. There is no admin mode.

If you'd like a demo account or sample data, please reach out — happy to provide.

Contact: bail.outapp.official@gmail.com
```

---

## Demo Account (App Review)

Apple sometimes wants a demo account. Since bail.out uses Sign in with Apple via iCloud, **you don't need to provide one** — the reviewer's own iCloud handles it. Check the box that says **"Sign-in not required"** OR **"This app uses Sign in with Apple"** in App Store Connect.

---

## Export Compliance

When asked about encryption:
- Does your app use encryption? **Yes**
- Does it qualify for exemption? **Yes** — only uses HTTPS / Apple-provided encryption (CloudKit) for standard data transit. No custom crypto.

This means you DON'T need an ERN (Encryption Registration Number). Just self-certify in App Store Connect.

---

## Version & Build

- **Version**: 1.0.0
- **Build**: 1
- **Copyright**: © 2026 Joseph Sacco

---

## Pricing & Availability

- **Price**: Free
- **Availability**: All countries (or start with US-only if you want a soft launch)

---

## Screenshots

See the `Screenshots/` folder in the project root.
Upload these to App Store Connect → App Store tab → 6.9" Display screenshots section.

Required: minimum 3, maximum 10. We're providing 5.
```
