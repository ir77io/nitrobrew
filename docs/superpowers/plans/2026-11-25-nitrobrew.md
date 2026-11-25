# NitroBrew Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build NitroBrew, a macOS menu bar Pomodoro timer where a nitro brew vessel (pint, can or pub glass) fills during work and drains during breaks, in the menu bar icon, popover and window.

**Architecture:** AppKit `NSStatusItem` + `NSPopover` hosting SwiftUI, plus a normal window. All timing and look logic is pure Swift (engine, foam, messages, stats) so it is unit-tested; views and the status item are thin. One vector definition per vessel feeds both the animated SwiftUI view and the menu bar template image.

**Tech Stack:** Swift, SwiftUI, AppKit, UserNotifications, XCTest. XcodeGen (`project.yml`) generates the Xcode project; it is a developer tool only, not an app dependency.

**Spec:** `docs/superpowers/specs/2026-11-25-nitrobrew-design.md`. Reference look and motion: https://claude.ai/artifact/DokKrM15LQ9mHS6S6t4sFs (throwaway prototype; match its behavior, do not copy it).

## Global Constraints

- Swift only; SwiftUI plus AppKit (`NSStatusItem`, `NSPopover`, `NSHostingController`); no third-party dependencies in the app.
- macOS 14.6+. Bundle identifier `com.ir77io.nitrobrewtimer`. App name `NitroBrew`.
- Layout: `src/NitroBrew.xcodeproj`, `src/NitroBrew/{App,Timer,Vessels,Views,Resources}`, tests in `src/NitroBrewTests`.
- Modes: Work 25, Work 50, Break 5, Break 10 minutes. Auto-start breaks and auto-start work default **off**.
- Vessels: `pint`, `can`, `pub` (nonic, bulged lip). Never a mug, saucer or steam.
- Timing is wall-clock: store an end `Date`; never count ticks.
- Foam thickness never jumps: zero at empty, full head by 45% fill, eased every frame.
- Dark look only (black background, cream and amber accents). No palettes, no light/dark toggle.
- All user-facing strings live in a String Catalog (`Localizable.xcstrings`); English only for now.
- Every update is a new release version. `MARKETING_VERSION` in `project.yml` is the single source of truth; the app reads it from the bundle (`CFBundleShortVersionString`, build from `CFBundleVersion`), shows it in the app, and a release tag `vX.Y.Z` must equal it. Each version gets a `CHANGELOG.md` entry. Initial version `1.0.0`.
- Write fresh code. Do not copy from the old timer or from Caffeine (repo is GPL-3).
- Commit messages end with: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.
- Test command: `xcodebuild test -project src/NitroBrew.xcodeproj -scheme NitroBrew -destination "platform=macOS"`.

## Review Focus

1. **Relaunch after the end time passed:** app quit mid-session, reopened after the end date. Expect the session to complete exactly once (one stats record, one notification), not repeat, and not show a stale running timer. (Task 1, Task 8)
2. **Pause then resume, and Mac sleep:** remaining time stays correct across pause and across a clock jump; resuming never replays the cascade. (Task 1, Task 3)
3. **Switching mode or pressing Reset mid-session:** the session is discarded, nothing is recorded as completed, the vessel returns to the right starting level. (Task 1, Task 6)
4. **Notification permission denied or unavailable:** the app still works and the chime still plays. (Task 5)
5. **Level 0, level 1, and out-of-range values:** foam and icon render without NaN, blank or crash; level is clamped to 0...1. (Task 2, Task 3)

---

### Task 0: Project scaffold

**Files:**
- Create: `project.yml`, `.gitignore`, `CLAUDE.md`, `src/NitroBrew/App/NitroBrewApp.swift`, `src/NitroBrew/App/AppDelegate.swift`, `src/NitroBrew/Resources/Info.plist`, `src/NitroBrew/Resources/Localizable.xcstrings`, `src/NitroBrewTests/SmokeTests.swift`
- Generated and committed: `src/NitroBrew.xcodeproj`

