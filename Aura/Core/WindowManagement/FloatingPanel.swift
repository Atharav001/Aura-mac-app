import AppKit
import SwiftUI

@MainActor
final class FloatingPanel: NSPanel {
    var panelID: UUID = UUID()
    var zoomScale: CGFloat = 1.0 {
        didSet {
            updatePanelSize()
            onZoomChanged?(zoomScale)
        }
    }
    var onClose: ((UUID) -> Void)?
    var onZoomChanged: ((CGFloat) -> Void)?
    private var baseSize: NSSize
    private var isResizingByUser = false

    init(contentView: NSView, size: NSSize) {
        baseSize = size
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isReleasedWhenClosed = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        minSize = NSSize(width: 180, height: 120)
        maxSize = NSSize(width: 900, height: 900)
        self.contentView = contentView
        scrollZoomEnabled = true
    }

    convenience init(rootView: some View, size: NSSize) {
        let hosting = NSHostingView(rootView: rootView)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        self.init(contentView: hosting, size: size)
    }

    func setIgnoresMouseEvents(_ flag: Bool) {
        ignoresMouseEvents = flag
    }

    func setAlwaysOnTop(_ enabled: Bool) {
        level = enabled ? .statusBar : .floating
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.keyCode == 13 && event.modifierFlags.contains(.command) {
            onClose?(panelID)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    var scrollZoomEnabled: Bool = true

    override func scrollWheel(with event: NSEvent) {
        guard scrollZoomEnabled else {
            super.scrollWheel(with: event)
            return
        }
        // Shotrr-style: scroll over panel zooms in/out
        let delta = event.scrollingDeltaY != 0 ? event.scrollingDeltaY : event.deltaY
        guard abs(delta) > 0.1 else { return }
        let factor = 1.0 + (delta * 0.008)
        zoomScale = (zoomScale * factor).clamped(to: 0.55...2.25)
    }

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        super.setFrame(frameRect, display: flag)
        // Keep base size in sync when user resizes via edges
        if isResizingByUser || inLiveResize {
            baseSize = NSSize(
                width: frameRect.width / max(zoomScale, 0.01),
                height: frameRect.height / max(zoomScale, 0.01)
            )
        }
    }

    private func updatePanelSize() {
        let newSize = NSSize(
            width: max(minSize.width, baseSize.width * zoomScale),
            height: max(minSize.height, baseSize.height * zoomScale)
        )
        var newFrame = frame
        // Zoom toward center to feel natural (Shotrr-like)
        let dx = (newSize.width - frame.width) / 2
        let dy = (newSize.height - frame.height) / 2
        newFrame.origin.x -= dx
        newFrame.origin.y -= dy
        newFrame.size = newSize

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().setFrame(newFrame, display: true)
        }
    }
}

extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
