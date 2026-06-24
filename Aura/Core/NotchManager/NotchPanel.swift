import AppKit

@MainActor
final class NotchPanel: NSPanel {
    init(contentView: NSView, rect: CGRect) {
        super.init(
            contentRect: rect,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovableByWindowBackground = false
        ignoresMouseEvents = true
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isReleasedWhenClosed = true
        self.contentView = contentView
    }

    func setIgnoresMouseEvents(_ flag: Bool) {
        ignoresMouseEvents = flag
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
