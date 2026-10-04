import Foundation

/// Keeps finished splits on disk, one file each, newest first.
enum HistoryStore {
    /// The oldest are dropped beyond this many.
    private static let limit = 50

    private static var folder: URL {
        URL.applicationSupportDirectory.appending(path: "History")
    }

    private static func file(for id: SavedSplit.ID) -> URL {
        folder.appending(path: "\(id.uuidString).plist")
    }

    static var isEmpty: Bool {
        (try? FileManager.default.contentsOfDirectory(atPath: folder.path))?.isEmpty ?? true
    }

    /// Every kept split, newest first.
    static func all() -> [SavedSplit] {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return files
            .compactMap { try? Data(contentsOf: $0) }
            // A property list keeps Decimal amounts exact; JSON would not.
            .compactMap { try? PropertyListDecoder().decode(SavedSplit.self, from: $0) }
            .sorted { $0.date > $1.date }
    }

    static func find(_ id: SavedSplit.ID) -> SavedSplit? {
        guard let data = try? Data(contentsOf: file(for: id)) else { return nil }
        return try? PropertyListDecoder().decode(SavedSplit.self, from: data)
    }

    static func save(_ split: SavedSplit) {
        guard let data = try? PropertyListEncoder().encode(split) else { return }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? data.write(to: file(for: split.id), options: .atomic)
        for old in all().dropFirst(limit) { delete(old.id) }
    }

    static func delete(_ id: SavedSplit.ID) {
        try? FileManager.default.removeItem(at: file(for: id))
    }

    static func clear() {
        try? FileManager.default.removeItem(at: folder)
    }
}
