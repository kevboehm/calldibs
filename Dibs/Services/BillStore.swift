import UIKit

/// Keeps the bill in progress on disk so it outlives the app being closed.
enum BillStore {
    private static var file: URL {
        URL.applicationSupportDirectory.appending(path: "BillInProgress.plist")
    }

    /// The photo the bill was scanned from.
    private static var scanFile: URL {
        URL.applicationSupportDirectory.appending(path: "BillScan.jpg")
    }

    /// Writes the bill, or clears it when there is none to keep.
    static func save(_ data: Data?) {
        guard let data else {
            clear()
            return
        }
        try? FileManager.default.createDirectory(at: .applicationSupportDirectory, withIntermediateDirectories: true)
        try? data.write(to: file, options: .atomic)
    }

    static func load() -> Data? {
        try? Data(contentsOf: file)
    }

    static func saveScan(_ image: UIImage) {
        try? FileManager.default.createDirectory(at: .applicationSupportDirectory, withIntermediateDirectories: true)
        try? image.jpegData(compressionQuality: 0.8)?.write(to: scanFile, options: .atomic)
    }

    static func loadScan() -> UIImage? {
        UIImage(contentsOfFile: scanFile.path)
    }

    /// Removes the bill and its photo.
    static func clear() {
        try? FileManager.default.removeItem(at: file)
        try? FileManager.default.removeItem(at: scanFile)
    }
}
