import AppKit
import SwiftUI

/// Makes an NSWindow draggable from a SwiftUI region (needed when the titlebar is transparent).
struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = DragRegionView()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class DragRegionView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}
