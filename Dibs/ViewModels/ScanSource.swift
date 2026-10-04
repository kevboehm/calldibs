import UIKit
import DibsCore

/// Where on the photo the bill was read from, so each item can be checked
/// against the paper it came off.
struct ScanSource: Codable {
    /// Every printed row the OCR found, top to bottom.
    var rows: [OCRRow]
    /// The rows each item was read from.
    var itemRows: [LineItem.ID: [Int]]
    /// The raw OCR output, kept so a corrected scan can become a parser fixture.
    var fragments: [TextFragment]

    /// The least sure of the rows an item was read from. Nil when the item
    /// didn't come from the scan.
    func confidence(of item: LineItem.ID) -> Double? {
        itemRows[item]?.compactMap { rows.indices.contains($0) ? rows[$0].confidence : nil }.min()
    }

    /// The part of the photo an item was printed on, the full width of the
    /// receipt's text, in pixels with the origin at the top-left.
    func stripRect(for item: LineItem.ID, in size: CGSize) -> CGRect? {
        let source = (itemRows[item] ?? []).filter(rows.indices.contains).map { rows[$0] }
        guard let top = source.map({ $0.minY + $0.height }).max(),
              let bottom = source.map(\.minY).min(),
              let left = rows.map(\.minX).min(),
              let right = rows.map({ $0.minX + $0.width }).max() else { return nil }
        // Room above and below, so the row isn't shaved by a tilted photo.
        let margin = (top - bottom) * 0.35
        // The OCR measures from the bottom-left; images from the top-left.
        return CGRect(
            x: (left - 0.01) * size.width,
            y: (1 - top - margin) * size.height,
            width: (right - left + 0.02) * size.width,
            height: (top - bottom + 2 * margin) * size.height
        ).intersection(CGRect(origin: .zero, size: size))
    }
}

/// What a scan produces: the bill, the photo it was read from, and where on
/// the photo each item sits.
struct ScannedReceipt {
    var receipt: Receipt
    var scan: ScanSource
    var image: UIImage
}
