import Foundation

/// One claimed item on a person's mini receipt.
public struct ClaimedLine: Identifiable, Hashable, Sendable {
    /// The line item's id.
    public let id: UUID
    public let name: String
    /// Units (or shares) this person claimed, out of `outOf`.
    public let quantity: Int
    public let outOf: Int
    public let isSplit: Bool
    public let amount: Decimal

    public init(id: UUID, name: String, quantity: Int, outOf: Int, isSplit: Bool, amount: Decimal) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.outOf = outOf
        self.isSplit = isSplit
        self.amount = amount
    }
}

/// One person's part of a service charge, fee or discount.
public struct ChargeShare: Identifiable, Hashable, Sendable {
    /// The charge's id.
    public let id: UUID
    public let name: String
    public let amount: Decimal

    public init(id: UUID, name: String, amount: Decimal) {
        self.id = id
        self.name = name
        self.amount = amount
    }
}

/// The "mini receipt": what one person owes and how it is composed.
/// Money values are rounded to cents and `total` is the sum of the parts shown.
public struct ShareSummary: Hashable, Sendable {
    public let person: Person
    public let lines: [ClaimedLine]
    public let claimedSubtotal: Decimal
    public let taxShare: Decimal
    public let chargeShares: [ChargeShare]
    public let tip: Decimal
    public let total: Decimal

    public init(
        person: Person,
        lines: [ClaimedLine],
        claimedSubtotal: Decimal,
        taxShare: Decimal,
        chargeShares: [ChargeShare] = [],
        tip: Decimal,
        total: Decimal
    ) {
        self.person = person
        self.lines = lines
        self.claimedSubtotal = claimedSubtotal
        self.taxShare = taxShare
        self.chargeShares = chargeShares
        self.tip = tip
        self.total = total
    }
}