**Interfaces:**
- Produces: a building app target `NitroBrew` (scheme `NitroBrew`) and a test target `NitroBrewTests` hosted by it, both buildable with the Global Constraints test command. `AppDelegate: NSObject, NSApplicationDelegate` with `NSApp.setActivationPolicy(.accessory)` at launch.

- [ ] **Step 1:** `git checkout -b build-nitrobrew`.
- [ ] **Step 2:** Write `project.yml` (XcodeGen): app target `NitroBrew` (sources `src/NitroBrew`), test target `NitroBrewTests` (sources `src/NitroBrewTests`, `TEST_HOST` the app, `@testable` enabled), bundle id `com.ir77io.nitrobrewtimer`, deployment target 14.6, `LSUIElement` true in Info.plist, `NSHumanReadableCopyright` "© 2026 ir77io", project output `src/NitroBrew.xcodeproj`.
- [ ] **Step 3:** Write `NitroBrewApp` (`@main struct NitroBrewApp: App` with `@NSApplicationDelegateAdaptor(AppDelegate.self)` and an empty `Settings { EmptyView() }` scene) and `AppDelegate`.
- [ ] **Step 4:** Write `SmokeTests.testAppModuleLoads` asserting `Bundle.main.bundleIdentifier == "com.ir77io.nitrobrewtimer"`.
- [ ] **Step 5:** Run `xcodegen generate`, then the test command. Expected: build succeeds, 1 test passes.
- [ ] **Step 6:** Write `CLAUDE.md` (project overview, tech stack, build and test commands, "regenerate project with `xcodegen generate` after adding files"), a Swift `.gitignore` (DerivedData, xcuserdata, `.build`).
- [ ] **Step 7:** Commit: `git add -A && git commit -m "chore: scaffold NitroBrew project"`.

### Task 1: Session engine

**Files:**
- Create: `src/NitroBrew/Timer/SessionMode.swift`, `src/NitroBrew/Timer/SessionEngine.swift`
- Test: `src/NitroBrewTests/SessionEngineTests.swift`

**Interfaces:**
- Produces:
  - `enum SessionMode: String, CaseIterable, Codable { case work25, work50, break5, break10; var duration: TimeInterval; var minutes: Int; var isWork: Bool }`
  - `enum SessionPhase: String, Codable { case idle, running, paused, done }`
  - `struct EngineSnapshot: Codable, Equatable { var mode: SessionMode; var phase: SessionPhase; var endDate: Date?; var pausedRemaining: TimeInterval? }`
  - `@MainActor final class SessionEngine: ObservableObject` with `init(clock: @escaping () -> Date = Date.init)`; `@Published private(set) var mode: SessionMode`, `phase: SessionPhase`, `completedAt: Date?`, `cascadeStart: Date?`; `var remaining: TimeInterval`; `var fillLevel: Double` (work: 0 to 1 rising; break: 1 to 0 falling; clamped 0...1); `func select(_ mode: SessionMode)`, `start()`, `pause()`, `reset()`; `@discardableResult func tick() -> SessionMode?` (returns the mode once, the first tick at or after the end date); `var onComplete: ((SessionMode) -> Void)?`; `func snapshot() -> EngineSnapshot`; `func restore(_ s: EngineSnapshot)`.
  - `start()` on a fresh work session (phase idle) sets `cascadeStart = clock()`; resuming from paused does not. A break starts at fill level 1.

