import Foundation
import DibsCore

extension LineItem {
    var displayName: String { name.isEmpty ? "Item" : name }

    /// "share" for a split item, "each" for separate units.
    var unitPriceLabel: String {
        "\(Money.string(unitPrice.roundedToCents())) \(isSplit ? "per share" : "each")"
    }
}

extension ClaimedLine {
    /// "Salad", "3 × Burger", or "1/5 of Seafood Tower".
    var label: String {
        let name = name.isEmpty ? "Item" : name
        if isSplit { return "\(quantity)/\(outOf) of \(name)" }
        return quantity > 1 ? "\(quantity) × \(name)" : name
    }
}
