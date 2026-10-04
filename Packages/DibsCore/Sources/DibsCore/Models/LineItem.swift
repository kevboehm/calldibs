import Foundation

public struct LineItem: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public var name: String
    public var unitPrice: Decimal

    /// Claimable units. Always at least 1. Shrinking it below what is already
    /// claimed clears the claims rather than guessing whose to cut.
    public var quantity: Int {
        didSet {
            quantity = max(1, quantity)
            if totalClaimed > quantity { claims.removeAll() }
        }
    }

    /// True when the units are equal shares of one thing (a seafood tower
    /// split five ways) rather than separate things (five beers).
    public private(set) var isSplit: Bool

    /// Units claimed, per person. Never holds zero entries and never adds up
    /// to more than `quantity`.
    public private(set) var claims: [Person.ID: Int] = [:]

    public init(
        id: UUID = UUID(),
        name: String,
        unitPrice: Decimal,
        quantity: Int = 1,
        isSplit: Bool = false
    ) {
        self.id = id
        self.name = name
        self.unitPrice = unitPrice
        self.quantity = max(1, quantity)
        self.isSplit = isSplit
    }

    public var isMultiUnit: Bool { quantity > 1 }
    public var lineTotal: Decimal { unitPrice * Decimal(quantity) }

    // MARK: - Claims

    public var totalClaimed: Int { claims.values.reduce(0, +) }
    public var unclaimedQuantity: Int { quantity - totalClaimed }
    public var unclaimedTotal: Decimal { unitPrice * Decimal(unclaimedQuantity) }

    public func claimedQuantity(by person: Person.ID) -> Int {
        claims[person] ?? 0
    }

    public func claimedTotal(by person: Person.ID) -> Decimal {
        unitPrice * Decimal(claimedQuantity(by: person))
    }

    /// Units this person could hold: everything other people haven't claimed.
    public func availableQuantity(for person: Person.ID) -> Int {
        unclaimedQuantity + claimedQuantity(by: person)
    }

    /// Sets this person's claim, kept within 0...availableQuantity(for:).
    public mutating func setClaimed(_ units: Int, by person: Person.ID) {
        let clamped = min(max(0, units), availableQuantity(for: person))
        claims[person] = clamped > 0 ? clamped : nil
    }

    public mutating func removeClaims(by person: Person.ID) {
        claims[person] = nil
    }

    // MARK: - Splitting

    /// Divides the item into equal shares that are claimed like units, keeping
    /// the line total. `split(into: 1)` undoes a split. Existing claims are
    /// cleared because they were counted in the old shares.
    public mutating func split(into parts: Int) {
        let total = lineTotal
        let parts = max(1, parts)
        claims.removeAll()
        quantity = parts
        unitPrice = total / Decimal(parts)
        isSplit = parts > 1
    }
}
