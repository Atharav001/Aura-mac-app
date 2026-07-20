import AppKit
import SwiftUI

@MainActor
final class FloatingPanel: NSPanel {
    var panelID: UUID = UUID()
    var onClose: ((UUID) -> Void)?

    init(contentView: NSView, size: NSSize) {
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            // Borderless: no system traffic lights floating over clear chrome.
            // Resizable from edges/corners. Custom close lives in WidgetContainer.
            styleMask: [.nonactivatingPanel, .borderless, .resizable, .fullSizeContentView],
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
        minSize = NSSize(width: 200, height: 140)
        maxSize = NSSize(width: 900, height: 900)
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
}

extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
