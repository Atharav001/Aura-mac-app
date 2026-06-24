import AppKit
import SwiftUI

@MainActor
final class FloatingPanel: NSPanel {
    init(contentView: NSView, size: NSSize) {
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isMovableByWindowBackground = true
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isReleasedWhenClosed = true
        self.contentView = contentView
    }

    convenience init(rootView: some View, size: NSSize) {
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        self.init(contentView: hostingView, size: size)
    }

    func setIgnoresMouseEvents(_ flag: Bool) {
        self.ignoresMouseEvents = flag
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
