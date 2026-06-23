# Project: Aura (macOS Productivity Suite) - Master Instructions File

## 0. AI Agent Role & Objective
You are an elite macOS software engineer. Your objective is to build "Aura," a lightweight, highly aesthetic, glassmorphic macOS productivity app. The app features a Dynamic Island (Notch integration), floating pinnable widgets, a Menu Bar command center, and a local MP3 player. The design language is "Tahoe Glassmorphism"—pure Apple aesthetic, fluid spring animations, and zero functional errors.

> **Important limitation:** This environment has Command Line Tools (Swift 6.2.4) installed but **no Xcode**. The SwiftData `@Model` macro requires full Xcode to resolve macro plugins (`SwiftDataMacros`). As a workaround, the project uses a `DataStore` (JSON-based persistence) with the same API shape. When Xcode becomes available, migrate to `@Model` by adding `import SwiftData` and the `@Model` macro to model structs. See `Models/DataStore.swift`.

## 1. Tech Stack & Architecture Rules
*   **Language:** Swift 5.9+
*   **UI Framework:** SwiftUI (for views and animations) + AppKit (for windowing, `NSPanel`, and `NSStatusItem`).
*   **Data Persistence:** SwiftData target, but currently using `DataStore` (JSON persistence via `Codable`) as a fallback since the SwiftData `@Model` macro requires full Xcode (not just CLI tools). When Xcode is available, swap to SwiftData `@Model` models.
*   **Audio:** AVFoundation (`AVAudioPlayer` for local MP3s).
*   **State Management:** Strictly use the `@Observable` macro (Swift 5.9+) for all ViewModels. Do not use `ObservableObject` unless interacting with legacy AppKit delegates.
*   **Media Tracking:** Use `MPNowPlayingInfoCenter` and `MediaPlayer` framework as the primary, sandbox-safe API. If system-wide browser/Spotify tracking is required, use the private `MediaRemote.framework` via a bridging helper, but wrap it in `#if !APPSTORE` and handle nil gracefully.
*   **Coding Standard:** Strict modular architecture (MVVM). Ensure all UI updates happen on the main thread (`DispatchQueue.main.async`). 
*   **Testing:** XCTest for logic validation (Timers, SwiftData migrations, Audio parsing).

## 2. Folder Structure
Adhere strictly to this folder structure. Create files only in their designated folders:
```text
Aura/
├── Package.swift              # SwiftPM manifest (Xcode 15+ can open this directly)
├── Aura/
│   ├── AuraApp.swift         # App entry point, SwiftData container setup
│   ├── Info.plist            # Privacy permissions, window configurations
│   ├── Aura.entitlements     # App Sandbox, Audio Input, Accessibility
│   ├── Assets.xcassets/      # App icon, Menu Bar template icon, Accent colors
│   ├── Core/
│   │   ├── WindowManagement/ # NSPanel subclasses for floating widgets
│   │   │   ├── FloatingPanel.swift   # Configures floating, click-through windows
│   │   │   └── PanelManager.swift    # Handles spawning, positioning, snapping
│   │   └── NotchManager/     # Logic for detecting screen notch and sizing
│   │       └── NotchDetector.swift
│   ├── Features/
│   │   ├── MenuBar/          # Menu Bar dropdown logic
│   │   │   └── MenuBarView.swift
│   │   ├── DynamicIsland/    # The notch UI and logic
│   │   │   ├── NotchView.swift       # The main expanding view
│   │   │   ├── NotchViewModel.swift  # @Observable class for hover, expand, swipe
│   │   │   └── MediaTracker.swift    # MPNowPlayingInfoCenter integration
│   │   ├── Widgets/          # Individual floating widget views
│   │   │   ├── PomodoroWidget.swift
│   │   │   ├── TodoWidget.swift
│   │   │   ├── StopwatchWidget.swift
│   │   │   └── WidgetContainer.swift # Shared wrapper for opacity/blur sliders
│   │   ├── AudioPlayer/      # Local MP3 player logic
│   │   │   ├── LocalAudioManager.swift
│   │   │   └── AudioPlayerView.swift
│   │   └── FocusRitual/      # Screen-wide ripple effect & dimming
│   │       └── FocusOverlay.swift
│   ├── Models/
│   │   ├── TodoItem.swift            # Codable model (migrate to @Model when Xcode available)
│   │   ├── AppSettings.swift         # Codable model (migrate to @Model when Xcode available)
│   │   └── DataStore.swift           # JSON persistence layer (replaces SwiftData container for CLI)
│   ├── Theme/
│   │   ├── GlassmorphicMaterials.swift # Custom ViewModifiers for glass effect
│   │   ├── AnimationCurves.swift       # Standard spring curves
│   │   └── ThemeManager.swift          # Light/Dark/Time-of-day dynamic theming
│   └── Utils/
│       └── ScreenCapture.swift        # Helpers for screen edge dimming
└── AuraTests/
    ├── TimerLogicTests.swift
    └── SwiftDataTests.swift
```

