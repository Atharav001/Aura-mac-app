import Foundation

// SwiftData Migration Guide
// -------------------------
// SwiftData @Model macro requires full Xcode (Command Line Tools cannot resolve
// SwiftDataMacros plugin). To migrate when Xcode is available:
//
// 1. Add 'import SwiftData' and 'import SwiftUI' to the target
// 2. Add '.modelContainer(for: [TodoItem.self, AppSettings.self])' to the WindowGroup
//    or Scene in AuraApp.swift
// 3. Replace 'struct TodoItem: Codable' with '@Model class TodoItem' and add
//    '@Attribute(.unique) var id: UUID'
// 4. Replace 'struct AppSettings: Codable' with '@Model class AppSettings'
// 5. Replace DataStore.shared usage with @Environment(\.modelContext) or
//    ModelContainer.shared.mainContext
// 6. Use FetchDescriptor / Predicate macros for queries
// 7. The JSON file at ~/Library/Application Support/aura_data.json can be migrated
//    by reading it one last time via DataStore.load() and inserting into the model
//    context via ModelContainer

struct LastTrackInfo: Codable {
    var title: String
    var artist: String
    var sourceBundleID: String?
    var sourceAppName: String
    var appIconData: Data?
}

final class DataStore: @unchecked Sendable {
    static let shared = DataStore()

    private let fileURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        return appSupport.appendingPathComponent("aura_data.json")
    }()

    private let lock = NSLock()

    private var _todoItems: [TodoItem] = []
    private var _settings: [AppSettings] = []
    private var _lastTrack: LastTrackInfo?

    var todoItems: [TodoItem] {
        get { lock.withLock { _todoItems } }
        set { lock.withLock { _todoItems = newValue } }
    }

    var settings: [AppSettings] {
        get { lock.withLock { _settings } }
        set { lock.withLock { _settings = newValue } }
    }

    var lastTrack: LastTrackInfo? {
        get { lock.withLock { _lastTrack } }
        set { lock.withLock { _lastTrack = newValue } }
    }

    private init() {
        load()
    }

    func setLastTrack(title: String, artist: String, sourceBundleID: String?, sourceAppName: String, appIconData: Data?) {
        let info = LastTrackInfo(
            title: title,
            artist: artist,
            sourceBundleID: sourceBundleID,
            sourceAppName: sourceAppName,
            appIconData: appIconData
        )
        lastTrack = info
        save()
    }

    func save() {
        let data: StoredData = lock.withLock {
            StoredData(todoItems: _todoItems, settings: _settings, lastTrack: _lastTrack)
        }
        if let encoded = try? JSONEncoder().encode(data) {
            try? encoded.write(to: fileURL, options: .atomic)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(StoredData.self, from: data) else {
            return
        }
        lock.withLock {
            _todoItems = decoded.todoItems
            _settings = decoded.settings
            _lastTrack = decoded.lastTrack
        }
    }

    private struct StoredData: Codable {
        let todoItems: [TodoItem]
        let settings: [AppSettings]
        let lastTrack: LastTrackInfo?
    }
}
