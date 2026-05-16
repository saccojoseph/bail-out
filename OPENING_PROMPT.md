# Opening Prompt for Claude Code
# Copy everything below this line and paste it as your first message in Claude Code

---

I'm building an iOS app called **bail.** — read CLAUDE.md for full context. It's already in this project folder.

Please start by doing the following in order:

1. Read CLAUDE.md fully before writing any code
2. Create the Xcode project structure (folders, not the .xcodeproj — I'll create that manually in Xcode first and then you scaffold inside it)
3. Create `Design/DesignTokens.swift` with all colors, gradients, and spacing as SwiftUI-compatible constants
4. Create all 4 model files in `Models/` — User, Event, EventGuest, Vote — with the anonymity constraint baked in (Vote model has no API-facing initializer)
5. Build the Splash screen in `Views/Splash/SplashView.swift` with a SwiftUI preview
6. Then stop and show me what you've built before continuing

**Anonymity rule to enforce in code:** The `Vote` model must only ever be created server-side. On the client, we only ever work with `EventSummary` which contains `bailCount: Int` and `totalVotes: Int` — never individual vote records.

**Visual reference:** There is a `mockup.jsx` file in this folder showing all 6 screens. Use it as the design source of truth for layout, colors, and component structure. Translate it faithfully to SwiftUI.

Ask me before installing any dependencies or pods.