- [ ] **Step 1:** Write failing tests with a controllable clock (a `var now = Date(timeIntervalSince1970: 1000)` captured by the clock closure):
  - `testWorkLevelRisesLinearly`: after start, advance 750 s of 1500 → `fillLevel == 0.5`, `remaining == 750`.
  - `testBreakLevelStartsFullAndDrains`: select `.break5`, level is 1 at idle; after 150 s level is 0.5.
  - `testTickCompletesOnceAndFiresOnComplete`: advance past end; first `tick()` returns `.work25` and sets phase `.done`; second `tick()` returns nil; callback fired exactly once.
  - `testPauseFreezesRemaining`: pause at 600 s, advance 10 minutes, `remaining == 900`; resume, advance 100, `remaining == 800`.
  - `testResumeDoesNotRestartCascade`: `cascadeStart` unchanged after pause and resume.
  - `testSelectOrResetMidSessionDiscards`: after select(.break5) or reset(), phase `.idle`, `tick()` returns nil, `onComplete` not called.
  - `testClampsLevel`: advance 10× the duration without ticking → `fillLevel == 1.0`, never above.
  - `testRestoreAfterEndDateCompletesOnce`: snapshot a running session, create a new engine with the clock past `endDate`, `restore`, `tick()` returns the mode once and then nil.
  - `testRestoreRunningBeforeEndKeepsRunning`: `restore` with `endDate` in the future → phase `.running`, correct `remaining`.
- [ ] **Step 2:** Run the engine tests. Expected: FAIL (types undefined).
- [ ] **Step 3:** Implement `SessionMode` and `SessionEngine` as specified. Remaining time is always `endDate - clock()` while running, `pausedRemaining` while paused. Drive no timers inside the engine; callers call `tick()`.
- [ ] **Step 4:** Run tests. Expected: all pass.
- [ ] **Step 5:** Commit: `feat: session engine with wall-clock timing`.

### Task 2: Foam model

**Files:**
- Create: `src/NitroBrew/Vessels/FoamModel.swift`
- Test: `src/NitroBrewTests/FoamModelTests.swift`

**Interfaces:**
- Consumes: `SessionMode`, `SessionPhase` from Task 1.
- Produces: `struct FoamModel { private(set) var thickness: Double; static func target(level: Double, mode: SessionMode, phase: SessionPhase, secondsSinceDone: TimeInterval?) -> Double; mutating func update(level: Double, mode: SessionMode, phase: SessionPhase, secondsSinceDone: TimeInterval?, dt: TimeInterval) }`. Units are viewBox units of the 290-high vessel space (same as the prototype).
- Target values (from the spec and prototype): `k = smoothstep(min(1, level / 0.45))`; work running or paused `20 * k`; work done `(secondsSinceDone ≥ 2.5 ? 13 : 22) * k`; break `(10 + 8 * level) * k`. Easing: `thickness += (target - thickness) * (1 - pow(1 - 0.04, dt * 60))`.

- [ ] **Step 1:** Write failing tests: `testZeroAtEmpty` (target 0 at level 0 for every mode and phase), `testFullHeadByFortyFivePercent` (work running target at 0.45 == 20, at 1.0 == 20), `testNeverJumps` (feeding levels 0 to 1 in 1/60 s steps, no frame-to-frame thickness change above 0.5), `testSettlesAfterDone` (done: 22 × k before 2.5 s, 13 × k after), `testBreakThinsAsLevelDrops`, `testClampsAndNoNaN` (levels -1, 0, 1, 5, `dt` 0 and 10 produce finite values in 0...30).
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement `FoamModel` per the interface. Clamp `level` to 0...1 first.
- [ ] **Step 4:** Run tests. Expected: PASS.
- [ ] **Step 5:** Commit: `feat: foam model with gradual thickness`.

### Task 3: Vessels, icon renderer and animated view

**Files:**
- Create: `src/NitroBrew/Vessels/Vessel.swift`, `src/NitroBrew/Vessels/MenuBarIconRenderer.swift`, `src/NitroBrew/Vessels/CascadeModel.swift`, `src/NitroBrew/Vessels/VesselView.swift`
- Test: `src/NitroBrewTests/VesselTests.swift`

