import Foundation

/// Pure money math for one person's share of a receipt.
public enum ShareCalculator {
    public static func claimedSubtotal(of receipt: Receipt, by person: Person.ID) -> Decimal {
        receipt.items.reduce(0) { $0 + $1.claimedTotal(by: person) }
    }

    /// Tax allocated in proportion to the claimed subtotal. Unrounded.
    public static func taxShare(of receipt: Receipt, by person: Person.ID) -> Decimal {
        let base = receipt.preTaxSubtotal
        guard base > 0 else { return 0 }
        return receipt.tax * (claimedSubtotal(of: receipt, by: person) / base)
    }

    /// Each service charge, fee or discount, allocated like tax: in proportion
    /// to the claimed subtotal. Rounded to the bill's smallest unit.
    public static func chargeShares(of receipt: Receipt, by person: Person.ID) -> [ChargeShare] {
        let base = receipt.preTaxSubtotal
        guard base > 0 else { return [] }
        let fraction = claimedSubtotal(of: receipt, by: person) / base
        return receipt.charges.compactMap { charge in
            let amount = (charge.amount * fraction).rounded(toPlaces: receipt.fractionDigits)
            return amount == 0 ? nil : ChargeShare(id: charge.id, name: charge.name, amount: amount)
        }
    }

    /// Tip on the configured base. Unrounded.
    public static func tip(claimedSubtotal: Decimal, taxShare: Decimal, config: TipConfig) -> Decimal {
        switch config.base {
        case .postTax: return (claimedSubtotal + taxShare) * config.rate
        case .preTax: return claimedSubtotal * config.rate
        }
    }

    public static func summary(for receipt: Receipt, person: Person) -> ShareSummary {
        // Cents, or whole yen: each row is rounded as it will be shown, so
        // the rows add up to the total.
        let places = receipt.fractionDigits
        let lines = receipt.items.compactMap { item -> ClaimedLine? in
            let claimed = item.claimedQuantity(by: person.id)
            guard claimed > 0 else { return nil }
            return ClaimedLine(
                id: item.id,
                name: item.name,
                quantity: claimed,
                outOf: item.quantity,
                isSplit: item.isSplit,
                amount: item.claimedTotal(by: person.id).rounded(toPlaces: places)
            )
        }
        let subtotal = claimedSubtotal(of: receipt, by: person.id).rounded(toPlaces: places)
        let tax = taxShare(of: receipt, by: person.id).rounded(toPlaces: places)
        let charges = chargeShares(of: receipt, by: person.id)
        // Tip is on food and tax; charges and fees are not tipped on.
        let tip = tip(claimedSubtotal: subtotal, taxShare: tax, config: person.tip).rounded(toPlaces: places)
        return ShareSummary(
            person: person,
            lines: lines,
            claimedSubtotal: subtotal,
            taxShare: tax,
            chargeShares: charges,
            tip: tip,
            total: subtotal + tax + charges.reduce(0) { $0 + $1.amount } + tip
        )
    }
}

extension Decimal {
    public func roundedToCents() -> Decimal {
        rounded(toPlaces: 2)
    }

    public func rounded(toPlaces places: Int) -> Decimal {
        var value = self
        var result = Decimal()
        NSDecimalRound(&result, &value, places, .plain)
        return result
    }
}
