# Project Aura: Phase 2 - Ultimate Improvements & Fixes Master File

## 0. Agent Directives & Strict Rules
You are continuing development on "Aura," a macOS glassmorphic productivity app. The initial build had UI glitches, dead buttons, and missing features. Your objective is to rewrite and fix the codebase based *strictly* on the instructions below. 
*   **NO STUBS:** Every button, text field, and slider must be fully functional. 
*   **NO HACKY APIs:** Remove `unsafeBitCast` and `dlopen`. Use public `MediaPlayer` and `AVFoundation` APIs.
*   **MODULARITY:** Edit the specific files mentioned. Do not refactor the entire architecture.
*   **SWIFT 6 COMPLIANCE:** Maintain strict `@MainActor` isolation and `@Observable` state management.

---

## 1. The Dynamic Island (Notch) Overhaul
**Goal:** Replicate the premium feel of Alcove and Boring Notch. Remove the 24h clock. Fix the shape.

### 1.1 Notch Shape (The "Melted Drop")
*   **File:** `Features/DynamicIsland/NotchView.swift`
*   **Issue:** Currently has 4 rounded corners, making it look like a floating pill.
*   **Fix:** The top-left and top-right corners must have a 0px radius (sharp). The bottom-left and bottom-right corners must have a 24px continuous radius. 
*   **Implementation:** Use a custom `Path` or `RoundedRectangle(cornerRadii: RectangleCornerRadii(topLeading: 0, bottomLeading: 24, bottomTrailing: 24, topTrailing: 0), style: .continuous)`. The view must visually appear to be pouring out of the top bezel of the MacBook.

### 1.2 Media Tracking & Hover UI (Alcove/Boring Notch Style)
*   **Files:** `Features/DynamicIsland/MediaTracker.swift`, `Features/DynamicIsland/NotchViewModel.swift`, `Features/DynamicIsland/NotchView.swift`
*   **Issue:** Music icon doesn't respond, no controls, no source app tracking.
*   **Fix:** 
    1.  **API Replacement:** Delete the `dlopen` private API hack. Import `MediaPlayer`. Use `MPNowPlayingInfoCenter.default()` and `MPRemoteCommandCenter.shared()` to observe system-wide media (Spotify, Apple Music, Safari).
    2.  **Hover State:** When the mouse enters the notch area (`onHover`), the notch expands smoothly using `spring(response: 0.4, dampingFraction: 0.8)`. 
    3.  **Expanded UI:** The expanded view must show:
        *   The source app icon (e.g., Spotify icon) fetched via `NSWorkspace.shared.icon(forFile:)` or bundle identifier.
        *   Album art with a frosted glass blur behind it.
        *   Track title and artist.
        *   A draggable progress bar (`Slider`) mapped to the current track time.
        *   Three buttons: Previous, Play/Pause, Next. Hook these to `MPRemoteCommandCenter.shared().skipBackwardCommand`, `playCommand`, etc.
    4.  **Resting State:** When not hovering, display a tiny, minimalistic audio waveform or a thin progress ring if media is playing. If no media, display nothing (pure black notch).

---

## 2. Widget System & Windowing Fixes
**Goal:** Implement Shottr-style resizing, fix window controls, fix Opacity vs. Blur, and fix the broken To-Do list.

### 2.1 Window Controls (Close Button & Cmd+W)
*   **File:** `Core/WindowManagement/FloatingPanel.swift` & `Features/Widgets/WidgetContainer.swift`
*   **Issue:** No way to close the widget.
*   **Fix:**
    1.  In `WidgetContainer.swift`, add a custom close button (a sleek 12px circle with an 'x' or macOS traffic-light style) at the `topLeading` corner.
    2.  Bind this button to `PanelManager.shared.closePanel(id:)`.
    3.  In `FloatingPanel.swift`, implement `NSWindowController` or override `performKeyEquivalent(with:)` to intercept `Command + W`. If pressed, close the panel.

