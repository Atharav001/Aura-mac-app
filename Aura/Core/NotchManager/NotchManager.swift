import AppKit
import SwiftUI

@MainActor
final class NotchManager {
    static let shared = NotchManager()

    let viewModel = NotchViewModel()
    private var panel: NotchPanel?
    private var hoverTimer: Timer?
    private var isHovering = false
    private var hideWorkItem: DispatchWorkItem?
    private var screenChangeObserver: NSObjectProtocol?

    private init() {}

    func setup() {
        viewModel.updateFrames()
        guard viewModel.notchRect != .zero else { return }

        let hostingView = NSHostingView(rootView: NotchView(viewModel: viewModel))
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        panel = NotchPanel(contentView: hostingView, rect: viewModel.collapsedRect)
        panel?.orderFront(nil)

        startMousePolling()
        MediaTracker.shared.startTracking()
        MediaTracker.shared.onUpdate = { [weak self] info in
            guard let self else { return }
            if let info {
                viewModel.showMedia(
                    title: info.title,
                    artist: info.artist,
                    isPlaying: info.isPlaying,
                    progress: info.duration > 0 ? info.elapsedTime / info.duration : 0,
                    duration: info.duration
                )
            } else {
                viewModel.hideMedia()
            }
        }

        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.screenDidChange()
            }
        }
    }

    private func startMousePolling() {
        hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.pollMousePosition()
            }
        }
    }

    private func pollMousePosition() {
        let mouseLocation = NSEvent.mouseLocation
        let checkRect = viewModel.expandedRect.insetBy(dx: -10, dy: -10)
        let isNear = checkRect.contains(mouseLocation)

        if isNear && !isHovering {
            isHovering = true
            hideWorkItem?.cancel()
            expand()
        } else if !isNear && isHovering {
            isHovering = false
            scheduleCollapse()
        }
    }

    private func expand() {
        panel?.setIgnoresMouseEvents(false)
        viewModel.handleHoverEnter()
        animatePanelFrame(viewModel.currentFrame)
    }

    private func scheduleCollapse() {
        hideWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.collapse()
        }
        hideWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: item)
    }

    private func collapse() {
        panel?.setIgnoresMouseEvents(true)
        viewModel.handleHoverExit()
        animatePanelFrame(viewModel.currentFrame)
    }

    private func animatePanelFrame(_ frame: CGRect) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.4
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel?.animator().setFrame(frame, display: true)
        }
    }

    private func screenDidChange() {
        viewModel.updateFrames()
        animatePanelFrame(viewModel.currentFrame)
    }
}