**Interfaces:**
- Consumes: `SessionEngine` (`fillLevel`, `mode`, `phase`, `cascadeStart`, `completedAt`), `FoamModel`.
- Produces:
  - `enum Vessel: String, CaseIterable, Codable, Identifiable { case pint, can, pub; var displayName: String; var noun: String }` (`noun`: "glass" for pint and pub, "can" for can).
  - `struct VesselGeometry { let outline: CGPath; let inner: CGPath; let liquidTop: CGFloat; let liquidHeight: CGFloat }` in a 24×24 coordinate space, with `static func geometry(for: Vessel) -> VesselGeometry`. Use the prototype's values: pint `outline M5.5 3h13l-1.6 17.2q-.1 1-1.1 1H8.2q-1 0-1.1-1z`, `inner M6.3 4h11.4l-1.5 16H7.8z`, top 20, height 15, foam caps; can `outline M8 3.5Q8 2.5 9 2.5h6q1 0 1 1V20q0 1.5-1.5 1.5h-5Q8 21.5 8 20z`, `inner M8.8 3.5h6.4V20.3h-6.4z`, top 20, height 16, plus a small widget circle at (12, 17); pub `outline M6 3h12l.4 2.8q.1 1.2-.6 1.8L16.9 20.2q-.1 1-1.1 1H8.2q-1 0-1.1-1L6.2 7.6Q5.5 7 5.6 5.8z`, `inner M6.8 4h10.4l.3 1.8-.4.9L16 20.2H8L6.9 6.7l-.4-.9z`, top 20, height 15, foam caps. Tune if the pub bulge is not visible next to the pint at 18 px (spec's builder call).
  - `enum MenuBarIconRenderer { static func image(vessel: Vessel, level: Double, pointSize: CGFloat = 18) -> NSImage }` returns a template image (`isTemplate == true`), outline stroked, liquid filled to `level` (clamped), foam bumps drawn at about 55% opacity when `level > 0.04` for pint and pub.
  - `struct CascadeModel { static let duration: TimeInterval = 3; static func strength(now: Date, start: Date?) -> Double }` returns 1 at start, easing to 0 at 3 s, 0 when `start` is nil.
  - `struct VesselView: View { init(vessel: Vessel, engine: SessionEngine) }` renders the large animated vessel (liquid gradient, foam path from `FoamModel`, rising bubbles, falling amber streaks scaled by `CascadeModel.strength`) using `TimelineView(.animation)` and `Canvas`.

- [ ] **Step 1:** Write failing tests: `testIconIsTemplateAndSized` (each vessel, 18 pt, `isTemplate`), `testIconChangesWithLevel` (bitmap data at 0, 0.5 and 1 all differ, for every vessel), `testVesselsLookDifferent` (bitmaps at level 0.5 differ pairwise), `testLevelClampedAndSafe` (levels -1, 0, 1, 2 render non-empty images without crash), `testCascadeStrength` (1 at t0, 0 at t0+3 and later, nil start → 0, strictly non-increasing).
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement `Vessel`, `VesselGeometry` (parse the path strings with a tiny SVG-path-to-`CGPath` helper or build paths directly, whichever is smaller), `MenuBarIconRenderer`, `CascadeModel`.
- [ ] **Step 4:** Implement `VesselView`. Verify by eye later in Task 9; no automated assertion beyond building.
- [ ] **Step 5:** Run tests. Expected: PASS.
- [ ] **Step 6:** Commit: `feat: vessels, menu bar icon renderer and animated view`.

### Task 4: Settings and statistics

**Files:**
- Create: `src/NitroBrew/Timer/Settings.swift`, `src/NitroBrew/Timer/StatsStore.swift`
- Test: `src/NitroBrewTests/SettingsTests.swift`, `src/NitroBrewTests/StatsStoreTests.swift`

