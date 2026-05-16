# bail. — Setup Guide
## How to hand this off to Claude Code and start building

---

## Step 1 — Create the Xcode Project (you do this manually)

1. Open Xcode → File → New → Project
2. Choose **App** under iOS
3. Fill in:
   - Product Name: **bail**
   - Team: your Apple ID
   - Organization Identifier: com.yourname (e.g. com.joesmith)
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Uncheck "Include Tests" for now
4. Save it somewhere you'll remember (e.g. ~/Documents/bail)

---

## Step 2 — Drop These Files Into Your Project Folder

Copy the entire contents of this handoff package into the root of your Xcode project folder (same level as the .xcodeproj file):

```
bail/                     ← your Xcode project folder
├── bail.xcodeproj        ← Xcode creates this
├── bail/                 ← source files go here
├── CLAUDE.md             ← ✅ drop this here
├── OPENING_PROMPT.md     ← ✅ drop this here
├── SPEC.md               ← ✅ drop this here
└── mockup.jsx            ← ✅ drop this here
```

---

## Step 3 — Open Claude Code

In Terminal:
```bash
cd ~/Documents/bail        # navigate to your project
claude                     # launch Claude Code
```

Claude Code will automatically read CLAUDE.md on startup.

---

## Step 4 — Paste the Opening Prompt

Open OPENING_PROMPT.md, copy everything after the dashed line, and paste it as your first message. That's it — Claude Code takes it from there.

---

## Step 5 — How to Work With Claude Code Session to Session

Claude Code remembers things via CLAUDE.md. After each working session, ask Claude Code:

> "Update CLAUDE.md to mark off what we completed and note anything important about how we built it."

This keeps the memory fresh every session without you having to re-explain anything.

---

## Useful Claude Code Commands

| Command | What it does |
|---------|-------------|
| `claude` | Start a session |
| `/memory` | See what Claude has loaded and remembers |
| `/clear` | Clear conversation (keeps CLAUDE.md memory) |
| Ctrl+C | Stop current task |
| `claude --continue` | Resume last session |

---

## Tips

- **Work in small chunks.** Ask Claude Code to build one screen at a time, then review before moving on.
- **Use Xcode side by side.** Claude Code edits files on disk; Xcode shows you the live preview.
- **If something breaks,** paste the Xcode error directly into Claude Code — it'll fix it.
- **Don't skip the mock-first approach.** Ask Claude Code to use mock data before wiring up a real backend. It's faster to iterate.
