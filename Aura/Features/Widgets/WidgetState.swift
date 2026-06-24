import Observation

@Observable
final class WidgetState {
    var opacity: Double
    var blurIntensity: Double
    var isPinned: Bool
    var isPresented: Bool

    init() {
        opacity = DataStore.shared.double(for: .defaultOpacity, default: 1.0)
        blurIntensity = DataStore.shared.double(for: .defaultBlur, default: 0.5)
        isPinned = DataStore.shared.bool(for: .defaultPin, default: false)
        isPresented = false
    }
}
