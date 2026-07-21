import AppKit
import Combine
import Defaults
import SwiftUI

/// Hosts Boring Notch's ContentView window inside Aura, while Aura keeps
/// menu-bar Pomodoro / Stopwatch / Todo / Settings.
@MainActor
final class BoringNotchHost {
    static let shared = BoringNotchHost()

    private let vm = BoringViewModel()
    private var window: NSWindow?
    private var windows: [String: NSWindow] = [:]
    private var viewModels: [String: BoringViewModel] = [:]
    private var screenObserver: NSObjectProtocol?
    private var selectedScreenObserver: NSObjectProtocol?
    private var notchHeightObserver: NSObjectProtocol?
    private var showOnAllDisplaysObserver: NSObjectProtocol?

    private init() {}

    func setup() {
        // Skip BN onboarding gate — otherwise hover never opens the notch
        UserDefaults.standard.set(false, forKey: "firstLaunch")
        UserDefaults.standard.set(false, forKey: "showWhatsNew")
        BoringViewCoordinator.shared.firstLaunch = false
        BoringViewCoordinator.shared.showWhatsNew = false
        BoringViewCoordinator.shared.helloAnimationRunning = false

        // Force Apple Music / Spotify controllers — MediaRemote adapter framework is not bundled in SPM
        if Defaults[.mediaController] == .nowPlaying {
            Defaults[.mediaController] = MusicManager.shared.isNowPlayingDeprecated ? .appleMusic : .spotify
        }

        Defaults[.openNotchOnHover] = true

        _ = MusicManager.shared
        _ = BatteryStatusViewModel.shared
        _ = CalendarManager.shared

        adjustWindowPosition(changeAlpha: true)

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

    private func createBoringNotchWindow(for screen: NSScreen, with viewModel: BoringViewModel) -> NSWindow {
        let rect = NSRect(x: 0, y: 0, width: windowSize.width, height: windowSize.height)
        let styleMask: NSWindow.StyleMask = [.borderless, .nonactivatingPanel, .fullSizeContentView]
        let panel = BoringNotchWindow(
            contentRect: rect,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )

        let hosting = NSHostingView(
            rootView: ContentView()
                .environmentObject(viewModel)
        )
        hosting.frame = rect
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting

        // Critical: receive hover / clicks (do NOT use BN CGSSpace — breaks hit testing in Aura)
        panel.ignoresMouseEvents = false
        panel.acceptsMouseMovedEvents = true
        panel.hidesOnDeactivate = false
        panel.isExcludedFromWindowsMenu = true
        panel.orderFrontRegardless()
        return panel
    }

    private func positionWindow(_ window: NSWindow, on screen: NSScreen, changeAlpha: Bool = false) {
        if changeAlpha { window.alphaValue = 0 }
        let screenFrame = screen.frame
        let size = windowSize
        window.setFrame(
            NSRect(
                x: screenFrame.origin.x + (screenFrame.width / 2) - size.width / 2,
                y: screenFrame.origin.y + screenFrame.height - size.height,
                width: size.width,
                height: size.height
            ),
            display: true
        )
        window.alphaValue = 1
        window.orderFrontRegardless()
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
                    let vm = BoringViewModel(screenUUID: uuid)
                    viewModels[uuid] = vm
                    return vm
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
        withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) {
            vm.open()
        }
    }

    func close() {
        withAnimation(.spring(response: 0.45, dampingFraction: 1.0)) {
            vm.close()
        }
    }
}
