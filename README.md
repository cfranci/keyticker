# KeyTicker

A discreet macOS menu bar app that scrolls keyboard shortcuts for whatever app you're using across the bottom of your screen. The goal: passive exposure → muscle memory → fewer mouse trips.

Unlike on-demand overlays (CheatSheet, KeyCue, Kommand), KeyTicker is ambient. You don't have to ask for the shortcuts — they drift past while you work. Once you've learned one, check it off and it stops showing up.

## Features

- **Menu bar app.** No Dock icon. Runs as an accessory.
- **Context-aware.** Watches the frontmost app and swaps in shortcuts for it (Finder, Safari, Chrome, Xcode, VS Code, Slack, Mail, Terminal, Notes, Messages, Figma, plus macOS globals). Unknown apps fall back to globals.
- **Mark as learned, per app.** Open *Manage Shortcuts…* and tick the ones you already know. They're filtered out of the ticker.
- **Exclude apps entirely.** Don't want the ticker showing in your video calls or your editor? Toggle it off for that app.
- **Translucent.** 30%–100% opacity, your call.
- **Fades on mouse hover.** Move the cursor toward the bottom of the screen and the ticker fades out so it never blocks anything.
- **Adjustable scroll speed.** Slow / normal / fast.
- **All shortcuts are local JSON.** Want to add an app? PR a new entry to `Sources/KeyTicker/Resources/shortcuts.json`.

## Build & run

Requires Xcode 15 / Swift 5.9+ and macOS 13 or later.

```bash
git clone https://github.com/cfranci/keyticker
cd keyticker
swift run
```

That's it. The menu bar icon (⌘) appears in the top-right and the ticker shows up across the bottom of the screen.

To install permanently, build a release binary and copy it somewhere on your PATH or add it to your Login Items:

```bash
swift build -c release
cp .build/release/KeyTicker /usr/local/bin/keyticker
```

## Adding shortcuts for a new app

Find the app's bundle identifier:

```bash
osascript -e 'id of app "Notion"'
```

Then add an entry to `Sources/KeyTicker/Resources/shortcuts.json`:

```json
{
  "bundleID": "notion.id",
  "appName": "Notion",
  "shortcuts": [
    {"keys": "⌘ N", "action": "New page"},
    {"keys": "⌘ P", "action": "Quick find"}
  ]
}
```

Open a PR. Symbols you can use: `⌘ ⌥ ⌃ ⇧` plus letters, arrows (`← → ↑ ↓`), and named keys (`Space`, `Tab`, `Esc`, `Delete`, `F1`–`F12`).

## Why this exists

Most people know maybe 10% of the shortcuts available in the apps they use every day. The existing tools (CheatSheet, KeyCue) require you to interrupt your flow and pop up a cheat sheet — which you only do when you already suspect a shortcut exists. KeyTicker shows you shortcuts you didn't know to look for, in your peripheral vision, while you're working.

## Status

v0.1 — works on my machine. Expect rough edges. Issues and PRs welcome.

## License

MIT. See [LICENSE](LICENSE).
