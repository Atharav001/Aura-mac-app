import AppKit
import SwiftUI

@MainActor
final class FloatingPanel: NSPanel {
    var panelID: UUID = UUID()
    var zoomScale: CGFloat = 1.0 {
        didSet {
            updatePanelSize()
        }
    }
    var onClose: ((UUID) -> Void)?
    private var originalSize: NSSize

    init(contentView: NSView, size: NSSize) {
        originalSize = size
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
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
        self.contentView = contentView
    }

    convenience init(rootView: some View, size: NSSize) {
        let hosting = NSHostingView(rootView: rootView)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        self.init(contentView: hosting, size: size)
    }

    func setIgnoresMouseEvents(_ flag: Bool) {
        ignoresMouseEvents = flag
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

    var scrollZoomEnabled: Bool = false

    override func scrollWheel(with event: NSEvent) {
        guard scrollZoomEnabled else {
            super.scrollWheel(with: event)
            return
        }
        let delta = event.deltaY
        guard delta != 0 else { return }
        zoomScale = (zoomScale + delta * 0.01).clamped(to: 0.75...1.5)
    }

    private func updatePanelSize() {
        let newSize = NSSize(
            width: max(200, originalSize.width * zoomScale),
            height: max(100, originalSize.height * zoomScale)
        )
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animator().setFrame(NSRect(origin: frame.origin, size: newSize), display: true)
        }
    }
}

extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