**Interfaces:**
- Consumes: `Vessel`, `SessionMode`.
- Produces:
  - `enum AlertSound: String, CaseIterable, Codable { case softChime, glass, hero, ping, pop, purr, submarine, none; var systemSoundName: String? }`
  - `@MainActor final class AppSettings: ObservableObject` with `init(defaults: UserDefaults = .standard)` and persisted `@Published` properties `vessel: Vessel = .pint`, `autoStartBreaks = false`, `autoStartWork = false`, `alertSound: AlertSound = .softChime`, `showTimeInMenuBar = true`. Each change writes to `defaults` immediately.
  - `struct SessionRecord: Codable, Identifiable, Equatable { let id: UUID; let mode: SessionMode; let date: Date; let completed: Bool }`
  - `@MainActor final class StatsStore: ObservableObject` with `init(fileURL: URL)`; `@Published private(set) var records: [SessionRecord]`; `func add(_ r: SessionRecord)`; `var todayCount(calendar:now:) -> Int`; `var totalWorkSessions: Int` and `totalWorkTime: TimeInterval` (completed work only); `var recent: [SessionRecord]` (last 10, newest first); `func exportCSV() -> String`; `func clear()`. Persists as JSON at `fileURL`; a missing or corrupt file yields an empty store without crashing.

- [ ] **Step 1:** Write failing tests: settings defaults (vessel `.pint`, both auto-start flags false, `showTimeInMenuBar` true), `testSettingsPersistAcrossInstances` (use `UserDefaults(suiteName:)` with a unique name), stats `testCountsOnlyCompletedWorkInTotals`, `testTodayCountUsesCalendarDay`, `testRecentIsLast10NewestFirst`, `testPersistsAndReloads`, `testCorruptFileGivesEmptyStore`, `testExportCSVHasHeaderAndRows`, `testClear`.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement both types. Use `JSONEncoder` with ISO 8601 dates; write atomically.
- [ ] **Step 4:** Run tests. Expected: PASS.
- [ ] **Step 5:** Commit: `feat: settings and session statistics`.

### Task 5: Messages, status text, notifier and sound

**Files:**
- Create: `src/NitroBrew/Timer/Messages.swift`, `src/NitroBrew/Timer/Notifier.swift`
- Test: `src/NitroBrewTests/MessagesTests.swift`, `src/NitroBrewTests/NotifierTests.swift`

**Interfaces:**
- Consumes: `SessionMode`, `SessionPhase`, `Vessel`, `AlertSound`.
- Produces:
  - `struct CompletionMessage: Equatable { let title: String; let body: String; let actionTitle: String }` and `static func make(finished: SessionMode, vessel: Vessel) -> CompletionMessage`. Finished work: title "Poured", body "Your {n} minute pour is ready. Take a {next} minute break.", action "Start {next} min break" (next is 5 after Work 25, 10 after Work 50). Finished break: title "{Glass|Can} is empty" (vessel noun capitalized), body "Break is over. Ready for the next pour?", action "Start next pour".
  - `enum StatusText { static func make(mode: SessionMode, phase: SessionPhase, level: Double, vessel: Vessel) -> String }`. Examples: idle work "Empty glass. Ready to pour."; idle break "Full glass. Ready to drain."; running work "Pouring, 42% full"; running break "Draining, 30% left"; paused "Paused"; done work "Poured. Foam is settling."; done break "{Glass|Can} is empty." (can uses "can" wherever the example says "glass").
  - `protocol Notifying { func requestAuthorization() async; func notify(_ message: CompletionMessage) }`; `final class UserNotifier: Notifying` (uses `UNUserNotificationCenter`); `protocol SoundPlaying { func play(_ sound: AlertSound) }`; `final class SystemSoundPlayer: SoundPlaying` (`NSSound(named:)`; `.softChime` synthesizes a two-note chime at 660 and 880 Hz with `AVAudioEngine`, or uses a bundled short sound if synthesis is awkward).

