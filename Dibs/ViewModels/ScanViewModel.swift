import UIKit
import Observation
import DibsCore

@Observable
final class ScanViewModel {
    private let parser: ReceiptParser

    var isParsing = false
    var errorMessage: String?

    init(parser: ReceiptParser = VisionReceiptParser()) {
        self.parser = parser
    }

    /// Returns the scanned receipt, or nil after setting `errorMessage`.
    @MainActor
    func parse(_ image: UIImage) async -> ScannedReceipt? {
        isParsing = true
        defer { isParsing = false }

        do {
            let scanned = try await parser.parse(image: image)
            guard !scanned.receipt.items.isEmpty else {
                errorMessage = "No line items were found in that photo. Try a sharper, straight-on photo, or enter the items yourself."
                return nil
            }
            return scanned
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
