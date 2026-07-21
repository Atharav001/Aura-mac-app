import AppKit
import SwiftUI

final class PanelManager: @unchecked Sendable {
    static let shared = PanelManager()

    private var panels: [UUID: FloatingPanel] = [:]
    private var observers: [UUID: NSObjectProtocol] = [:]
    private let lock = NSLock()
    private let snapThreshold: CGFloat = 80.0
    private let edgePadding: CGFloat = 8.0

    private init() {}

    @discardableResult
    @MainActor
    func spawnPanel<Content: View>(
        id: UUID = UUID(),
        size: NSSize = NSSize(width: 300, height: 400),
        position: CGPoint? = nil,
        @ViewBuilder content: () -> Content
    ) -> UUID {
        let panel = FloatingPanel(rootView: content(), size: size)
        panel.panelID = id
        panel.setAlwaysOnTop(true)
        panel.onClose = { [weak self] closedID in
            self?.closePanel(id: closedID)
        }

        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let pos = position ?? CGPoint(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.midY - size.height / 2
        )
        panel.setFrameOrigin(pos)
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)

        let observer = addDragSnapping(to: panel)

        lock.withLock {
            panels[id] = panel
            observers[id] = observer
        }
        return id
    }

    private var settingsWindow: NSWindow?

    @MainActor
    func openSettingsWindow() {
        if let existing = settingsWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
            .frame(minWidth: 520, idealWidth: 820, maxWidth: .infinity, minHeight: 400, idealHeight: 600, maxHeight: .infinity)
        let hostingView = NSHostingView(rootView: settingsView)
        hostingView.autoresizingMask = [.width, .height]

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Aura Settings"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .visible
        window.isOpaque = false
        window.backgroundColor = NSColor.black.withAlphaComponent(0.001)
        window.hasShadow = true
        window.isMovable = true
        window.isMovableByWindowBackground = true
        window.contentView = hostingView
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 520, height: 400)
        window.maxSize = NSSize(width: 1400, height: 1200)
        window.setContentSize(NSSize(width: 820, height: 600))
        window.center()
        window.makeKeyAndOrderFront(nil)

        NSApp.setActivationPolicy(.regular)
        MenuBarIconFactory.applyApplicationIcon()
        NSApp.activate(ignoringOtherApps: true)

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.settingsWindow = nil
                self?.restoreAccessoryPolicyIfNeeded()
            }
        }

        settingsWindow = window
    }

    func closePanel(id: UUID) {
        let info: (panel: FloatingPanel?, observer: NSObjectProtocol?) = lock.withLock {
            (panels.removeValue(forKey: id), observers.removeValue(forKey: id))
        }
        if let observer = info.observer {
            NotificationCenter.default.removeObserver(observer)
        }
        Task { @MainActor in
            // Only dismiss this widget — never terminate the menu-bar / notch app.
            if let panel = info.panel {
                panel.orderOut(nil)
                panel.close()
            }
            restoreAccessoryPolicyIfNeeded()
        }
    }

    func closeAll() {
        let allData: ([FloatingPanel], [NSObjectProtocol]) = lock.withLock {
            let panels = Array(self.panels.values)
            let obs = Array(self.observers.values)
            self.panels.removeAll()
            self.observers.removeAll()
            return (panels, obs)
        }
        allData.1.forEach { NotificationCenter.default.removeObserver($0) }
        Task { @MainActor in
            allData.0.forEach { panel in
                panel.orderOut(nil)
                panel.close()
            }
            restoreAccessoryPolicyIfNeeded()
        }
    }

    /// After the last widget/settings window closes, return to menu-bar mode (app stays running).
    @MainActor
    func restoreAccessoryPolicyIfNeeded() {
        let dockVisible = DataStore.shared.bool(for: .dockVisible, default: false)
        let hasSettings = settingsWindow?.isVisible == true
        let hasPanels = lock.withLock { !panels.isEmpty }
        if !dockVisible && !hasSettings && !hasPanels {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func panel(for id: UUID) -> FloatingPanel? {
        lock.withLock { panels[id] }
    }

    private func addDragSnapping(to panel: NSPanel) -> NSObjectProtocol {
        NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak self] notification in
            guard let movedWindow = notification.object as? NSWindow else { return }
            Task { @MainActor [weak self] in
                self?.snapWindowToEdge(window: movedWindow)
            }
        }
    }

    @MainActor
    private func snapWindowToEdge(window: NSWindow) {
        guard let screenFrame = NSScreen.main?.visibleFrame else { return }
        guard !window.inLiveResize else { return }

        let frame = window.frame
        let threshold: CGFloat = snapThreshold
        var targetOrigin = frame.origin

        if frame.minX < screenFrame.minX + threshold {
            targetOrigin.x = screenFrame.minX + edgePadding
        } else if frame.maxX > screenFrame.maxX - threshold {
            targetOrigin.x = screenFrame.maxX - frame.width - edgePadding
        }

        if frame.maxY > screenFrame.maxY - threshold {
            targetOrigin.y = screenFrame.maxY - frame.height - edgePadding
        } else if frame.minY < screenFrame.minY + threshold {
            targetOrigin.y = screenFrame.minY + edgePadding
        }

        guard targetOrigin != frame.origin else { return }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrameOrigin(targetOrigin)
        }
    }
}