- [ ] **Step 1:** Write failing tests for `CompletionMessage` (all four finished modes, each vessel noun) and `StatusText` (every example above, including the can variants and percent rounding at 0.416 → "42% full"). Write `testDeniedAuthorizationDoesNotPreventSound` using a fake `Notifying` that fails and a fake `SoundPlaying`, via a small `CompletionHandler` helper or the coordinator seam in Task 8; if that seam does not exist yet, leave this test for Task 8 and note it there.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement `CompletionMessage`, `StatusText`, and the notifier and sound classes. Put all strings through `String(localized:)`.
- [ ] **Step 4:** Run tests. Expected: PASS.
- [ ] **Step 5:** Commit: `feat: completion messages, status text, notifications and sound`.

### Task 6: Views

**Files:**
- Create: `src/NitroBrew/Views/TimerView.swift`, `src/NitroBrew/Views/SettingsView.swift`, `src/NitroBrew/Views/StatsView.swift`, `src/NitroBrew/Views/Theme.swift`
- Test: `src/NitroBrewTests/ThemeTests.swift` (light check only)

**Interfaces:**
- Consumes: `SessionEngine`, `AppSettings`, `StatsStore`, `VesselView`, `StatusText`, `CompletionMessage`.
- Produces:
  - `struct TimerView: View { init(engine: SessionEngine, settings: AppSettings, completion: CompletionMessage?, onStartNext: () -> Void, onDismissCompletion: () -> Void) }`: mode chips (Work 25, Work 50, Break 5, Break 10), `VesselView`, large remaining time (`mm:ss`, tabular digits), status line, Start/Pause/Resume and Reset buttons, and a completion banner with the message's action button.
  - `struct SettingsView: View` (vessel picker showing all three live icons at current level, auto-start toggles, alert sound picker, show time in menu bar toggle) and `struct StatsView: View` (today, totals, last 10 sessions, Export, Clear with in-view confirmation).
  - `enum Theme { static let background: Color; cream, amber, roast, foam }`. Background is pure black.

- [ ] **Step 1:** Write `ThemeTests.testBackgroundIsBlack` (resolve `Theme.background` to sRGB components 0, 0, 0).
- [ ] **Step 2:** Also write `AppVersion` tests in `src/NitroBrewTests/AppVersionTests.swift`: `AppVersion.display(from: [String: Any]) -> String` returns "Version 1.0.0 (1)" for `CFBundleShortVersionString` "1.0.0" and `CFBundleVersion` "1", and "Version unknown" when keys are missing; `AppVersion.current` equals the bundle's values. `SettingsView` shows `AppVersion.current.display` as a footer line, and the right-click menu (Task 7) has an "About NitroBrew" item that shows the same text.
- [ ] **Step 2b:** Run it. Expected: FAIL. Implement `Theme` and `AppVersion` (in `src/NitroBrew/App/AppVersion.swift`), then the three views to match the prototype's layout and wording. Run again. Expected: PASS.
- [ ] **Step 3:** Add `#Preview` blocks for `TimerView` at idle, 40% work, and done states; build to confirm they compile.
- [ ] **Step 4:** Commit: `feat: timer, settings and stats views`.

### Task 7: Menu bar controller and window

**Files:**
- Create: `src/NitroBrew/App/MenuBarController.swift`, `src/NitroBrew/App/WindowController.swift`
- Modify: `src/NitroBrew/App/AppDelegate.swift`

**Interfaces:**
- Consumes: `SessionEngine`, `AppSettings`, `StatsStore`, `MenuBarIconRenderer`, `TimerView`, `SettingsView`.
- Produces: `final class MenuBarController` with `init(coordinator: AppCoordinator)` and `func cleanup()`. Behavior: `NSStatusItem` with the template icon for the chosen vessel at the current level, redrawn once per second (and on vessel change); title shows `mm:ss` when `showTimeInMenuBar`; left click toggles an `NSPopover` (`.transient`) hosting `TimerView`; right click shows a menu (Start/Pause, Reset, Open window, Settings, Quit). `WindowController` shows the same `TimerView` plus settings and stats in a normal window, opened from the right-click menu.

