import Foundation
import DibsCore

extension LineItem {
    var displayName: String { name.isEmpty ? "Item" : name }

    /// "share" for a split item, "each" for separate units.
    func unitPriceLabel(_ money: Money) -> String {
        "\(money.string(unitPrice.roundedToCents())) \(isSplit ? "per share" : "each")"
    }

    /// What nobody has claimed: "Salad", "2 × Burger", or "3/5 of Seafood Tower".
    var unclaimedLabel: String {
        if isSplit { return "\(unclaimedQuantity)/\(quantity) of \(displayName)" }
        return unclaimedQuantity > 1 ? "\(unclaimedQuantity) × \(displayName)" : displayName
    }
}

extension ShareSummary {
    /// The person's tip as a whole percentage.
    var tipPercent: Int {
        NSDecimalNumber(decimal: person.tip.rate * 100).intValue
    }

    /// What sits on top of the items: tax, each charge, and the tip if any.
    var extras: [(label: String, amount: Decimal)] {
        [("Tax", taxShare)]
            + chargeShares.map { ($0.name, $0.amount) }
            // A tip already on the bill is one of the charges above.
            + (tip == 0 ? [] : [("Tip (\(tipPercent)%)", tip)])
    }

    /// The items, then the extras: every line that makes up `total`.
    var breakdown: [(label: String, amount: Decimal)] {
        lines.map { ($0.label, $0.amount) } + extras
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
