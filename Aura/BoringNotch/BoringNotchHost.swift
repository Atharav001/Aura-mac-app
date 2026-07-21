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
        // Force Apple Music / Spotify controllers — MediaRemote adapter framework is not bundled in SPM
        if Defaults[.mediaController] == .nowPlaying {
            Defaults[.mediaController] = MusicManager.shared.isNowPlayingDeprecated ? .appleMusic : .spotify
        }

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
        let styleMask: NSWindow.StyleMask = [.borderless, .nonactivatingPanel, .utilityWindow, .hudWindow]
        let panel = BoringNotchWindow(
            contentRect: rect,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        panel.contentView = NSHostingView(
            rootView: ContentView()
                .environmentObject(viewModel)
        )
        panel.orderFrontRegardless()
        NotchSpaceManager.shared.notchSpace.windows.insert(panel)
        return panel
    }

    private func positionWindow(_ window: NSWindow, on screen: NSScreen, changeAlpha: Bool = false) {
        if changeAlpha { window.alphaValue = 0 }
        let screenFrame = screen.frame
        window.setFrameOrigin(
            NSPoint(
                x: screenFrame.origin.x + (screenFrame.width / 2) - window.frame.width / 2,
                y: screenFrame.origin.y + screenFrame.height - window.frame.height
            )
        )
        window.alphaValue = 1
    }

    private func cleanupWindows() {
        windows.values.forEach { $0.close(); NotchSpaceManager.shared.notchSpace.windows.remove($0) }
        windows.removeAll()
        viewModels.removeAll()
        if let window {
            window.close()
            NotchSpaceManager.shared.notchSpace.windows.remove(window)
            self.window = nil
        }
    }

    func adjustWindowPosition(changeAlpha: Bool = false) {
        if Defaults[.showOnAllDisplays] {
            let screens = NSScreen.screens
            // Close windows for removed screens
            let uuids = Set(screens.compactMap(\.displayUUID))
            for (uuid, win) in windows where !uuids.contains(uuid) {
                win.close()
                NotchSpaceManager.shared.notchSpace.windows.remove(win)
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
            // Tear down single-display window if any
            if let window {
                window.close()
                NotchSpaceManager.shared.notchSpace.windows.remove(window)
                self.window = nil
            }
        } else {
            windows.values.forEach { $0.close(); NotchSpaceManager.shared.notchSpace.windows.remove($0) }
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

    func open() { vm.open() }
    func close() { vm.close() }
}
