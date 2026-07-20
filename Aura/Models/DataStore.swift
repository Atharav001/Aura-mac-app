import Foundation

struct LastTrackInfo: Codable {
    var title: String
    var artist: String
    var sourceBundleID: String?
    var sourceAppName: String
    var appIconData: Data?
}

struct PersistedClipboardItem: Codable, Identifiable, Equatable {
    var id: UUID
    var text: String
    var imageData: Data?
    var sourceApp: String
    var timestamp: Date
    var isPinned: Bool

    init(id: UUID = UUID(), text: String, imageData: Data? = nil, sourceApp: String, timestamp: Date = Date(), isPinned: Bool = false) {
        self.id = id
        self.text = text
        self.imageData = imageData
        self.sourceApp = sourceApp
        self.timestamp = timestamp
        self.isPinned = isPinned
    }
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
    private var _clipboardItems: [PersistedClipboardItem] = []
    private var _shelfPaths: [String] = []

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

    var clipboardItems: [PersistedClipboardItem] {
        get { lock.withLock { _clipboardItems } }
        set { lock.withLock { _clipboardItems = newValue } }
    }

    var shelfPaths: [String] {
        get { lock.withLock { _shelfPaths } }
        set { lock.withLock { _shelfPaths = newValue } }
    }

    private init() {
        load()
        pruneClipboardHistory()
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

    func saveClipboard(_ items: [PersistedClipboardItem]) {
        clipboardItems = items
        save()
    }

    func saveShelf(_ urls: [URL]) {
        shelfPaths = urls.map(\.path)
        save()
    }

    /// Keep pinned forever; drop unpinned older than 7 days.
    func pruneClipboardHistory() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date.distantPast
        let pruned = clipboardItems.filter { $0.isPinned || $0.timestamp >= cutoff }
        if pruned.count != clipboardItems.count {
            clipboardItems = pruned
            save()
        }
    }

    func save() {
        let data: StoredData = lock.withLock {
            StoredData(
                todoItems: _todoItems,
                settings: _settings,
                lastTrack: _lastTrack,
                clipboardItems: _clipboardItems,
                shelfPaths: _shelfPaths
            )
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
            _clipboardItems = decoded.clipboardItems ?? []
            _shelfPaths = decoded.shelfPaths ?? []
        }
    }

    private struct StoredData: Codable {
        let todoItems: [TodoItem]
        let settings: [AppSettings]
        let lastTrack: LastTrackInfo?
        var clipboardItems: [PersistedClipboardItem]?
        var shelfPaths: [String]?
    }
}