- [ ] **Step 1:** Implement the controllers. Use a repeating `Timer` on the main run loop only to call `engine.tick()` and refresh the icon; the engine remains the source of truth.
- [ ] **Step 2:** Build. Expected: success.
- [ ] **Step 3:** Commit: `feat: menu bar controller, popover and window`.

### Task 8: Coordinator and persistence

**Files:**
- Create: `src/NitroBrew/App/AppCoordinator.swift`
- Modify: `src/NitroBrew/App/AppDelegate.swift`
- Test: `src/NitroBrewTests/AppCoordinatorTests.swift`

**Interfaces:**
- Consumes: `SessionEngine`, `AppSettings`, `StatsStore`, `Notifying`, `SoundPlaying`, `CompletionMessage`.
- Produces: `@MainActor final class AppCoordinator: ObservableObject` with `init(engine:settings:stats:notifier:sound:defaults:)`, `@Published var completion: CompletionMessage?`, `func startNext()`, `func tick()`, `func saveState()`, `func restoreState()`. On engine completion it: records a completed `SessionRecord`, shows the notification, plays the alert sound, publishes `completion`, and, if the matching auto-start setting is on, starts the next session (work → break, break → work) and clears `completion`. `saveState()` stores `EngineSnapshot` as JSON in `defaults`; call it on every phase change and at terminate. `restoreState()` loads it before the first `tick()`.

- [ ] **Step 1:** Write failing tests with fakes for `Notifying` and `SoundPlaying` and a fake clock:
  - `testCompletionRecordsNotifiesAndPlays`: one record, one notification with `CompletionMessage.make` output, one sound.
  - `testAutoStartBreaksStartsBreak` and `testAutoStartOffLeavesDone`.
  - `testStartNextFromWorkStartsBreak` and `testStartNextFromBreakStartsWork`.
  - `testRelaunchAfterEndRecordsExactlyOnce`: save mid-session, new coordinator with clock past the end, `restoreState()` then `tick()` twice → one record, one notification.
  - `testDeniedNotificationStillPlaysSound`: fake notifier that fails; the sound fake is still called.
  - `testResetMidSessionRecordsNothing`.
  - `testDismissingCompletionClearsIt`.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement `AppCoordinator`; wire it into `AppDelegate` (create engine, settings, stats at `~/Library/Application Support/NitroBrew/sessions.json`, notifier, sound; call `restoreState()` then start `MenuBarController`; call `saveState()` in `applicationWillTerminate`). In `#if DEBUG` builds only, if the launch argument `-NitroBrewDebugSpeed <n>` is set, the engine's clock runs `n` times faster than real time, so manual checks can finish a 25 minute session in seconds.
- [ ] **Step 4:** Run the full test suite. Expected: all pass.
- [ ] **Step 5:** Commit: `feat: app coordinator, auto-start and state restore`.

### Task 9: Manual verification and polish

**Files:**
- Modify: `CLAUDE.md`, create `README.md`, `CHANGELOG.md`

- [ ] **Step 1:** Run the app (`xcodebuild ... build`, then open the built app). Verify by eye and note results in the PR description: for each of the three vessels, the icon in the menu bar fills with progress and matches the popover vessel; foam grows gradually with no pop; cascade plays on a fresh work start only; launch a debug build with `-NitroBrewDebugSpeed 60` to reach completion quickly, confirm notification, chime and "Start 5 min break"; break drains and ends with "Glass is empty" (and "Can is empty" for the can); relaunch mid-session and after the end time.
- [ ] **Step 2:** Confirm the pint and pub glass icons are distinguishable at 18 px in the real menu bar; if not, adjust `VesselGeometry` for pub and re-run `VesselTests`.
- [ ] **Step 3:** Write `README.md` and `CHANGELOG.md` (short: what it is, build and test commands, GPL-3). `CHANGELOG.md` starts with a `## 1.0.0` entry. Add a "Releasing" section to `CLAUDE.md`: bump `MARKETING_VERSION` (and `CURRENT_PROJECT_VERSION`) in `project.yml`, run `xcodegen generate`, add a changelog entry, commit, then tag `vX.Y.Z`.
- [ ] **Step 4:** Commit: `docs: README, changelog and verification notes`.

