# NitroBrew: Design

Status: draft for approval, 2026-11-25. Nothing has been built.
Reference prototype (throwaway, not product code): https://claude.ai/artifact/DokKrM15LQ9mHS6S6t4sFs

## Intent and why

NitroBrew is a macOS menu bar Pomodoro timer themed as nitro cold brew. It is a clean rebuild of an earlier personal timer (a single 50 KB `ContentView.swift`), keeping its feature ideas but not its code or its generic color-palette look. It is the follow-on to Triple Espresso (same author, same stack).

The central idea: **the timer is a vessel that fills with nitro brew as your work session progresses.** The vessel appears in the menu bar icon, the popover and the app window, and all three always show the same vessel at the same fill level. It should be satisfying to glance at.

## Goals

- A work session fills the vessel gradually from empty to full. A break drains it from full to empty.
- The user picks one of three vessels: **Pint glass**, **Nitro can**, **Pub glass** (nonic). The pick changes the menu bar icon and the animated vessel in the popover and window together.
- The foam head grows gradually with the fill level. It must never pop in. Settling and shrinking are also gradual.
- The menu bar icon is a single-color template image that fills with progress, with the remaining time beside it (the time display can be turned off).
- Clear end-of-session behavior (below).
- Clean structure: no file larger than one clear responsibility.

## Non-goals

- iOS, widgets, Live Activities. The old README described these but they never existed in the zip.
- Cloud sync, accounts, an in-app auto-updater, analytics.

## Versioning

Every update ships as a new release version. The app reflects it: the version and build are read from the bundle, shown in Settings and in an "About NitroBrew" menu item, and a release tag `vX.Y.Z` must match the built version and have a `CHANGELOG.md` entry, or the release job fails. Initial version `1.0.0`. **(author's requirement; the display and enforcement details are my call)**
- Multiple color palettes or a light/dark toggle (see calls below).

## Anti-goals (failure even if it technically works)

- The icon reads as an espresso or coffee cup (a mug, a saucer, steam).
- The foam or fill visibly jumps instead of changing smoothly.
- The timer drifts or stops when the Mac sleeps or the app is busy.
- Code copied from the old timer or from Caffeine. The repo is GPL-3; write fresh code.

## Constraints

- Swift only. SwiftUI plus AppKit (`NSStatusItem`, `NSPopover`, `NSHostingController`). No third-party dependencies.
- macOS 14.6+, matching Triple Espresso.
- Xcode project, same layout style as Triple Espresso (`src/NitroBrew.xcodeproj`, `src/NitroBrew/`).
- Icons and assets are generated or drawn in code, not hand-drawn bitmaps.

## Approaches considered

1. **Pure SwiftUI `MenuBarExtra`.** Least code. Weaker control: redrawing the menu bar icon every second is awkward and can look jumpy, and popover and right-click behavior is hard to customize.
2. **AppKit `NSStatusItem` + `NSPopover` hosting SwiftUI, plus a normal window.** More plumbing, but full control of the icon image, popover behavior and right-click menu. It is the pattern Triple Espresso already uses.

**Chosen: 2** (picked by the author). The icon is the heart of the app, and 2 gives the most control over it.

## Behavior

### Session flow

- **Modes:** Work 25, Work 50, Break 5, Break 10 (minutes).
- **Work session:** starts empty. A short **cascade** (dark swirls falling through the vessel, about 3 seconds) plays at the start of a fresh session, not on resume. Then the vessel fills evenly until time is up.
- **Work done:** vessel is full, the foam settles gradually, a soft two-note chime plays, a macOS notification says "Poured", and the popover offers **Start 5 min break**.
- **Break:** starts full and drains evenly. At empty: notification "Glass is empty" (wording follows the chosen vessel), and the popover offers **Start next pour**.
- **Break chosen directly** (without a prior work session) starts from a full vessel, as in the prototype.
- Controls: Start, Pause, Resume, Reset, mode chips.
- Auto-start options from the old timer are kept: auto-start break after work, auto-start work after break. Default off.

### Foam

- Thickness is a function of fill level: zero at empty, a full head by about 45% fill, smoothed each frame toward its target so it never jumps.
- After a work session completes, the head eases down to a settled thickness.
- During a break the head thins as the level drops.

### Menu bar

- Template icon of the selected vessel, filled to the current level, redrawn as time passes.
- Remaining time next to the icon (setting to hide it).
- Left click toggles the popover. Right click shows a small menu (Start/Pause, Reset, Open window, Settings, Quit).

### Popover and window

- Same view in both: mode chips, animated vessel, big time, status line, Start/Pause and Reset.
- Status line examples: "Empty glass. Ready to pour." / "Pouring, 42% full" / "Poured. Foam is settling." / "Draining, 30% left". Wording uses the chosen vessel's name where it reads better (glass, can).
- Settings (in the window or a popover sheet): vessel, auto-start options, alert sound, show time in menu bar, statistics.
- Look: black background, cream and amber accents, dark roast brew color, cream foam. Matches the prototype.

### Statistics and persistence (carried over from the old timer)

- Record completed and skipped sessions with mode and date. Show today's count, all-time work sessions, total work time, and the last 10 sessions. Export and clear.
- Persist the selected vessel, settings and the running timer's state. A running timer survives quitting the app by storing its end time.

## Decisions on how it gets made

Marked **(author)** if the author decided, **(my call)** if I chose it and the author has not seen it.

- Menu bar via `NSStatusItem` + `NSPopover` + a normal window. **(author)**
- One vector shape per vessel (SwiftUI `Shape` with a fill level). The animated vessel and the menu bar template image both come from the same shape, so there are no per-level image files. **(my call)**
- Timing is wall-clock based: store an end `Date` and compute remaining time from it. **(my call)**
- Suggested folders under `src/NitroBrew/`: `App` (app and status item controller), `Timer` (engine, modes, persistence), `Vessels` (shapes, icon renderer, foam and bubble animation), `Views` (popover, window, settings, statistics), `Resources`. **(my call)**
- Notifications via `UNUserNotificationCenter`; chime from system sounds, default a soft one. **(my call)**
- Dark look only, replacing the 8 palettes and the dark/light toggle. **(my call)**
- English only at first, but all user-facing strings go in a String Catalog so other languages can be added later (Triple Espresso has 13). **(my call)**
- Keep statistics and auto-start from the old timer. **(my call)**
- The app name is `NitroBrew` and the bundle identifier is `com.ir77io.nitrobrewtimer`. **(author)**

## Left to the builder

- Exact vessel path geometry for the pint, can and pub glass, tuned so each reads clearly at 18 px and the pub glass bulge is visible next to the pint.
- Particle and cascade tuning: counts, speeds, colors.
- Exact settled foam thickness and the easing constants.
- The notification and menu wording beyond the examples above.
- App icon: a generated image (script in `scripts/`, like Triple Espresso). It must not look like a coffee cup or mug.
- How to verify without a test target: the prototype's behaviors are the reference. Pure logic (level and foam as functions of time and mode, end-time handling) should have unit tests once a test target exists.
