import Foundation
import SwiftUI

@Observable
final class MenuBarViewModel {
    var musicDirectory: URL?
    var mp3Files: [URL] = []
    var selectedMP3: URL?
    var isScanning = false
    var isPlaying = false

    private var currentScopeAccess: (url: URL, token: Data?)?

    func selectMusicDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select a folder containing MP3 files"
        panel.prompt = "Select Folder"
        panel.treatsFilePackagesAsDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        currentScopeAccess?.url.stopAccessingSecurityScopedResource()
        currentScopeAccess = (url, nil)

        let didStart = url.startAccessingSecurityScopedResource()
        if !didStart { currentScopeAccess = nil }

        musicDirectory = url
        scanMP3Files(in: url)
    }

    deinit {
        currentScopeAccess?.url.stopAccessingSecurityScopedResource()
    }

    func refreshAudioFiles() {
        guard let dir = musicDirectory else { return }
        scanMP3Files(in: dir)
    }

    func playMP3(_ url: URL) {
        selectedMP3 = url
        isPlaying = true
        NotificationCenter.default.post(name: .playAudioFile, object: url)
    }

    private func scanMP3Files(in directory: URL) {
        isScanning = true
        mp3Files = []

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let enumerator = FileManager.default.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            )

            var files: [URL] = []
            while let fileURL = enumerator?.nextObject() as? URL {
                if fileURL.pathExtension.lowercased() == "mp3" {
                    files.append(fileURL)
                }
            }
            files.sort { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

            let safeFiles = files
            Task { @MainActor in
                self.mp3Files = safeFiles
                self.isScanning = false
            }
        }
    }
}

extension Notification.Name {
    static let playAudioFile = Notification.Name("com.aura.playAudioFile")
}
