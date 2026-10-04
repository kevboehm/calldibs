#if DEBUG
import SwiftUI
import UniformTypeIdentifiers
import DibsCore

/// One half of a parser fixture made from a scan the user has corrected: the
/// raw OCR output (`<name>.ocr.json`) or what the receipt really says
/// (`<name>.json`, in `dibs-eval`'s ground truth format). Debug builds only.
struct ScanFixture: Transferable {
    enum Part { case ocr, truth }

    let part: Part
    let name: String
    let receipt: Receipt
    let fragments: [TextFragment]

    var filename: String {
        part == .ocr ? "\(name).ocr.json" : "\(name).json"
    }

    static func pair(receipt: Receipt, scan: ScanSource) -> [ScanFixture] {
        let name = "receipt-\(receipt.id.uuidString.prefix(8).lowercased())"
        return [.ocr, .truth].map { ScanFixture(part: $0, name: name, receipt: receipt, fragments: scan.fragments) }
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { fixture in
            let url = URL.temporaryDirectory.appending(path: fixture.filename)
            try fixture.data().write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }

    private func data() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        switch part {
        case .ocr:
            return try encoder.encode(fragments)
        case .truth:
            return try encoder.encode(Truth(
                items: receipt.items.map {
                    Truth.Item(name: $0.name, quantity: $0.quantity, total: Self.number($0.lineTotal))
                },
                subtotal: Self.number(receipt.subtotal ?? receipt.itemsSubtotal),
                tax: Self.number(receipt.tax),
                total: Self.number(receipt.total ?? receipt.computedTotal)
            ))
        }
    }

    private static func number(_ amount: Decimal) -> Double {
        NSDecimalNumber(decimal: amount.roundedToCents()).doubleValue
    }

    /// Mirrors `GroundTruth` in DibsEval, which the app doesn't link.
    private struct Truth: Encodable {
        struct Item: Encodable {
            var name: String
            var quantity: Int
            var total: Double
        }

        var items: [Item]
        var subtotal: Double
        var tax: Double
        var total: Double
    }
}
#endif
