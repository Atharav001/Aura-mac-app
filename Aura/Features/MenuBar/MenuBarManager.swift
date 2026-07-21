import AppKit
import SwiftUI

final class MenuBarManager: NSObject, @unchecked Sendable {
    static let shared = MenuBarManager()

    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let viewModel = MenuBarViewModel()
    private var eventMonitor: Any?

    private override init() {
        // Fixed width so the island logo stays an easy click target
        statusItem = NSStatusBar.system.statusItem(withLength: 28)
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 320, height: 420)

        super.init()

        configureStatusButton()
        configurePopover()
    }

    private func configureStatusButton() {
        guard let button = statusItem.button else { return }
        button.image = MenuBarIconFactory.makeIcon(size: 18)
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.toolTip = "Aura"
        button.target = self
        button.action = #selector(togglePopover(_:))
        button.sendAction(on: [.leftMouseUp])
        button.isEnabled = true
        let visible = DataStore.shared.bool(for: .menuBarIconVisible, default: true)
        button.isHidden = !visible
        statusItem.isVisible = visible
    }

    private func configurePopover() {
        let hostingController = NSHostingController(rootView: MenuBarView(viewModel: viewModel))
        hostingController.view.frame = NSRect(x: 0, y: 0, width: 320, height: 420)
        popover.contentViewController = hostingController
        popover.delegate = self
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            closePopover()
        } else {
            // Ensure content is attached (defensive — never lose the Command Center)
            if popover.contentViewController == nil {
                configurePopover()
            }
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            positionWithinScreen(button)
            startEventMonitor()
        }
    }

    private func startEventMonitor() {
        stopEventMonitor()
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover()
        }
    }

    private func stopEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
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
        stopEventMonitor()
        popover.performClose(nil)
    }

    func toggleIconVisibility(_ visible: Bool) {
        statusItem.isVisible = visible
        if let button = statusItem.button {
            button.isHidden = !visible
        }
    }
}

extension MenuBarManager: NSPopoverDelegate {
    func popoverWillShow(_ notification: Notification) {
        viewModel.refreshAudioFiles()
    }

    func popoverDidClose(_ notification: Notification) {
        stopEventMonitor()
    }

    func popoverShouldDetach(_ popover: NSPopover) -> Bool {
        false
    }
}
