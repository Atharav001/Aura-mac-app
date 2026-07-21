import AppKit
import AVFoundation
import Foundation
import UniformTypeIdentifiers

/// Bundled + custom short alert tones for Pomodoro / countdown completion.
@MainActor
final class TimerAlertService {
    static let shared = TimerAlertService()

    struct Preset: Identifiable, Equatable {
        let id: String
        let displayName: String
        let fileName: String
    }

    static let presets: [Preset] = [
        .init(id: "glass", displayName: "Glass Bell", fileName: "bell-glass.aiff"),
        .init(id: "ping", displayName: "Ping", fileName: "bell-ping.aiff"),
        .init(id: "tink", displayName: "Tink", fileName: "bell-tink.aiff"),
        .init(id: "bottle", displayName: "Bottle", fileName: "bell-bottle.aiff"),
        .init(id: "soft", displayName: "Soft Chime", fileName: "bell-soft.aiff"),
    ]

    static let customPresetID = "custom"
    static let timerAttentionNotification = Notification.Name("com.aura.timerAttention")

    private var player: AVAudioPlayer?

    private init() {}

    var selectedPresetID: String {
        get {
            let id = DataStore.shared.string(for: .timerAlertSoundID) ?? "glass"
            if id == Self.customPresetID,
               let path = DataStore.shared.string(for: .timerAlertCustomPath),
               FileManager.default.fileExists(atPath: path) {
                return Self.customPresetID
            }
            if Self.presets.contains(where: { $0.id == id }) { return id }
            return "glass"
        }
        set { DataStore.shared.set(key: .timerAlertSoundID, value: newValue) }
    }

    var customSoundURL: URL? {
        guard let path = DataStore.shared.string(for: .timerAlertCustomPath),
              !path.isEmpty else { return nil }
        let url = URL(fileURLWithPath: path)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    var selectedDisplayName: String {
        if selectedPresetID == Self.customPresetID,
           let name = customSoundURL?.lastPathComponent {
            return name
        }
        return Self.presets.first(where: { $0.id == selectedPresetID })?.displayName ?? "Glass Bell"
    }

    func resolveSoundURL() -> URL? {
        if selectedPresetID == Self.customPresetID, let custom = customSoundURL {
            return custom
        }
        let fileName = Self.presets.first(where: { $0.id == selectedPresetID })?.fileName
            ?? Self.presets[0].fileName
        return bundledURL(named: fileName)
    }

    func playSelectedAlert(loop: Bool = false) {
        guard let url = resolveSoundURL() else {
            NSSound.beep()
            return
        }
        do {
            let audio = try AVAudioPlayer(contentsOf: url)
            audio.numberOfLoops = loop ? 2 : 0
            audio.prepareToPlay()
            audio.volume = 1.0
            audio.play()
            player = audio
        } catch {
            NSSound(contentsOf: url, byReference: true)?.play()
        }
    }

    func stop() {
        player?.stop()
        player = nil
    }

    func preview(presetID: String) {
        let url: URL?
        if presetID == Self.customPresetID {
            url = customSoundURL
        } else if let name = Self.presets.first(where: { $0.id == presetID })?.fileName {
            url = bundledURL(named: name)
        } else {
            url = nil
        }
        guard let url else {
            NSSound.beep()
            return
        }
        NSSound(contentsOf: url, byReference: true)?.play()
    }

    @discardableResult
    func pickCustomMP3() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.mp3, .wav, .aiff, .mpeg4Audio]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "Choose a timer alert sound"
        panel.message = "Pick a short MP3, WAV, or AIFF file"
        guard panel.runModal() == .OK, let url = panel.url else { return nil }

        // Copy into Application Support so the path stays valid
        let dir = customSoundsDirectory()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.removeItem(at: dest)
        do {
            try FileManager.default.copyItem(at: url, to: dest)
            DataStore.shared.set(key: .timerAlertCustomPath, value: dest.path)
            selectedPresetID = Self.customPresetID
            return dest
        } catch {
            DataStore.shared.set(key: .timerAlertCustomPath, value: url.path)
            selectedPresetID = Self.customPresetID
            return url
        }
    }

    /// Sound + visual attention pulse for any open timer widget.
    func announceTimerComplete(source: String = "timer", playSound: Bool = true) {
        if playSound {
            playSelectedAlert(loop: false)
        }
        NotificationCenter.default.post(
            name: Self.timerAttentionNotification,
            object: nil,
            userInfo: ["source": source]
        )
        NSApp.requestUserAttention(.informationalRequest)
    }

    private func bundledURL(named fileName: String) -> URL? {
        let base = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        let candidates: [URL?] = [
            Bundle.main.url(forResource: base, withExtension: ext),
            Bundle.main.url(forResource: base, withExtension: ext, subdirectory: "Sounds"),
            Bundle.main.resourceURL?.appendingPathComponent("Sounds").appendingPathComponent(fileName),
            Bundle.main.resourceURL?
                .appendingPathComponent("Aura_Aura.bundle")
                .appendingPathComponent("Sounds")
                .appendingPathComponent(fileName),
        ]
        return candidates.compactMap { $0 }.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    private func customSoundsDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("Aura/AlertSounds", isDirectory: true)
    }
}
