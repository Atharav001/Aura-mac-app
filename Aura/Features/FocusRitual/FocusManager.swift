import AppKit
import SwiftUI

@MainActor
final class FocusManager: @unchecked Sendable {
    static let shared = FocusManager()

    let viewModel = FocusViewModel()
    private var overlayPanel: NSPanel?

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStartPomodoro),
            name: .startPomodoro,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStartDeepWork),
            name: .startDeepWork,
            object: nil
        )
    }

    func setup() {}

    @objc private func handleStartPomodoro() {
        startFocus()
    }

    @objc private func handleStartDeepWork() {
        startFocus()
    }

    func startFocus() {
        guard !viewModel.isActive else { return }
        showOverlay()
        viewModel.startFocus()
    }

    func stopFocus() {
        viewModel.endFocus()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.hideOverlay()
        }
    }

    private func showOverlay() {
        guard overlayPanel == nil else { return }
        guard let screen = NSScreen.main else { return }
        let hostingView = NSHostingView(rootView: FocusOverlay(viewModel: viewModel))
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        let panel = NSPanel(
            contentRect: screen.frame,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = false
        panel.ignoresMouseEvents = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isReleasedWhenClosed = true
        panel.contentView = hostingView
        panel.orderFront(nil)

        overlayPanel = panel
    }

    private func hideOverlay() {
        overlayPanel?.close()
        overlayPanel = nil
    }
}
