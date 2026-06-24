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

        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let pos = position ?? CGPoint(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.midY - size.height / 2
        )
        panel.setFrameOrigin(pos)
        panel.orderFront(nil)

        let observer = addDragSnapping(to: panel)

        lock.withLock {
            panels[id] = panel
            observers[id] = observer
        }
        return id
    }

    func closePanel(id: UUID) {
        let info: (panel: FloatingPanel?, observer: NSObjectProtocol?) = lock.withLock {
            (panels.removeValue(forKey: id), observers.removeValue(forKey: id))
        }
        if let observer = info.observer {
            NotificationCenter.default.removeObserver(observer)
        }
        Task { @MainActor in
            info.panel?.close()
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
            allData.0.forEach { $0.close() }
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

        let frame = window.frame
        let threshold: CGFloat = snapThreshold
        var targetOrigin = frame.origin

        let snappedToLeft = frame.minX < screenFrame.minX + threshold
        let snappedToRight = frame.maxX > screenFrame.maxX - threshold
        let snappedToTop = frame.maxY > screenFrame.maxY - threshold
        let snappedToBottom = frame.minY < screenFrame.minY + threshold

        if snappedToLeft {
            targetOrigin.x = screenFrame.minX + edgePadding
        } else if snappedToRight {
            targetOrigin.x = screenFrame.maxX - frame.width - edgePadding
        }

        if snappedToTop {
            targetOrigin.y = screenFrame.maxY - frame.height - edgePadding
        } else if snappedToBottom {
            targetOrigin.y = screenFrame.minY + edgePadding
        }

        guard targetOrigin != frame.origin else { return }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrameOrigin(targetOrigin)
        }
    }
}
