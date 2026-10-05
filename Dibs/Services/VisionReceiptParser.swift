import UIKit
import DibsCore
import DibsOCR
import DibsLLM

/// On-device OCR with Vision, then `ReceiptTextParser` for the text. When the
/// result doesn't add up, the on-device language model gets a second look.
struct VisionReceiptParser: ReceiptParser {
    func parse(image: UIImage) async throws -> ScannedReceipt {
        let (upright, fragments) = try await Task.detached(priority: .userInitiated) {
            // Turned the right way up first, so the positions the OCR reports
            // are positions in the picture that is kept.
            let upright = image.upright()
            guard let cgImage = upright.cgImage else { throw ReceiptParserError.unreadableImage }
            return (upright, try TextRecognizer.fragments(in: cgImage))
        }.value

        let rows = OCRRowGrouper.rows(from: fragments)
        let lines = rows.map(\.text)
        DebugLog.ocr(lines)

        let rules = ReceiptTextParser.parseWithSources(rows: rows)
        var receipt = rules.receipt
        var itemRows = rules.itemLines
        if let improved = await LanguageModelReceiptParser.improve(rules.receipt, lines: lines) {
            itemRows = Self.rows(for: improved, from: rules)
            receipt = improved
        }
        return ScannedReceipt(
            receipt: receipt,
            scan: ScanSource(rows: rows, itemRows: itemRows, fragments: fragments),
            image: upright
        )
    }

    /// The model doesn't say where it read each item, so an item borrows the
    /// rows of the rules' item with the same line total, when only one has it.
    private static func rows(
        for improved: Receipt,
        from rules: (receipt: Receipt, itemLines: [LineItem.ID: [Int]])
    ) -> [LineItem.ID: [Int]] {
        var rows: [LineItem.ID: [Int]] = [:]
        for item in improved.items {
            let matches = rules.receipt.items.filter { $0.lineTotal == item.lineTotal }
            if matches.count == 1, let lines = rules.itemLines[matches[0].id] {
                rows[item.id] = lines
            }
        }
        return rows
    }
}

private extension UIImage {
    /// The same picture with its pixels stored the right way up.
    func upright() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
