import AppKit
import SwiftUI

final class MenuBarManager: NSObject, @unchecked Sendable {
    static let shared = MenuBarManager()

    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let viewModel = MenuBarViewModel()

    private override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 360, height: 540)

        super.init()

        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Aura")
            image?.isTemplate = true
            button.image = image
            button.action = #selector(togglePopover)
            button.target = self
        }

        let hostingController = NSHostingController(rootView: MenuBarView(viewModel: viewModel))
        popover.contentViewController = hostingController
        popover.delegate = self
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            positionWithinScreen(sender)
        }
    }

    private func positionWithinScreen(_ sender: NSView) {
        guard let popoverWindow = popover.contentViewController?.view.window,
              let screenFrame = NSScreen.main?.visibleFrame else { return }

        var frame = popoverWindow.frame
        let maxX = screenFrame.maxX - frame.width - 8
        if frame.maxX > screenFrame.maxX {
            frame.origin.x = maxX
        }
        if frame.minY < screenFrame.minY {
            frame.origin.y = screenFrame.minY + 4
        }
        popoverWindow.setFrame(frame, display: true)
    }

    func closePopover() {
        popover.performClose(nil)
    }
}

extension MenuBarManager: NSPopoverDelegate {
    func popoverWillShow(_ notification: Notification) {
        viewModel.refreshAudioFiles()
    }
}
