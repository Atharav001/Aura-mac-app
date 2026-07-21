import AppKit
import SwiftUI

/// NSHostingView that only captures mouse hits inside the Dynamic Island shape.
/// Transparent wings of the BN window otherwise block macOS menu-bar icons.
final class NotchPassThroughHostingView<Content: View>: NSHostingView<Content> {
    /// Return the hit-testable rect in view coordinates (origin bottom-left).
    var interactiveRectProvider: (() -> NSRect)?

    override func hitTest(_ point: NSPoint) -> NSView? {
        if let rect = interactiveRectProvider?(), !rect.contains(point) {
            return nil
        }
        return super.hitTest(point)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
