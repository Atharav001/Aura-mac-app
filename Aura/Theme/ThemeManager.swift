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
