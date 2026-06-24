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

        viewModel.onTogglePlayPause = { [weak self] in
            LocalAudioManager.shared.togglePlayPause()
            self?.refreshMediaInfo()
        }
        viewModel.onNextTrack = {
            NotificationCenter.default.post(name: .remoteNextTrack, object: nil)
        }
        viewModel.onPreviousTrack = {
            NotificationCenter.default.post(name: .remotePreviousTrack, object: nil)
        }

        startMousePolling()
        MediaTracker.shared.startTracking()
        MediaTracker.shared.onUpdate = { [weak self] info in
            guard let self else { return }
            if let info {
                let sourceInfo = MediaTracker.shared.sourceAppInfo()
                let source: NotchViewModel.MediaSource
                if let bundleID = sourceInfo?.bundleID {
                    source = .system(bundleID: bundleID)
                } else {
                    source = .local
                }
                viewModel.showMedia(
                    title: info.title,
                    artist: info.artist,
                    isPlaying: info.isPlaying,
                    progress: info.duration > 0 ? info.elapsedTime / info.duration : 0,
                    duration: info.duration,
                    source: source,
                    appName: sourceInfo?.name ?? "",
                    appIcon: sourceInfo?.icon
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

    private var hideDelay: Double {
        DataStore.shared.double(for: .notchHideDelay, default: 1.0)
    }

    private var extendHoverAmount: CGFloat {
        DataStore.shared.bool(for: .extendHoverArea, default: true) ? -40 : -12
    }

    private var openOnHoverEnabled: Bool {
        DataStore.shared.bool(for: .openNotchOnHover, default: true)
    }

    private func pollMousePosition() {
        guard openOnHoverEnabled else { return }
        let mouseLocation = NSEvent.mouseLocation
        let checkRect = viewModel.notchRect.insetBy(dx: extendHoverAmount, dy: extendHoverAmount)
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

    func openNotch() {
        isHovering = true
        hideWorkItem?.cancel()
        expand()
    }

    func closeNotch() {
        isHovering = false
        collapse()
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
        DispatchQueue.main.asyncAfter(deadline: .now() + hideDelay, execute: item)
    }

    private func collapse() {
        panel?.setIgnoresMouseEvents(true)
        viewModel.handleHoverExit()
        animatePanelFrame(viewModel.currentFrame)
    }

    private func animatePanelFrame(_ frame: CGRect) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.5
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            context.allowsImplicitAnimation = true
            panel?.animator().setFrame(frame, display: true)
        }
    }

    private func screenDidChange() {
        viewModel.updateFrames()
        animatePanelFrame(viewModel.currentFrame)
    }

    private func refreshMediaInfo() {
        let manager = LocalAudioManager.shared
        if let url = manager.currentURL {
            viewModel.showMedia(
                title: url.deletingPathExtension().lastPathComponent,
                artist: "Local File",
                isPlaying: manager.isPlaying,
                progress: manager.duration > 0 ? manager.currentTime / manager.duration : 0,
                duration: manager.duration,
                source: .local,
                appName: "Local File"
            )
        }
    }
}