### 2.2 Shottr-Style Scroll-to-Zoom
*   **File:** `Core/WindowManagement/FloatingPanel.swift` & `Features/Widgets/WidgetContainer.swift`
*   **Issue:** Widgets are not resizable via scroll.
*   **Fix:**
    1.  In `FloatingPanel.swift`, override `scrollWheel(with event: NSEvent)`.
    2.  If `event.deltaY < 0` (scroll down), decrease a `@State var scale: CGFloat` (min 0.75). If `event.deltaY > 0` (scroll up), increase `scale` (max 1.5).
    3.  Apply `.scaleEffect(scale)` to the SwiftUI content.
    4.  Crucially, dynamically update the `NSPanel` frame size to match the scaled content using `panel.setContentSize(scale * originalSize)` with an `NSAnimationContext` animation.

### 2.3 Opacity vs. Blur Distinction
*   **File:** `Theme/GlassmorphicMaterials.swift` & `Features/Widgets/WidgetContainer.swift`
*   **Issue:** Opacity is capped, sliders are confusing and apply to the wrong elements.
*   **Fix:**
    1.  **Blur Slider:** Controls *only* the `NSVisualEffectView`. Range: `0.0` (transparent) to `1.0` (thick frosted glass). Apply this to the background material only.
    2.  **Opacity Slider:** Controls *only* the foreground UI (text, buttons, rings). Range: `0.3` to `1.0`. Apply this to the `VStack` containing the UI elements.
    3.  **UI Layout:** Hide these sliders by default. Add a small "Gear" icon to the top-right of the widget. Clicking it animates the widget's height downward (using `spring(response: 0.4, dampingFraction: 0.8)`) to reveal the sliders. Clicking it again collapses them.

### 2.4 Fixing the "Dead" To-Do List
*   **Files:** `Core/WindowManagement/FloatingPanel.swift`, `Features/Widgets/TodoWidget.swift`
*   **Issue:** Text field and plus button do not respond.
*   **Fix:** 
    1.  In `FloatingPanel.swift`, override `var needsPanelToBecomeKey: Bool { return true }` and ensure `styleMask` contains `.nonactivatingPanel`. This allows the panel to accept keyboard input without stealing focus from the user's main app.
    2.  In `TodoWidget.swift`, ensure the `TextField` is bound to a `@State var newTaskTitle: String = ""`.
    3.  The "Plus" button must call a function that saves `newTaskTitle` to `DataStore` (or SwiftData) and clears the string.
    4.  Ensure `onSubmit` of the `TextField` performs the same action as the Plus button.

---

## 3. Timers, Alarms & Automations
**Goal:** Real Pomodoro cycles, custom timers, file-based alarms, and the "Attention Wave" animation.

### 3.1 Pomodoro Cycle Logic
*   **File:** `Features/Widgets/PomodoroViewModel.swift`
*   **Issue:** It's just a static 45-minute countdown.
*   **Fix:** 
    1.  Create an `enum PomodoroPhase { case focus, shortBreak, longBreak }`.
    2.  Default cycle: 25m focus -> 5m short break -> 25m focus -> 5m short break -> 25m focus -> 5m short break -> 25m focus -> 15m long break (repeat).
    3.  When the timer hits 00:00, automatically transition to the next phase, trigger the completion animation, and play the alarm (if set).
    4.  Add UI buttons to switch between "Focus" and "Break" manually.

### 3.2 Custom Timers & File Alarms
*   **Files:** `Features/Widgets/StopwatchWidget.swift` (repurpose to `TimerWidget.swift`), `Features/AudioPlayer/LocalAudioManager.swift`
*   **Fix:**
    1.  Add a mode to set a custom duration (e.g., 10 minutes).
    2.  In the widget UI, add a button "Set Alarm Sound". This opens an `NSOpenPanel` allowing the user to select an `.mp3`, `.m4a`, or `.mov` file.
    3.  Store the file URL in `AppSettings`.
    4.  When the timer hits 0, pass the URL to `LocalAudioManager` to play on a loop until dismissed.
    5.  When the timer finishes, spawn a popup widget button "Stop Alarm". Clicking it stops the audio and resets the timer.

