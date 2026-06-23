import Foundation

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

    var todoItems: [TodoItem] {
        get { lock.withLock { _todoItems } }
        set { lock.withLock { _todoItems = newValue } }
    }

    var settings: [AppSettings] {
        get { lock.withLock { _settings } }
        set { lock.withLock { _settings = newValue } }
    }

    private init() {
        load()
    }

    func save() {
        lock.withLock {
            let data = StoredData(todoItems: _todoItems, settings: _settings)
            if let encoded = try? JSONEncoder().encode(data) {
                try? encoded.write(to: fileURL, options: .atomic)
            }
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
        }
    }

    private struct StoredData: Codable {
        let todoItems: [TodoItem]
        let settings: [AppSettings]
    }
}
