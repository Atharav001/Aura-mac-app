import AppKit
import Combine
import SwiftUI

// MARK: - Boring Notch integration shims
// Real BN relies on Sparkle / Lottie / SkyLight / XPC helper / MacroVisionKit.
// Aura keeps the notch UI and routes optional features through these stand-ins.

@MainActor
enum SettingsWindowController {
    static let shared = SettingsWindowControllerProxy()
}

@MainActor
final class SettingsWindowControllerProxy {
    func showWindow() {
        PanelManager.shared.openSettingsWindow()
    }

    func setUpdaterController(_ controller: Any?) {}
}

struct LottieView: View {
    var url: URL? = nil
    var speed: CGFloat = 1
    var loopMode: Int = 0

    var body: some View {
        Color.clear.frame(width: 1, height: 1)
    }
}

struct LottieAnimationContainer: View {
    var body: some View { Color.clear }
}

/// Stub fullscreen detector (MacroVisionKit excluded from SPM build).
final class FullscreenMediaDetector: ObservableObject {
    static let shared = FullscreenMediaDetector()
    @Published var fullscreenStatus: [String: Bool] = [:]
    private init() {}
}

/// No-op XPC helper (brightness / accessibility privileged ops).
final class XPCHelperClient {
    static let shared = XPCHelperClient()

    func stopMonitoringAccessibilityAuthorization() {}
    func startMonitoringAccessibilityAuthorization() {}
    func requestAccessibilityAuthorization() {}

    func ensureAccessibilityAuthorization(promptIfNeeded: Bool) async -> Bool { true }
    func isAccessibilityAuthorized() async -> Bool { true }

    func currentScreenBrightness() async -> Float? { nil }
    func setScreenBrightness(_ value: Float) async -> Bool { false }
    func currentKeyboardBrightness() async -> Float? { nil }
    func setKeyboardBrightness(_ value: Float) async -> Bool { false }
}

@objc protocol BoringNotchXPCHelperProtocol {}

// Notifications that live on BN's AppDelegate in upstream — kept here for Aura host.
extension Notification.Name {
    static let selectedScreenChanged = Notification.Name("SelectedScreenChanged")
    static let notchHeightChanged = Notification.Name("NotchHeightChanged")
    static let showOnAllDisplaysChanged = Notification.Name("showOnAllDisplaysChanged")
    static let expandedDragDetectionChanged = Notification.Name("expandedDragDetectionChanged")
    static let automaticallySwitchDisplayChanged = Notification.Name("automaticallySwitchDisplayChanged")
    static let accessibilityAuthorizationChanged = Notification.Name("accessibilityAuthorizationChanged")
}
