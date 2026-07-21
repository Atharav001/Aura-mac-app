import AppKit
import SwiftUI

@MainActor
final class FloatingPanel: NSPanel {
    var panelID: UUID = UUID()
    var onClose: ((UUID) -> Void)?

    init(contentView: NSView, size: NSSize) {
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
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
        contentMinSize = NSSize(width: 180, height: 150)
        minSize = NSSize(width: 180, height: 150)
        maxSize = NSSize(width: 900, height: 1100)
        self.contentView = contentView
        contentView.autoresizingMask = [.width, .height]
    }

    convenience init(rootView: some View, size: NSSize) {
        let hosting = NSHostingView(rootView: rootView)
        hosting.frame = NSRect(origin: .zero, size: size)
        // Critical: hosting must resize with the panel when dragging edges
        hosting.autoresizingMask = [.width, .height]
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
