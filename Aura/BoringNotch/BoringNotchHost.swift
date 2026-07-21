import AppKit
import Combine
import Defaults
import SwiftUI

/// Hosts Boring Notch ContentView. Window frame shrinks to the physical notch when
/// closed so macOS menu-bar status items stay clickable (hit-testing alone is not enough
/// for SystemUIServer extras under a high-level panel).
@MainActor
final class BoringNotchHost {
    static let shared = BoringNotchHost()

    private let vm = BoringViewModel()
    private var window: NSWindow?
    private var windows: [String: NSWindow] = [:]
    private var viewModels: [String: BoringViewModel] = [:]
    private var cancellables = Set<AnyCancellable>()
    private var mouseMonitor: Any?
    private var localMouseMonitor: Any?
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

        // Resize panel whenever open/closed or live-activity width changes
        Publishers.CombineLatest3(vm.$notchState, vm.$notchSize, vm.$closedNotchSize)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _, _ in
                self?.syncAllWindowFrames(animated: true)
            }
            .store(in: &cancellables)

        MusicManager.shared.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.syncAllWindowFrames(animated: true)
            }
            .store(in: &cancellables)

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
            Task { @MainActor in self?.syncAllWindowFrames(animated: false) }
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

    // MARK: - Mouse pass-through (critical for menu-bar icons)

    /// When the notch is closed, ignore mouse events unless the cursor is over the
    /// physical island. High-level panels otherwise steal clicks from Control Center etc.
    private func startMousePassThroughMonitor() {
        let handler: (NSEvent) -> Void = { [weak self] _ in
            Task { @MainActor in self?.updateMousePassThrough() }
        }
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged],
            handler: handler
        )
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged]
        ) { [weak self] event in
            Task { @MainActor in self?.updateMousePassThrough() }
            return event
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
            window.ignoresMouseEvents = false
            return
        }
        // Closed: only accept input while cursor is over the island frame (+ tiny pad)
        let frame = window.frame.insetBy(dx: -4, dy: -6)
        window.ignoresMouseEvents = !frame.contains(mouse)
    }

    // MARK: - Window sizing

    /// Frame that must NOT cover left/right menu-bar status items when closed.
    private func targetFrame(for viewModel: BoringViewModel, on screen: NSScreen) -> NSRect {
        let screenFrame = screen.frame
        let size = panelSize(for: viewModel)
        return NSRect(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }

    private func panelSize(for viewModel: BoringViewModel) -> CGSize {
        if viewModel.notchState == .open {
            return windowSize
        }
        var width = max(viewModel.closedNotchSize.width, 120)
        let height = max(viewModel.closedNotchSize.height, 28) + 4

        let music = MusicManager.shared
        if (music.isPlaying || !music.isPlayerIdle),
           BoringViewCoordinator.shared.musicLiveActivityEnabled,
           !viewModel.hideOnClosed {
            width += (2 * max(0, viewModel.effectiveClosedNotchHeight - 12) + 20)
        }
        // Do NOT add large hover padding to the window itself — that covers menu icons.
        // Hover discovery uses ignoresMouseEvents toggling + small inset instead.
        return CGSize(width: width, height: height)
    }

    private func syncAllWindowFrames(animated: Bool) {
        if Defaults[.showOnAllDisplays] {
            for (uuid, win) in windows {
                guard let screen = win.screen ?? NSScreen.screens.first(where: { $0.displayUUID == uuid }) else { continue }
                let viewModel = viewModels[uuid] ?? vm
                applyFrame(targetFrame(for: viewModel, on: screen), to: win, animated: animated)
            }
        } else if let window,
                  let screen = window.screen
                    ?? NSScreen.screen(withUUID: BoringViewCoordinator.shared.selectedScreenUUID)
                    ?? NSScreen.main {
            applyFrame(targetFrame(for: vm, on: screen), to: window, animated: animated)
        }
        updateMousePassThrough()
    }

    private func applyFrame(_ frame: NSRect, to window: NSWindow, animated: Bool) {
        guard window.frame != frame else { return }
        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.28
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(frame, display: true)
            }
        } else {
            window.setFrame(frame, display: true)
        }
    }

    private func createBoringNotchWindow(for screen: NSScreen, with viewModel: BoringViewModel) -> NSWindow {
        let frame = targetFrame(for: viewModel, on: screen)
        let styleMask: NSWindow.StyleMask = [.borderless, .nonactivatingPanel, .fullSizeContentView]
        let panel = BoringNotchWindow(
            contentRect: frame,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )

        let hosting = NSHostingView(
            rootView: ContentView()
                .environmentObject(viewModel)
        )
        hosting.frame = NSRect(origin: .zero, size: frame.size)
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting

        // Start click-through until cursor enters the island
        panel.ignoresMouseEvents = true
        panel.acceptsMouseMovedEvents = true
        panel.hidesOnDeactivate = false
        panel.isExcludedFromWindowsMenu = true
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
        return panel
    }

    private func positionWindow(_ window: NSWindow, on screen: NSScreen, changeAlpha: Bool = false, viewModel: BoringViewModel? = nil) {
        if changeAlpha { window.alphaValue = 0 }
        let vm = viewModel ?? self.vm
        applyFrame(targetFrame(for: vm, on: screen), to: window, animated: false)
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
                positionWindow(win, on: screen, changeAlpha: changeAlpha, viewModel: viewModel)
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
                positionWindow(window, on: selectedScreen, changeAlpha: changeAlpha, viewModel: vm)
            }
        }
    }

    func open() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) {
            vm.open()
        }
        window?.ignoresMouseEvents = false
        windows.values.forEach { $0.ignoresMouseEvents = false }
    }

    func close() {
        withAnimation(.spring(response: 0.45, dampingFraction: 1.0)) {
            vm.close()
        }
        updateMousePassThrough()
    }
}
