import Observation

@Observable
final class WidgetState {
    var opacity: Double = 0.85
    var isPinned: Bool = false
    var isPresented: Bool = false
}
