import UIKit
import DibsCore

/// Turns a receipt photo into a `Receipt`. The app only depends on this
/// protocol, so the OCR/parsing implementation can be swapped.
protocol ReceiptParser {
    func parse(image: UIImage) async throws -> ScannedReceipt
}

enum ReceiptParserError: LocalizedError {
    case unreadableImage

    var errorDescription: String? {
        switch self {
        case .unreadableImage: return "That image couldn't be read."
        }
    }
}
