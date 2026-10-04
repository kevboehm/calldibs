import Foundation

enum DebugLog {
    /// Prints the raw OCR lines in debug builds so the parser can be tuned.
    static func ocr(_ lines: [String]) {
        #if DEBUG
        print("---- OCR: \(lines.count) lines ----")
        for line in lines { print(line) }
        print("---- end OCR ----")
        #endif
    }
}