### Task 10: App icon

**Files:**
- Create: `scripts/make_app_icon.swift`, `src/NitroBrew/Resources/Assets.xcassets/AppIcon.appiconset/*`

- [ ] **Step 1:** Write `scripts/make_app_icon.swift` (`swift scripts/make_app_icon.swift <out.png>`) drawing a pint glass of nitro brew with a cream foam head and a few cascade streaks on a black rounded square. It must not contain a mug, saucer or steam.
- [ ] **Step 2:** Generate the icon sizes into `AppIcon.appiconset`, point `project.yml` at it, regenerate the project, build.
- [ ] **Step 3:** Commit: `feat: app icon`.

### Task 11: GitHub Actions build, test and release

**Files:**
- Create: `.github/workflows/ci.yml`, `.github/workflows/release.yml`, `scripts/build_pkg.sh`

**Interfaces:**
- Consumes: the `NitroBrew` scheme and `NitroBrewTests` target from Task 0 (the generated `.xcodeproj` is committed, so CI does not need XcodeGen).
- Produces: `ci.yml` (on push to `main` and on every pull request: build and run the test command from Global Constraints); `release.yml` (on a `v*` tag or manual run: build `build/NitroBrew-<version>.pkg` with `scripts/build_pkg.sh`, upload it as an artifact, and on tags create a GitHub Release). `scripts/build_pkg.sh` builds a Release app (ad-hoc signed, pkg unsigned by default; signs and notarizes when `APP_IDENTITY`, `PKG_IDENTITY` and `NOTARY_PROFILE` are set), bundle id `com.ir77io.nitrobrewtimer`.

- [ ] **Step 1:** Write `scripts/build_pkg.sh` and `release.yml` by adapting Triple Espresso's (`/Users/jeisenberg/Documents/GitHub/tripleespresso/scripts/build_pkg.sh` and `.github/workflows/release.yml`): rename the app, bundle id and pkg name, keep `runs-on: macos-15` with `maxim-lobanov/setup-xcode@v1` (`latest-stable`) and the tag-matches-version check. Add a second check that fails the release if `CHANGELOG.md` has no `## X.Y.Z` heading for the tag's version, and use that changelog section as the GitHub Release notes instead of `--generate-notes`. Write fresh text; both repos are the same author's, but do not copy code from the old timer.
- [ ] **Step 2:** Write `ci.yml` with one `macos-15` job: checkout, setup-xcode, `xcodebuild -version`, then the test command.
- [ ] **Step 3:** Run `./scripts/build_pkg.sh` locally. Expected: `build/NitroBrew-<version>.pkg` exists and `pkgutil --payload-files` lists `NitroBrew.app`.
- [ ] **Step 4:** Commit: `ci: GitHub Actions build, test and release`. Pushing the branch and opening a PR (which triggers the first CI run) is a separate step that waits for the author's go-ahead.

---

## Self-Review

- **Spec coverage:** vessels and pick (Tasks 3, 4, 6), gradual foam (2), cascade only on fresh start (1, 3), end-of-session flow and wording (5, 8), break drain and direct break from full (1), menu bar icon, time toggle, right-click menu (3, 7), auto-start (4, 8), stats and persistence (4, 8), wall-clock timing and relaunch (1, 8), dark look (6), String Catalog (0, 5), bundle id (0), GPL fresh code (Global Constraints), app icon not a cup (10), folder layout (Global Constraints).
- **Types:** `SessionMode`, `SessionPhase`, `EngineSnapshot`, `SessionEngine`, `Vessel.noun`, `FoamModel`, `CascadeModel`, `CompletionMessage`, `AppCoordinator` are defined once and referenced by the same names.
- **Open for the builder:** vessel path tuning, particle counts, soft chime synthesis, notification category wording beyond the examples.
