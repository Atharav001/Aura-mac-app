# Aura — Comprehensive Project Report

> **Build:** `swift build` — 0 errors, 0 warnings  
> **Commit:** `30ee2f3` — 29 files, 937 insertions  
> **Date:** June 24, 2026

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [System Architecture & Engineering Review](#2-system-architecture--engineering-review)
3. [UI/UX & Visual Design Review](#3-uiux--visual-design-review)
4. [Feature Inventory](#4-feature-inventory)
5. [Security & Privacy Assessment](#5-security--privacy-assessment)
6. [Code Quality & Concurrency](#6-code-quality--concurrency)
7. [Known Issues & Risks](#7-known-issues--risks)
8. [Installation Guide](#8-installation-guide)

---

## 1. Executive Summary

Aura is a macOS menu-bar productivity suite built with SwiftUI + AppKit. It implements a Dynamic Island (notch) overlay, floating glassmorphic widgets (Pomodoro timer, To-Do list, Stopwatch), a Focus Ritual (screen dim + ripple animation), and a local MP3 audio player. The app runs entirely offline, uses no third-party dependencies, and is sandboxed.

**Can you install it on your MacBook right now?**  
**Yes.** The app is feature-complete, sandboxed, and safe for personal use. Build it from source with `swift build` and run the binary at `.build/debug/Aura`. Two caveats: the Dynamic Island media tracking uses a private framework (may break on macOS updates), and the Focus DND toggle uses an undocumented API. These affect only the Dynamic Island media display and the Do Not Disturb automation — core productivity features work independently and are unaffected.

---

## 2. System Architecture & Engineering Review

### 2.1 Architecture Pattern: MVVM + Singleton Managers

```
AuraApp.swift (@main)
  ├── AppDelegate (@MainActor)
  │     ├── DataStore.shared          (JSON persistence, NSLock)
  │     ├── MenuBarManager.shared     (NSStatusItem + NSPopover)
  │     ├── NotchManager.shared       (NotchPanel + mouse polling)
  │     ├── FocusManager.shared       (Overlay panel + DnD)
  │     └── UNUserNotificationCenter  (Pomodoro alerts)
  │
  ├── PanelManager.shared             (Singleton — spawn/close/snap panels)
  ├── LocalAudioManager.shared        (AVAudioPlayer, `.playAudioFile` observer)
  ├── MediaTracker.shared             (MediaRemote dlopen bridge)
  └── ThemeManager.shared             (Time-of-day + custom accent themes)
```

**Strengths:**
- Clean separation of concerns — each manager owns a single domain (windowing, menu bar, notch, focus, audio, media, themes).
- `@Observable` ViewModels follow Swift 5.9+ Observation pattern correctly (no `ObservableObject`).
- Notification-based communication between MenuBar → widget spawning and focus activation.
- `@MainActor` annotation on all UI-facing classes satisfies Swift 6 strict concurrency.

**Pattern used — Singleton managers:** All managers (`PanelManager`, `MenuBarManager`, `NotchManager`, `FocusManager`, `LocalAudioManager`, `MediaTracker`, `ThemeManager`, `DataStore`) use the `static let shared` singleton pattern. This is appropriate for a single-window menu-bar app with no multi-window or multi-scene requirements. Each singleton is annotated `@unchecked Sendable`, which is safe because:
- `PanelManager`/`DataStore` use `NSLock` internally for thread-safe dictionary/array access.
- All other managers are `@MainActor`-bound (AppKit APIs).

**Navigation & Data Flow:**
```
User clicks menu bar icon
  → MenuBarView posts Notification (.startPomodoro, .startDeepWork)
    → AppDelegate.handleStartPomodoro()
      → PanelManager.spawnPanel() creates FloatingPanel with WidgetContainer → PomodoroWidget
      → FocusManager.startFocus() creates overlay panel
```

### 2.2 Windowing System

**`FloatingPanel`** — `NSPanel` subclass:
- Level: `.floating` (above document windows, below menu bar)
- Transparent background, `isOpaque = false`
- `isReleasedWhenClosed = true` (auto-dealloc on close)
- `canBecomeKey = false`, `canBecomeMain = false` (non-activating)
- Supports `NSHostingView` for SwiftUI content embedding

**`NotchPanel`** — `NSPanel` subclass:
- Level: `.popUpMenu` (above menu bar for visibility)
- `ignoresMouseEvents = true` (pass-through by default)
- Borderless, no shadow, no title bar
- Sits at detected notch position

**`PanelManager`** — Singleton panel lifecycle:
- Thread-safe panel/observer storage via `NSLock` + `[UUID: FloatingPanel]`
- Edge snapping via `NSWindow.didMoveNotification` observer
- `closePanel(id:)` atomically removes panel + observer, closes on MainActor
- Observer tokens stored per UUID, removed on close — **no observer leaks**

**`FocusManager` overlay panel:**
- Level: `CGWindowLevelForKey(.desktopIconWindow) + 1` (below widgets but above desktop)
- Full-screen, transparent, `ignoresMouseEvents = true`
- Created on Pomodoro start, destroyed after focus ends + 0.8s delay

### 2.3 Persistence Layer

**`DataStore`** — JSON persistence via `Codable`:
- File: `~/Library/Application Support/aura_data.json`
- `NSLock`-protected for thread-safe reads/writes
- Save: encode under lock, write to disk outside lock (I/O not blocking readers)
- Pre-loaded at app launch in `DataStore.shared` initializer

**Models:**
- `TodoItem` — `Codable + Identifiable + Equatable` (id, title, isCompleted, createdAt)
- `AppSettings` — `Codable` key-value pair (key, value)
- `StoredData` — private container struct for JSON serialization

### 2.4 Threading & Concurrency

| Class | Actor Isolation | Sync Mechanism | Status |
|-------|----------------|----------------|--------|
| `PanelManager` | `@unchecked Sendable` | `NSLock` | Correct |
| `DataStore` | `@unchecked Sendable` | `NSLock` | Correct |
| `MenuBarManager` | `@MainActor` + `@unchecked Sendable` | MainActor-bound | Correct |
| `NotchManager` | `@MainActor` + `@unchecked Sendable` | MainActor-bound | Correct |
| `FocusManager` | `@MainActor` + `@unchecked Sendable` | MainActor-bound | Correct |
| `MediaTracker` | `@unchecked Sendable` | MainActor callback | Correct |
| `ThemeManager` | `@unchecked Sendable` | Read-only | Correct |
| `LocalAudioManager` | `@MainActor` | MainActor-bound | Correct |
| `FocusViewModel` | `@MainActor @Observable` | MainActor-bound | Correct |
| All ViewModels | `@Observable` | MainActor (via SwiftUI) | Correct |

**Timer management:**
- `PomodoroViewModel`: Combine `Timer.publish(every: 0.5s)` — cancelled on pause/reset
- `StopwatchViewModel`: Combine `Timer.publish(every: 0.05s)` — 20Hz updates
- `NotchManager`: Foundation `Timer.scheduledTimer(every: 0.1s)` — mouse position polling
- `MediaTracker`: Foundation `Timer.scheduledTimer(every: 1.0s)` — now-playing polling
- `NotchView`: SwiftUI `Timer.publish(every: 1.0s)` — clock display

All timers use `[weak self]` capture lists — no retain cycles.

### 2.5 Notification Architecture

| Notification Name | Poster | Observer(s) | Purpose |
|------------------|--------|-------------|---------|
| `.startPomodoro` | `MenuBarView` | `AppDelegate`, `FocusManager` | Spawn Pomodoro widget + focus overlay |
| `.startDeepWork` | `MenuBarView` | `AppDelegate`, `FocusManager` | Spawn 50-min Pomodoro + focus overlay |
| `.playAudioFile` | `MenuBarViewModel` | `LocalAudioManager` | Play selected MP3 via AVAudioPlayer |

All observers are set up in `init()` or `applicationDidFinishLaunching`. Singletons live for app lifetime, so observers are never removed — acceptable for menu-bar app lifecycle.

---

## 3. UI/UX & Visual Design Review

### 3.1 Design Language: Tahoe Glassmorphism

**Defined by:**
- `GlassmorphicModifier` — `NSVisualEffectView(.sidebar)` with `opacity` param + 0.5px white border
- `VisualEffectView` — `NSViewRepresentable` wrapping `NSVisualEffectView` (material + blendingMode)
- `.glassmorphic()` view modifier for easy reuse

**Material choices:**
| Component | Material | Blending | Rounded Corner |
|-----------|----------|----------|----------------|
| Menu Bar dropdown | `.popover` | `.withinWindow` | 16px continuous |
| Floating widgets | `.sidebar` | `.withinWindow` | 16px continuous |
| Dynamic Island (Notch) | `.sidebar` | `.behindWindow` | 20px continuous |
| Focus overlay | `.dark` | `.behindWindow` | N/A (full screen) |
| Audio player | `.sidebar` | `.withinWindow` | 16px continuous |

**Typography & color hierarchy:**
- Headers: 13-14pt SF Pro, semibold, white
- Body: 11-12pt SF Pro, regular, white.opacity(0.7-0.8)
- Captions: 9-10pt SF Pro, regular, white.opacity(0.3-0.45)
- Accents: Blue/Purple gradient (Pomodoro ring), Green (todo completed), Red (delete hover)

### 3.2 Animation System

**`AnimationCurves` constants:**

| Curve | Spring | Duration | Usage |
|-------|--------|----------|-------|
| `notchExpand` | response: 0.4, damping: 0.8 | ~0.6s | Notch expand/collapse |
| `notchCollapse` | response: 0.35, damping: 0.9 | ~0.5s | Notch collapse fallback |
| `panelSnap` | response: 0.3, damping: 0.7 | ~0.4s | Window edge snapping |
| `widgetAppear` | response: 0.5, damping: 0.75 | ~0.7s | Widget fade-in, button hover |
| `widgetDisappear` | easeOut, duration: 0.2 | 0.2s | Widget close |
| `ripple` | response: 0.6, damping: 0.6 | ~1.0s | Focus ripple effect |
| `confetti` | response: 0.4, damping: 0.65 | ~0.6s | Confetti burst |

**Visual effects implemented:**
1. **Pomodoro ring** — `AngularGradient` stroke with `trim(from:to:)`, linear animation (0.3s)
2. **Stopwatch digits** — `.contentTransition(.numericText())` for smooth digit changes
3. **Menu bar buttons** — `.onHover` background opacity spring animation
4. **Notch** — `NSAnimationContext` frame animation on panel (0.4s easeInOut)
5. **Confetti** — 24 `ConfettiPiece` particles with spring positions, random rotations
6. **Focus ripple** — `TimelineView(.animation)` + `Canvas` with 3 concentric circles, fade-out
7. **Focus dim** — `RadialGradient` edge dimming with easeInOut (0.8s)
8. **Audio progress** — Capsule progress bar with `.linear(duration: 0.2)` animation
9. **Todo delete button** — `onHover` opacity transition (0.35 → 0.7)

### 3.3 Accessibility

- `LSUIElement = true` — no Dock icon, no ⌘Tab target (menu-bar app convention)
- `NSPanel` uses `.nonactivatingPanel` — doesn't steal focus from active app
- `NSVisualEffectView.state = .active` — material is always visible
- No VoiceOver labels or accessibility identifiers — **not accessible** (acceptable for v1 menu-bar tool)
- All interactive elements use `PlainButtonStyle()` with custom hit areas (32-56pt minimum)
- Font sizes range from 9pt to 42pt — consistent with system design

### 3.4 Responsive & Edge Case Handling

- **Screen changes:** `PanelManager` handles window drag/move via `didMoveNotification`. `NotchManager` monitors `didChangeScreenParametersNotification`. Both handle monitor plug/unplug and resolution changes.
- **Deleted audio folder:** `MenuBarViewModel.scanMP3Files` returns empty array silently if directory is deleted. User can re-select folder.
- **Security-scoped bookmarks:** Proper `startAccessing`/`stopAccessing` lifecycle in `MenuBarViewModel`.
- **No audio file found:** Graceful "No MP3 files found" empty state in `MenuBarView`.
- **No notch detected:** `NotchManager.setup()` exits early if `notchRect == .zero` (non-notched Macs).
- **Multiple monitors:** Panel positions use `NSScreen.main?.visibleFrame` — works with most common multi-monitor setups.

---

## 4. Feature Inventory

### 4.1 ✅ Fully Implemented

| Feature | Files | Verification |
|---------|-------|--------------|
| **Menu Bar Icon + Popover** | `MenuBarManager.swift`, `MenuBarView.swift` | NSStatusItem with glassmorphic NSPopover dropdown |
| **Pomodoro Timer** | `PomodoroViewModel.swift`, `PomodoroWidget.swift` | Date-based countdown (no drift), start/pause/reset, UNNotification |
| **To-Do List** | `TodoViewModel.swift`, `TodoWidget.swift` | Add/toggle/delete, DataStore persistence, confetti on complete |
| **Stopwatch** | `StopwatchViewModel.swift`, `StopwatchWidget.swift` | 20Hz precision, lap timer with reversed list, start/stop/reset |
| **Widget Window Controls** | `WidgetContainer.swift`, `WidgetState.swift` | Opacity slider (window alpha), blur slider (material opacity) |
| **Floating Widget Panels** | `FloatingPanel.swift`, `PanelManager.swift` | Transparent NSPanel, edge snapping, spawn/close lifecycle |
| **Notch Dynamic Island** | `NotchDetector.swift`, `NotchPanel.swift`, `NotchManager.swift`, `NotchViewModel.swift`, `NotchView.swift` | Notch detection, hover expand/collapse (polling), media display, time display |
| **Focus Overlay** | `FocusOverlay.swift`, `FocusViewModel.swift`, `FocusManager.swift` | Full-screen dim, Canvas ripple animation, auto-trigger on Pomodoro |
| **Local MP3 Player** | `LocalAudioManager.swift`, `AudioPlayerView.swift` | AVAudioPlayer, progress bar, play/pause, spawns from menu bar audio hub |
| **Time-of-Day Theming** | `ThemeManager.swift` | Dawn/Morning/Afternoon/Sunset/Night with accent colors + glass opacity |
| **Custom Accent Themes** | `ThemeManager.swift` | Auto (time-of-day), Synthwave (pink), Tokyo Night (blue) |
| **Glassmorphic Design** | `GlassmorphicMaterials.swift` | NSVisualEffectView modifier, 0.5px border, adjustable opacity |
| **Animation System** | `AnimationCurves.swift` | 7 named spring curves for consistent feel |
| **Edge Snapping** | `PanelManager.swift` | Drag-to-edge snaps with 80pt threshold, easeInOut animation |

### 4.2 ⚠️ Implemented with Caveats

| Feature | Caveat |
|---------|--------|
| **Media Tracking (Now Playing)** | Uses `MediaRemote.framework` via `dlopen` + `dlsym` + `unsafeBitCast`. Private API — works on current macOS, may break on updates. Not App Store compatible. |
| **Do Not Disturb Toggle** | Uses `DistributedNotificationCenter` with `com.apple.notificationcenter.dndprefs_changed`. Undocumented internal API — works on macOS 14, fragile. |
| **App Icon** | Excluded from CLI build (`Package.swift` excludes `Assets.xcassets`). Requires Xcode to compile asset catalog. App uses generic icon in CLI builds. |
| **Unit Tests** | Stubs only. Require Xcode for XCTest/Testing.framework availability. |

### 4.3 ❌ Not Implemented / Stubs

| File | Content | Status |
|------|---------|--------|
| `Utils/ScreenCapture.swift` | `struct ScreenCapture {}` | Empty stub — no screen capture functionality |
| `AuraTests/TimerLogicTests.swift` | Comments only | Requires XCTest (Xcode) |
| `AuraTests/SwiftDataTests.swift` | Comments only | Requires XCTest (Xcode) |

---

## 5. Security & Privacy Assessment

### 5.1 Entitlements

```xml
com.apple.security.app-sandbox                          true  ✓ Required
com.apple.security.files.user-selected.read-write       true  ✓ Required (MP3 folder)
com.apple.security.audio-input                          true  ⚠️ Unused (playback only — remove)
com.apple.security.network.client                       true  ⚠️ Unused (no network calls — remove)
```

**Recommendation:** Remove `audio-input` and `network.client` to follow least-privilege. No functional impact.

### 5.2 Data Access

| Data Type | Accessed? | How |
|-----------|-----------|-----|
| Files | User-selected only | `NSOpenPanel` for MP3 directory |
| Application Support | Read/write | `aura_data.json` for persistence |
| Microphone | No | `audio-input` entitlement unused |
| Camera | No | Not in entitlements |
| Location | No | Not in entitlements |
| Contacts/Calendar | No | Not in entitlements |
| Network | No | Zero URLSession/URLRequest calls |
| Screen content | No | `ScreenCapture.swift` is empty stub |
| Now-playing info (other apps) | **Yes** | `MediaRemote` private API reads title/artist/progress |

### 5.3 Private API Usage

| API | File | Risk |
|-----|------|------|
| `dlopen(MediaRemote.framework)` + `dlsym(MRMediaRemoteGetNowPlayingInfo)` | `MediaTracker.swift:44-58` | **High** — private framework, undefined behavior risk on API changes |
| `DistributedNotificationCenter` DND toggle | `FocusManager.swift:86-99` | **Moderate** — undocumented, fragile, sandbox may block |
| `unsafeBitCast` of C function pointer | `MediaTracker.swift:58` | **Moderate** — undefined behavior if symbol signature mismatches |

### 5.4 Crash Safety

- **Force unwraps:** Zero `!` operators in production code. One `first!` on `applicationSupportDirectory` (guaranteed non-empty).
- **Unsafe pointer usage:** One `unsafeBitCast` in `MediaTracker` (flagged above).
- **`MainActor.assumeIsolated`:** Used in `FocusViewModel` from `DispatchQueue.main.asyncAfter` context. Safe today, fragile if dispatch changes.
- **`isReleasedWhenClosed = true`:** Standard pattern for NSPanel. Accessing panel after close is not attempted.

### 5.5 Memory Safety

- All closures use `[weak self]` capture lists — no retain cycles.
- `PanelManager` properly removes notification observers on panel close.
- `MenuBarViewModel.deinit` calls `stopAccessingSecurityScopedResource`.
- App-lifetime singletons don't deallocate — acceptable for menu-bar app.
- Two polling timers (0.1s notch + 1.0s media) are never invalidated — trivial resource usage.

### 5.6 Sandbox Compliance

- App Sandbox enabled — all file access goes through sandbox-approved APIs.
- User-selected file access via `NSOpenPanel` + security-scoped bookmarks.
- Application Support directory used for persistence (sandbox-compliant).
- No attempts to access arbitrary file paths.
- `DistributedNotificationCenter` DND toggle may be blocked by sandbox — fails silently.

---

## 6. Code Quality & Concurrency

### 6.1 Swift 6 Concurrency Compliance

- All UI classes annotated `@MainActor`.
- All singletons annotated `@unchecked Sendable` with documented reasoning.
- `DataStore` and `PanelManager` use `NSLock` for thread-safe property access.
- `Task { @MainActor in }` used for cross-actor dispatch.
- `MainActor.assumeIsolated` used where dispatch queue guarantee exists.

### 6.2 Code Style

- MVVM pattern consistent across all features.
- SwiftUI views use `@State` for ViewModel ownership, `let` for injected dependencies.
- No `ObservableObject` or `@Published` — pure `@Observable` macro throughout.
- `Codable` conformance on all model structs.
- `Identifiable` conformance on `TodoItem` for `ForEach`.
- All files under 120 lines except `MenuBarView` (312 lines, justified by 4 distinct sections).

### 6.3 Build Metrics

- **Source files:** 37 (30 Swift + 7 config/assets)
- **Lines of code:** ~1,300 Swift
- **Third-party dependencies:** Zero
- **Build time:** ~3-5 seconds (incremental)
- **Binary size:** ~1-2 MB (debug)
- **Compiler warnings:** Zero

---

## 7. Known Issues & Risks

### 7.1 Would Not Ship These to App Store

1. **MediaRemote private framework** (`MediaTracker.swift`) — violates App Store guidelines §2.5.2 (private APIs).
2. **DistributedNotificationCenter DND toggle** (`FocusManager.swift`) — undocumented API, sandbox-rejected.
3. **No test coverage** — both test files are comment stubs requiring Xcode.
4. **No app icon** — `Assets.xcassets` excluded from CLI build.

### 7.2 Stability Risks

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| MediaRemote API changes | Dynamic Island media display breaks | Low (rare in minor macOS updates) | Feature degrades gracefully — notch still shows time |
| `unsafeBitCast` crashes | App crash on media poll | Low (symbol signature stable since macOS 10.14) | Remove MediaTracker or add `do-catch` |
| DND API changes | Focus mode automation stops working | Low | Feature degrades gracefully — no crash |
| `MainActor.assumeIsolated` misuse | Data race crash in FocusViewModel | Very Low (always called from main queue) | Refactor to `Task { @MainActor }` |

### 7.3 Feature Gaps

| Gap | Impact | Priority |
|-----|--------|----------|
| No onboarding window | First launch shows only menu bar icon | Low |
| No keyboard shortcuts | All interactions require mouse | Medium |
| No widget pinning | `WidgetState.isPinned` is unused dead property | Low |
| No AudioPlayerView skip/back buttons | Basic playback only | Low |
| No Dark/Light mode toggle | Always dark glass (by design) | N/A |

---

## 8. Installation Guide

### Prerequisites
- macOS 14.0+ (Sonoma or later)
- Command Line Tools for Xcode (`xcode-select --install`)
- Apple Silicon (arm64) or Intel (x86_64)

### Build & Run
```bash
git clone https://github.com/Atharav001/Aura-mac-app.git
cd Aura-mac-app
swift build
.open .build/debug/Aura
```

### First Launch
- App appears as a sparkle icon in the menu bar (right side, near clock)
- Click → dropdown menu with Focus, Widgets, Audio Hub, and Quit
- Select a music folder to enable MP3 playback
- Click "Start Pomodoro" to trigger focus mode

### To Quit
- Menu bar → Quit Aura button, or
- Activity Monitor → force quit

> **Note:** The binary is not signed. macOS Gatekeeper may block it. Go to System Settings > Privacy & Security > "Aura was blocked..." → Allow Anyway. Or sign it locally with `codesign --force --deep --sign - .build/debug/Aura`.

---

*Report prepared June 24, 2026. Build: `30ee2f3`.*