## 3. Phased Implementation Plan
Execute these phases in exact order. Do not proceed to the next phase until the verification steps of the current phase are met.

### Phase 0: Project Scaffolding & Entitlements
**Scope:** Initialize the SwiftPM project, configure signing, and set up entitlements.
1.  Create `Package.swift` for the SwiftPM-based macOS app (can be opened in Xcode 15+ directly, or built via `swift build`).
2.  Configure `Info.plist` for background audio playback (`UIBackgroundModes`: `audio`).
3.  Set up `Aura.entitlements`: Enable `App Sandbox`, `Audio Input`, and `Access to Network`.
4.  Add a template image to `Assets.xcassets` for the Menu Bar `NSStatusItem`.
5.  Create stub file tree matching the folder structure in Section 2.
6.  Set up `DataStore.swift` (JSON persistence) in `AuraApp.swift` — avoids `@Model` macro which requires full Xcode.
**Modular Verification:**
- [ ] `swift build` completes without errors.
- [ ] Entitlements file is present and sandbox is enabled.
- [ ] Binary exists at `.build/debug/Aura`.
- [ ] Project opens in Xcode if Xcode is available (via `Package.swift`).

### Phase 1: Foundation & Windowing (AppKit + SwiftUI)
**Scope:** Build the `FloatingPanel` subclass and `@Observable` ViewModels.
1.  Create `FloatingPanel.swift`: An `NSPanel` subclass with `level = .floating`, `collectionBehavior = [.canJoinAllSpaces, .stationary]`, and transparent background settings (`isOpaque = false`, `backgroundColor = .clear`).
2.  Create `PanelManager.swift`: A singleton that spawns, positions, and closes panels. Include "Widget Magnetism" (snapping to screen edges with spring animations).
3.  Create `GlassmorphicMaterials.swift`: A ViewModifier applying `.ultraThinMaterial` with adjustable opacity.
4.  Ensure ViewModels use `@Observable`:
    ```swift
    @Observable
    class WidgetState {
        var opacity: Double = 0.8
        var isPinned: Bool = false
    }
    ```
**Modular Verification:**
- [ ] A test SwiftUI view can be spawned as a floating window.
- [ ] The floating window is click-through where transparent.
- [ ] Window can be dragged and snaps to screen corners.

### Phase 2: The Menu Bar Command Center
**Scope:** Build the `NSStatusItem` and the dropdown SwiftUI menu.
1.  Create `MenuBarView.swift` using SwiftUI and `MenuBarExtra`.
2.  Implement UI for: "Start Pomodoro (25m)", "Spawn To-Do Widget", "Spawn Timer Widget".
3.  Implement "Local Audio Hub" UI: A button to select a directory (`NSOpenPanel`). Once selected, read all `.mp3` files and list them in the menu.
4.  Integrate with `PanelManager` so clicking "Spawn To-Do Widget" actually spawns the floating window.
**Modular Verification:**
- [ ] Menu bar icon appears on app launch using the template asset.
- [ ] Clicking the icon drops down a glassmorphic SwiftUI view.
- [ ] Directory picker successfully reads MP3s and lists them.

### Phase 3: Core Widgets (Pomodoro & To-Do)
**Scope:** Build the actual functional UI for the floating widgets.
1.  **PomodoroWidget:** Circular progress ring, start/pause/reset buttons. When time is up, trigger a system notification and a visual animation.
2.  **TodoWidget:** List of tasks using SwiftData. Swipe to delete, tap to check off. When a task is checked off, trigger a "glass shard confetti" animation.
3.  **StopwatchWidget:** Standard stopwatch with fluid digit rollovers.
4.  Wrap all widgets in `WidgetContainer.swift` which includes a live opacity slider and blur intensity slider.
**Modular Verification:**
- [ ] Pomodoro timer counts down accurately in the background.
- [ ] To-Do items persist after app restart (SwiftData working).
- [ ] Opacity and blur sliders dynamically update the widget window in real-time.

