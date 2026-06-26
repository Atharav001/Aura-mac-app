import AppKit
import SwiftUI
import Cocoa
import IOKit.pwr_mgt
import CoreAudio
import MediaPlayer

@MainActor
final class NotchManager {
    static let shared = NotchManager()

    let viewModel = NotchViewModel()
    private var panel: NotchPanel?
    private var hoverTimer: Timer?
    private var isHovering = false
    private var hideWorkItem: DispatchWorkItem?
    private var expandWorkItem: DispatchWorkItem?
    private var screenChangeObserver: NSObjectProtocol?
    private var systemHUDMonitor: NSObjectProtocol?
    private var swipeMonitor: NSObjectProtocol?

    private init() {}

    func setup() {
        viewModel.updateFrames()
        guard viewModel.notchRect != .zero else { return }

        let hostingView = NSHostingView(rootView: NotchView(viewModel: viewModel))
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.wantsLayer = true

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
        setupMiddleClickHandler()
        setupSystemHUDMonitoring()
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
            Task { @MainActor in self.screenDidChange() }
        }
    }

    private func setupMiddleClickHandler() {
        NSEvent.addGlobalMonitorForEvents(matching: .otherMouseDown) { [weak self] event in
            guard let self, event.buttonNumber == 2 else { return }
            let action = DataStore.shared.string(for: .middleClickAction) ?? "Cycle states"
            switch action {
            case "Cycle states":
                Task { @MainActor in
                    if self.viewModel.state == .collapsed {
                        self.openNotch()
                    } else {
                        self.closeNotch()
                    }
                }
            case "Toggle play/pause":
                NotificationCenter.default.post(name: .remoteTogglePlayPause, object: nil)
            default: break
            }
        }
    }

    // MARK: - System HUD Monitoring (Volume, Brightness)

    private func setupSystemHUDMonitoring() {
        guard DataStore.shared.bool(for: .replaceSystemHUD, default: false) else { return }

        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.systemVolumesDidChange"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateVolumeHUD()
        }

        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.settings.brightnessChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateBrightnessHUD()
        }

        NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self,
                  DataStore.shared.bool(for: .enableGestures, default: false) else { return }
            let mouse = NSEvent.mouseLocation
            let notch = viewModel.notchRect
            if notch.insetBy(dx: -20, dy: -20).contains(mouse) {
                if event.modifierFlags.contains(.option) {
                    adjustBrightness(delta: event.deltaY > 0 ? 0.05 : -0.05)
                } else if event.modifierFlags.isEmpty || event.modifierFlags.contains(.shift) {
                    adjustVolume(delta: event.deltaY > 0 ? 0.05 : -0.05)
                }
            }
        }
    }

    private func updateVolumeHUD() {
        var volume: Float = 0.5
        var defaultOutput: AudioDeviceID = 0
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &propertySize, &defaultOutput) == noErr {
            var vol: Float32 = 0
            var volSize = UInt32(MemoryLayout<Float32>.size)
            var volAddr = AudioObjectPropertyAddress(
                mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            if AudioObjectGetPropertyData(defaultOutput, &volAddr, 0, nil, &volSize, &vol) == noErr {
                volume = vol
            }
        }
        viewModel.systemHUDVolume = volume
        viewModel.systemHUDType = .volume
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if viewModel.systemHUDType == .volume {
                viewModel.systemHUDType = nil
            }
        }
    }

    private func updateBrightnessHUD() {
        var brightness: Float = 0.7
        let service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IODisplayConnect"))
        if service != 0 {
            if let info = IODisplayCreateInfoDictionary(service, UInt32(kIODisplayOnlyPreferredName)).takeRetainedValue() as? [String: Any],
               let brightnessVal = info["IODisplayBrightness"] as? Float {
                brightness = brightnessVal
            }
            IOObjectRelease(service)
        }
        viewModel.systemHUDBrightness = brightness
        viewModel.systemHUDType = .brightness
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if viewModel.systemHUDType == .brightness {
                viewModel.systemHUDType = nil
            }
        }
    }

    private func adjustVolume(delta: Float) {
        var defaultOutput: AudioDeviceID = 0
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &propertySize, &defaultOutput) == noErr else { return }

        var currentVol: Float32 = 0
        var volSize = UInt32(MemoryLayout<Float32>.size)
        var volAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(defaultOutput, &volAddr, 0, nil, &volSize, &currentVol)

        let newVolume = max(0, min(1, currentVol + delta))
        var mutableVolume = newVolume
        AudioObjectSetPropertyData(defaultOutput, &volAddr, 0, nil, volSize, &mutableVolume)
        viewModel.systemHUDVolume = newVolume
        viewModel.systemHUDType = .volume
    }

    private func adjustBrightness(delta: Float) {
        let newBrightness = max(0, min(1, viewModel.systemHUDBrightness + delta))
        viewModel.systemHUDBrightness = newBrightness
        viewModel.systemHUDType = .brightness
        let service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IODisplayConnect"))
        if service != 0 {
            IODisplaySetFloatParameter(service, 0, kIODisplayBrightnessKey as CFString, newBrightness)
            IOObjectRelease(service)
        }
    }

    // MARK: - Mouse Polling

    private func startMousePolling() {
        hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.pollMousePosition() }
        }
    }

    private var hideDelay: Double {
        DataStore.shared.double(for: .notchHideDelay, default: 1.0)
    }

    private var expandDelay: Double {
        DataStore.shared.double(for: .hoverExpandDelay, default: 0.0)
    }

    private var hoverInset: (dx: CGFloat, dy: CGFloat) {
        if DataStore.shared.bool(for: .extendHoverArea, default: true) {
            (-8, -8)
        } else {
            (0, 0)
        }
    }

    private var openOnHoverEnabled: Bool {
        DataStore.shared.bool(for: .openNotchOnHover, default: true)
    }

    private func pollMousePosition() {
        guard openOnHoverEnabled else { return }
        let mouseLocation = NSEvent.mouseLocation
        let inset = hoverInset
        let checkRect = viewModel.notchRect.insetBy(dx: inset.dx, dy: inset.dy)
        let isNearNotch = checkRect.contains(mouseLocation)

        let isOverExpanded = viewModel.state != .collapsed &&
            viewModel.expandedRect.insetBy(dx: 0, dy: -10).contains(mouseLocation)

        let isNear = isNearNotch || isOverExpanded

        if isNear && !isHovering {
            isHovering = true
            hideWorkItem?.cancel()
            scheduleExpand()
        } else if !isNear && isHovering {
            isHovering = false
            expandWorkItem?.cancel()
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
        animatePanelFrame(viewModel.currentFrame, springy: true)
    }

    private func scheduleExpand() {
        let delay = expandDelay
        if delay > 0 {
            expandWorkItem?.cancel()
            let item = DispatchWorkItem { [weak self] in
                guard let self, self.isHovering else { return }
                self.expand()
            }
            expandWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        } else {
            expand()
        }
    }

    private func scheduleCollapse() {
        hideWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.collapse() }
        hideWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + hideDelay, execute: item)
    }

    private func collapse() {
        panel?.setIgnoresMouseEvents(true)
        viewModel.handleHoverExit()
        animatePanelFrame(viewModel.currentFrame, springy: false)
    }

    private func animatePanelFrame(_ frame: CGRect, springy: Bool = true) {
        if springy && !DataStore.shared.bool(for: .disableOvershoot, default: false) {
            let animation = CASpringAnimation(keyPath: "frameOrigin")
            animation.damping = 12
            animation.stiffness = 180
            animation.mass = 1.2
            animation.initialVelocity = 5
            animation.duration = animation.settlingDuration * 0.8
            animation.fromValue = NSValue(point: panel?.frame.origin ?? .zero)
            animation.toValue = NSValue(point: frame.origin)
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel?.animations = ["frameOrigin": animation]

            let sizeAnimation = CASpringAnimation(keyPath: "frameSize")
            sizeAnimation.damping = 12
            sizeAnimation.stiffness = 180
            sizeAnimation.mass = 1.2
            sizeAnimation.initialVelocity = 5
            sizeAnimation.duration = animation.settlingDuration * 0.8
            sizeAnimation.fromValue = NSValue(size: panel?.frame.size ?? .zero)
            sizeAnimation.toValue = NSValue(size: frame.size)
            panel?.animations["frameSize"] = sizeAnimation
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = springy ? 0.6 : 0.35
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            context.allowsImplicitAnimation = true
            panel?.animator().setFrame(frame, display: true)
        }
    }

    private func screenDidChange() {
        viewModel.updateFrames()
        animatePanelFrame(viewModel.currentFrame, springy: false)
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

    deinit {
        NotificationCenter.default.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
    }
}