### 3.3 The "Attention Wave" Completion Animation
*   **File:** `Features/FocusRitual/FocusOverlay.swift`
*   **Issue:** No visual feedback when a timer completes.
*   **Fix:** 
    1.  Create a new full-screen transparent `NSPanel` (level: `.statusBar`).
    2.  When *any* timer completes, display a soft, expanding circular ripple originating from the center of the screen.
    3.  **Implementation:** Use SwiftUI `Canvas` or a `Circle()` with `.stroke(lineWidth: 2)` and a gentle accent color (e.g., `.blue.opacity(0.5)`).
    4.  Animate it with `.scaleEffect(from: 0.1, to: 3.0)` and `.opacity(from: 0.8, to: 0)` over `1.5` seconds using `easeOut(duration: 1.5)`.
    5.  This draws the user's eye without being intrusive. After the animation, remove the overlay panel.

---

## 4. Main App Window & Deep Settings UI
**Goal:** The "Command Center" dropdown link is dead. We need a native macOS Settings window with deep customization.

### 4.1 Main Settings Window Initialization
*   **Files:** `Core/WindowManagement/PanelManager.swift`, `Features/Settings/SettingsView.swift` (NEW FILE)
*   **Issue:** Clicking "Command Center" does nothing.
*   **Fix:**
    1.  Create `SettingsView.swift` using SwiftUI `Form` and `TabView` for native macOS settings aesthetics.
    2.  In `PanelManager`, add a function `openSettingsWindow()`.
    3.  Use a standard `NSWindow` (not `NSPanel`) for the settings window so it behaves like a normal macOS app window (`canBecomeMain = true`, `canBecomeKey = true`).
    4.  Hook the "Command Center" button in `MenuBarView` to call `PanelManager.shared.openSettingsWindow()`.

### 4.2 Deep Customization Options in Settings
*   **File:** `Features/Settings/SettingsView.swift`
*   **Requirements:** The Settings window must contain the following bindings, saved to `AppSettings` (SwiftData/JSON):
    *   **Appearance:** Toggle Dark/Light/System mode.
    *   **Accent Color:** A color picker (`ColorPicker`) that dynamically changes the app's accent color.
    *   **Glassmorphism Toggle:** A switch to turn off `NSVisualEffectView` entirely (fallback to solid dark/light background).
    *   **Dock Visibility:** Toggle to show/hide the app in the Dock (runtime modification of `NSApp.setActivationPolicy(.regular)` vs `.accessory`).
    *   **Menu Bar Icon Visibility:** Toggle to hide/show the `NSStatusItem`.
    *   **Notch Style:** Picker for different notch shapes (e.g., "Melted Drop", "Rounded Pill", "Hidden").
    *   **Music Integrations:** Toggles to request access to Apple Music (`SKCloudServiceController`) and Spotify API. 
    *   **Timer Defaults:** Fields to customize the Focus, Short Break, and Long Break durations for the Pomodoro cycle.

---

## 5. Menu Bar Dropdown Glitch Fix
*   **File:** `Features/MenuBar/MenuBarView.swift`
*   **Issue:** Clicking anywhere in the dropdown darkens the background glass material, causing a jarring visual glitch.
*   **Fix:**
    1.  Ensure all buttons inside the dropdown use `ButtonStyle.plain`.
    2.  Do not use standard `Button` actions that trigger `NSPopover` state changes. 
    3.  Wrap clickable elements in `LazyVStack` and apply custom `.onHover` states that only alter a local `@State isHovered` variable (e.g., changing background color to `.white.opacity(0.1)`).
    4.  Ensure the `NSPopover` containing this view has `behavior = .transient` and the `NSVisualEffectView` material is set to `.popover` with `.behindWindow` blending, so it inherently matches macOS behavior without darkening on click events.