### Phase 4: The Dynamic Island (Notch) & Media Routing
**Scope:** Create the notch overlay window and media integration.
1.  Create `NotchDetector.swift`: Detect if the Mac has a notch and return the `CGRect` of the notch area.
2.  Create a specialized transparent `NSPanel` that sits exactly over the notch area, ignoring mouse events unless hovered.
3.  Create `NotchViewModel.swift` using `@Observable` to manage states: `.collapsed`, `.expanded`, `.media`, `.timer`.
4.  Create `NotchView.swift`: Expand vertically/horizontally with `spring(response: 0.4, dampingFraction: 0.8)`.
5.  Create `MediaTracker.swift`: Use `MPNowPlayingInfoCenter` for sandbox-safe media tracking. If access to third-party browser audio is required, bridge to the private `MediaRemote.framework`:
    ```swift
    // Warning: Private API. Wrap safely.
    @objc protocol MediaRemoteProtocol {
        func MRMediaRemoteGetNowPlayingInfo(@escaping (Dictionary<NSString, Any>) -> Void) -> Void
    }
    ```
    Ensure this does not cause a crash if the framework is missing.
**Modular Verification:**
- [ ] Notch window aligns perfectly with the physical hardware notch.
- [ ] Hovering expands the view smoothly without flickering.
- [ ] Playing a song in Apple Music updates the Notch UI.

### Phase 5: The "Focus Ritual" & Dynamic Elements
**Scope:** Add screen-wide dynamic effects for a premium feel.
1.  Create `FocusOverlay.swift`: A full-screen transparent `NSPanel` that sits below the floating widgets but above the desktop.
2.  When a Pomodoro starts:
    - Trigger a "water ripple" animation using SwiftUI `Canvas`.
    - Apply a subtle dark radial gradient to the edges of `FocusOverlay`.
    - Enable macOS "Do Not Disturb" / Focus Mode. *Note: Do not use fragile shell commands (`defaults write ...`). On macOS 14+, use `NotificationCenter` and the `Focus` API if available, or safely route the user to System Settings to activate it manually if programmatic activation is blocked by sandbox.*
3.  **Time-of-Day Theming:** Create logic in `ThemeManager.swift` to check the system time. Morning: Warm amber. Night: Deep black/cool blue.
**Modular Verification:**
- [ ] Starting a Pomodoro triggers the ripple animation.
- [ ] Screen edges dim smoothly.
- [ ] Theme tint changes dynamically based on time of day.

### Phase 6: Polish, Testing & Theming Engine
**Scope:** Final aesthetic pass, custom themes, testing, and performance optimization.
1.  Implement custom accent themes (Synthwave, Tokyo Night) in `ThemeManager.swift`.
2.  Write Unit Tests in `AuraTests/`:
    - `TimerLogicTests.swift`: Verify Pomodoro countdown logic.
    - `SwiftDataTests.swift`: Verify To-Do item creation and persistence.
3.  Optimize SwiftUI views: Use `equatable()` on complex views to prevent unnecessary redraws.
4.  Handle edge cases: External monitor plug/unplug, deleted audio folder.
**Modular Verification:**
- [ ] Unit tests pass.
- [ ] App uses less than 80-100MB of RAM when idle (realistic target for SwiftUI + AppKit floating windows).
- [ ] No frame drops during transitions between notch states.
- [ ] App does not crash when screen configuration changes.

## 4. Strict Agent Rules
1.  **Project First:** Do not write Swift files without the project scaffolding existing. Run Phase 0 first.
2.  **Sandbox Safety:** Default to sandbox-safe APIs. If using `MediaRemote.framework` or other private APIs, clearly comment them with `// PRIVATE API - NOT FOR APP STORE`.
3.  **No Hallucinated APIs:** If you are unsure about a macOS API, refer to Apple documentation. Do not invent functions.
4.  **Context Adherence:** Always refer back to this file. If the user asks for a feature not listed here, politely decline and state that the current objective is to perfect the features defined in this document.
5.  **SwiftData Macro Limitation:** The `@Model` macro from SwiftData **requires full Xcode** (Command Line Tools alone cannot resolve `SwiftDataMacros` plugin). Always use the `DataStore` JSON-based persistence layer when building in CLI-only environments. If Xcode becomes available, migrate models from `Codable` structs to `@Model` classes by adding `import SwiftData` and replacing conformance.
