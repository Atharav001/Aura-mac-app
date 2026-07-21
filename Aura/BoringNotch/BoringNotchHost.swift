import AppKit
import Combine
import Defaults
import SwiftUI

/// Hosts Boring Notch ContentView.
///
/// Important: do **not** resize the NSWindow during open/close — that races SwiftUI
/// layout and aborts AppKit (`NSWindowGetDisplayCycleObserverForLayout` → SIGABRT).
/// Instead keep a stable open-sized frame and toggle `ignoresMouseEvents` so menu-bar
/// icons beside the island stay clickable while the notch is closed.
@MainActor
final class BoringNotchHost {
    static let shared = BoringNotchHost()

    private let vm = BoringViewModel()
    private var window: NSWindow?
    private var windows: [String: NSWindow] = [:]
    private var viewModels: [String: BoringViewModel] = [:]
    private var mouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var passThroughTimer: Timer?
    private var screenObserver: NSObjectProtocol?
    private var selectedScreenObserver: NSObjectProtocol?
    private var notchHeightObserver: NSObjectProtocol?
    private var showOnAllDisplaysObserver: NSObjectProtocol?

    private init() {}

    func setup() {
        UserDefaults.standard.set(false, forKey: "firstLaunch")
        UserDefaults.standard.set(false, forKey: "showWhatsNew")
        BoringViewCoordinator.shared.firstLaunch = false
        BoringViewCoordinator.shared.showWhatsNew = false
        BoringViewCoordinator.shared.helloAnimationRunning = false

        if Defaults[.mediaController] == .nowPlaying {
            Defaults[.mediaController] = MusicManager.shared.isNowPlayingDeprecated ? .appleMusic : .spotify
        }
        Defaults[.openNotchOnHover] = true

        _ = MusicManager.shared
        _ = BatteryStatusViewModel.shared
        _ = CalendarManager.shared

        adjustWindowPosition(changeAlpha: true)
        startMousePassThroughMonitor()

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.adjustWindowPosition(changeAlpha: true) }
        }

        selectedScreenObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name.selectedScreenChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.adjustWindowPosition(changeAlpha: true) }
        }

        notchHeightObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name.notchHeightChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.adjustWindowPosition() }
        }

        showOnAllDisplaysObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name.showOnAllDisplaysChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.cleanupWindows()
                self?.adjustWindowPosition(changeAlpha: true)
            }
        }
    }

    // MARK: - Mouse pass-through

    private func startMousePassThroughMonitor() {
        // Lightweight timer is safer than flooding Task { @MainActor } from every mouse move
        passThroughTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateMousePassThrough() }
        }
        if let passThroughTimer {
            RunLoop.main.add(passThroughTimer, forMode: .common)
        }
        updateMousePassThrough()
    }

    private func updateMousePassThrough() {
        let mouse = NSEvent.mouseLocation
        if Defaults[.showOnAllDisplays] {
            for (uuid, win) in windows {
                let viewModel = viewModels[uuid] ?? vm
                applyPassThrough(to: win, viewModel: viewModel, mouse: mouse)
            }
        } else if let window {
            applyPassThrough(to: window, viewModel: vm, mouse: mouse)
        }
    }

    private func applyPassThrough(to window: NSWindow, viewModel: BoringViewModel, mouse: NSPoint) {
        if viewModel.notchState == .open {
            if window.ignoresMouseEvents {
                window.ignoresMouseEvents = false
            }
            return
        }

        guard let screen = window.screen ?? NSScreen.main else {
            window.ignoresMouseEvents = true
            return
        }

        // Only the physical island (screen coords) is interactive while closed
        let island = closedIslandScreenRect(for: viewModel, on: screen)
        let shouldIgnore = !island.contains(mouse)
        if window.ignoresMouseEvents != shouldIgnore {
            window.ignoresMouseEvents = shouldIgnore
        }
    }

    /// Hardware-notch sized hit target at the top-center of the screen.
    private func closedIslandScreenRect(for viewModel: BoringViewModel, on screen: NSScreen) -> NSRect {
        var width = max(viewModel.closedNotchSize.width, 120)
        let height = max(viewModel.closedNotchSize.height, 28) + 10

        let music = MusicManager.shared
        if (music.isPlaying || !music.isPlayerIdle),
           BoringViewCoordinator.shared.musicLiveActivityEnabled,
           !viewModel.hideOnClosed {
            width += (2 * max(0, viewModel.effectiveClosedNotchHeight - 12) + 20)
        }
        // Tiny hover pad only — not large enough to cover Control Center
        if Defaults[.extendHoverArea] {
            width += 16
        }

        let frame = screen.frame
        return NSRect(
            x: frame.midX - width / 2,
            y: frame.maxY - height,
            width: width,
            height: height
        )
    }

    // MARK: - Window create / position (stable full open size — never animates on hover)

    private func createBoringNotchWindow(for screen: NSScreen, with viewModel: BoringViewModel) -> NSWindow {
        let frame = stableWindowFrame(on: screen)
        let styleMask: NSWindow.StyleMask = [.borderless, .nonactivatingPanel, .fullSizeContentView]
        let panel = BoringNotchWindow(
            contentRect: frame,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )

        // Fixed container so SwiftUI layout never resizes the NSWindow.
        // Without this, NSHostingView.updateAnimatedWindowSize races AppKit
        // layout on open and aborts (_postWindowNeedsUpdateConstraints).
        let container = NSView(frame: NSRect(origin: .zero, size: frame.size))
        container.autoresizingMask = [.width, .height]
        container.wantsLayer = true

        let hosting = NSHostingView(
            rootView: ContentView()
                .environmentObject(viewModel)
                .frame(width: frame.width, height: frame.height, alignment: .top)
        )
        hosting.frame = container.bounds
        hosting.autoresizingMask = [.width, .height]
        if #available(macOS 13.0, *) {
            hosting.sizingOptions = []
        }
        container.addSubview(hosting)
        panel.contentView = container

        panel.ignoresMouseEvents = true
        panel.acceptsMouseMovedEvents = true
        panel.hidesOnDeactivate = false
        panel.isExcludedFromWindowsMenu = true
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
        return panel
    }

    private func stableWindowFrame(on screen: NSScreen) -> NSRect {
        let screenFrame = screen.frame
        let size = windowSize
        return NSRect(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }

    private func positionWindow(_ window: NSWindow, on screen: NSScreen, changeAlpha: Bool = false) {
        if changeAlpha { window.alphaValue = 0 }
        // Always set the stable frame synchronously — never during SwiftUI open animation
        window.setFrame(stableWindowFrame(on: screen), display: true)
        window.alphaValue = 1
        window.orderFrontRegardless()
        updateMousePassThrough()
    }

    private func cleanupWindows() {
        windows.values.forEach { $0.close() }
        windows.removeAll()
        viewModels.removeAll()
        if let window {
            window.close()
            self.window = nil
        }
    }

    func adjustWindowPosition(changeAlpha: Bool = false) {
        if Defaults[.showOnAllDisplays] {
            let screens = NSScreen.screens
            let uuids = Set(screens.compactMap(\.displayUUID))
            for (uuid, win) in windows where !uuids.contains(uuid) {
                win.close()
                windows.removeValue(forKey: uuid)
                viewModels.removeValue(forKey: uuid)
            }
            for screen in screens {
                guard let uuid = screen.displayUUID else { continue }
                let viewModel = viewModels[uuid] ?? {
                    let created = BoringViewModel(screenUUID: uuid)
                    viewModels[uuid] = created
                    return created
                }()
                let win = windows[uuid] ?? {
                    let w = createBoringNotchWindow(for: screen, with: viewModel)
                    windows[uuid] = w
                    return w
                }()
                positionWindow(win, on: screen, changeAlpha: changeAlpha)
            }
            if let window {
                window.close()
                self.window = nil
            }
        } else {
            windows.values.forEach { $0.close() }
            windows.removeAll()
            viewModels.removeAll()

            let selected =
                NSScreen.screen(withUUID: BoringViewCoordinator.shared.selectedScreenUUID)
                ?? NSScreen.main
            guard let selectedScreen = selected else { return }

            if window == nil {
                window = createBoringNotchWindow(for: selectedScreen, with: vm)
            }
            if let window {
                positionWindow(window, on: selectedScreen, changeAlpha: changeAlpha)
            }
        }
    }

    func open() {
        window?.ignoresMouseEvents = false
        windows.values.forEach { $0.ignoresMouseEvents = false }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) {
            vm.open()
        }
    }

    func close() {
        withAnimation(.spring(response: 0.45, dampingFraction: 1.0)) {
            vm.close()
        }
        // Defer pass-through update until after SwiftUI settles
        DispatchQueue.main.async { [weak self] in
            self?.updateMousePassThrough()
        }
    }
}
