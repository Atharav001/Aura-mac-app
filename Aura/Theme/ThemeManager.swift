import SwiftUI

enum ThemeTime: Equatable, CaseIterable {
    case dawn
    case morning
    case afternoon
    case sunset
    case night

    var accentColor: Color {
        switch self {
        case .dawn: return Color(red: 1.0, green: 0.6, blue: 0.3)
        case .morning: return Color(red: 1.0, green: 0.75, blue: 0.4)
        case .afternoon: return Color(red: 0.5, green: 0.7, blue: 1.0)
        case .sunset: return Color(red: 1.0, green: 0.4, blue: 0.3)
        case .night: return Color(red: 0.3, green: 0.5, blue: 1.0)
        }
    }

    var glassOpacity: Double {
        switch self {
        case .dawn, .sunset: return 0.18
        case .morning, .afternoon: return 0.12
        case .night: return 0.22
        }
    }

    var displayName: String {
        switch self {
        case .dawn: return "Dawn"
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .sunset: return "Sunset"
        case .night: return "Night"
        }
    }
}

enum AccentTheme: String, CaseIterable, Equatable {
    case auto
    case synthwave
    case tokyoNight

    var accentColor: Color {
        switch self {
        case .auto:
            return ThemeManager.shared.currentTheme.accentColor
        case .synthwave:
            return Color(red: 1.0, green: 0.2, blue: 0.6)
        case .tokyoNight:
            return Color(red: 0.5, green: 0.7, blue: 1.0)
        }
    }

    var glassOpacity: Double {
        switch self {
        case .auto:
            return ThemeManager.shared.currentTheme.glassOpacity
        case .synthwave:
            return 0.2
        case .tokyoNight:
            return 0.18
        }
    }

    var displayName: String {
        switch self {
        case .auto: return "Auto (Time of Day)"
        case .synthwave: return "Synthwave"
        case .tokyoNight: return "Tokyo Night"
        }
    }
}

@MainActor @Observable
final class AppSettingsManager {
    static let shared = AppSettingsManager()

    var glassmorphismEnabled: Bool = true
    var accentHex: String = "#007AFF"
    var accentColor: Color = .blue
    var notchStyle: String = "melted"

    // Reactive settings observed by NotchView and other views
    var showBatteryInNotch: Bool = true
    var showBatteryPercentage: Bool = true
    var showChargingIndicator: Bool = true
    var showMediaControls: Bool = true
    var settingsIconInNotch: Bool = true
    var windowShadow: Bool = true
    var openNotchOnHover: Bool = true
    var enableHaptics: Bool = true
    var simpleCloseAnim: Bool = true
    var playerTinting: Bool = true
    var blurBehindAlbum: Bool = true
    var coloredSpectrograms: Bool = true

    private init() {
        reload()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadFromNotification),
            name: .settingsDidChange,
            object: nil
        )
    }

    @objc private func reloadFromNotification() {
        reload()
    }

    func reload() {
        glassmorphismEnabled = DataStore.shared.bool(for: .glassmorphismEnabled, default: true)
        accentHex = DataStore.shared.string(for: .accentColor) ?? "#007AFF"
        accentColor = Color(hex: accentHex) ?? .blue
        notchStyle = DataStore.shared.string(for: .notchStyle) ?? "melted"

        showBatteryInNotch = DataStore.shared.bool(for: .showBatteryInNotch, default: true)
        showBatteryPercentage = DataStore.shared.bool(for: .showBatteryPercentage, default: true)
        showChargingIndicator = DataStore.shared.bool(for: .showChargingIndicator, default: true)
        showMediaControls = DataStore.shared.bool(for: .showMediaControls, default: true)
        settingsIconInNotch = DataStore.shared.bool(for: .settingsIconInNotch, default: true)
        windowShadow = DataStore.shared.bool(for: .windowShadow, default: true)
        openNotchOnHover = DataStore.shared.bool(for: .openNotchOnHover, default: true)
        enableHaptics = DataStore.shared.bool(for: .enableHaptics, default: true)
        simpleCloseAnim = DataStore.shared.bool(for: .simpleCloseAnim, default: true)
        playerTinting = DataStore.shared.bool(for: .playerTinting, default: true)
        blurBehindAlbum = DataStore.shared.bool(for: .blurBehindAlbum, default: true)
        coloredSpectrograms = DataStore.shared.bool(for: .coloredSpectrograms, default: true)
    }

    func saveAndNotify(glassmorphism: Bool? = nil, accentHex: String? = nil, notchStyle: String? = nil) {
        if let g = glassmorphism {
            DataStore.shared.set(key: .glassmorphismEnabled, value: g)
        }
        if let h = accentHex {
            DataStore.shared.set(key: .accentColor, value: h)
        }
        if let n = notchStyle {
            DataStore.shared.set(key: .notchStyle, value: n)
        }
        reload()
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }
}

// Time-based theme
final class ThemeManager: @unchecked Sendable {
    static let shared = ThemeManager()

    var selectedTheme: AccentTheme = .auto

    var currentTheme: ThemeTime {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<7: return .dawn
        case 7..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<20: return .sunset
        default: return .night
        }
    }

    var accentColor: Color { selectedTheme.accentColor }
    var glassOpacity: Double { selectedTheme.glassOpacity }
}

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard hex.count == 6 else { return nil }
        var int = UInt64()
        guard Scanner(string: hex).scanHexInt64(&int) else { return nil }
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

extension Notification.Name {
    static let settingsDidChange = Notification.Name("com.aura.settingsDidChange")
}
