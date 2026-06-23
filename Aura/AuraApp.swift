import SwiftUI

@main
struct AuraApp: App {
    init() {
        _ = DataStore.shared
        DispatchQueue.main.async {
            AuraApp.spawnTestWindow()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
    }

    private static func spawnTestWindow() {
        PanelManager.shared.spawnPanel(
            size: NSSize(width: 340, height: 480),
            position: CGPoint(x: 100, y: 400)
        ) {
            VStack(spacing: 24) {
                Image(systemName: "sparkles")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.white)

                Text("Aura")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)

                Text("Dynamic Island · Floating Widgets · Menu Bar")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.white.opacity(0.6))

                Divider()
                    .background(.white.opacity(0.2))
                    .padding(.horizontal, 40)

                Text("Phase 1 Foundation Complete")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))

                HStack(spacing: 16) {
                    Label("FloatingPanel", systemImage: "rectangle.on.rectangle")
                        .font(.system(size: 11))
                    Label("PanelManager", systemImage: "rectangle.3.group")
                        .font(.system(size: 11))
                }
                .foregroundStyle(.white.opacity(0.5))
            }
            .padding(32)
            .glassmorphic(opacity: 0.2, blurRadius: 40)
        }
    }
}

struct ContentView: View {
    var body: some View {
        Text("Aura")
            .frame(width: 200, height: 200)
    }
}
