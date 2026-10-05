import Foundation
import FoundationModels
import DibsCore

/// Reads OCR lines with the on-device language model. A second opinion for
/// receipts the rules in `ReceiptTextParser` could not make add up.
@available(iOS 26.0, macOS 26.0, *)
public enum LanguageModelReceiptParser {
    /// False on devices without Apple Intelligence, or with it switched off.
    public static var isAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    /// Why the model can't be used here, for `dibs-eval` to print.
    public static var availability: String {
        "\(SystemLanguageModel.default.availability)"
    }

    /// The model's reading, or nil when it is not better than `rules`: it
    /// must add up to its own total and use only amounts printed on the receipt.
    public static func improve(_ rules: Receipt, lines: [String]) async -> Receipt? {
        // Amounts are read the way the rules read them: "12,50" on a euro
        // receipt, whole numbers on a yen one.
        let format = PriceFormat(lines: lines, currencyCode: rules.currencyCode)
        guard isAvailable, rules.reconciles != true,
              var read = try? await parse(lines: lines, format: format) else { return nil }
        let printed = Set(lines.flatMap(format.amounts))
        guard read.reconciles == true, read.items.allSatisfy({ printed.contains($0.lineTotal) }) else { return nil }
        read.currencyCode = rules.currencyCode
        return read
    }

    public static func parse(lines: [String], format: PriceFormat = .standard) async throws -> Receipt {
        let session = LanguageModelSession(instructions: """
            You read the text of a restaurant receipt, one printed row per line, and list what was bought. \
            Copy names and amounts exactly as printed. Never invent or correct an amount.
            """)
        // The model's context is small; a receipt's items and totals fit well inside this.
        let text = lines.prefix(70).joined(separator: "\n")
        let read = try await session.respond(to: text, generating: ReadReceipt.self).content

        let items = read.items.compactMap { item -> LineItem? in
            guard let total = format.amount(item.lineTotal), total > 0 else { return nil }
            let quantity = max(1, item.quantity)
            return LineItem(name: item.name, unitPrice: total / Decimal(quantity), quantity: quantity)
        }
        return Receipt(
            items: items,
            tax: read.tax.flatMap(format.amount) ?? 0,
            subtotal: read.subtotal.flatMap(format.amount),
            total: read.total.flatMap(format.amount)
        )
    }
}

@available(iOS 26.0, macOS 26.0, *)
@Generable
private struct ReadReceipt {
    @Guide(description: "Each thing that was ordered, in printed order. Not the subtotal, tax, total, tip, payment or change lines.")
    var items: [ReadItem]
    @Guide(description: "The subtotal before tax, as printed, like 61.50")
    var subtotal: String?
    @Guide(description: "The tax amount, as printed, like 5.07")
    var tax: String?
    @Guide(description: "The total due before any tip, as printed, like 66.57")
    var total: String?
}

@available(iOS 26.0, macOS 26.0, *)
@Generable
private struct ReadItem {
    @Guide(description: "The item name without its quantity or price")
    var name: String
    @Guide(description: "How many were ordered. 1 unless the line says otherwise.")
    var quantity: Int
    @Guide(description: "The amount at the end of the line, as printed, like 19.00")
    var lineTotal: String
}
