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

    /// Shares whatever nobody claimed equally among `people`, leaving the
    /// line total and everyone's existing claims worth what they were.
    ///
    /// Returns an item to list after this one when the leftovers had to be
    /// carved off: three beers with one left over stay "2 × Beer" for those
    /// who had a whole one, and the third becomes its own shared line.
    public mutating func shareUnclaimed(among people: [Person.ID]) -> LineItem? {
        let left = unclaimedQuantity
        let count = people.count
        guard left > 0, count > 0 else { return nil }

        if left % count == 0 {
            for person in people { claims[person, default: 0] += left / count }
            return nil
        }

        if isMultiUnit, !isSplit, totalClaimed > 0 {
            var rest = LineItem(name: name, unitPrice: unitPrice * Decimal(left))
            quantity -= left
            _ = rest.shareUnclaimed(among: people)
            return rest
        }

        // Cut every share into `count` smaller ones, so the leftovers divide
        // evenly, then reduce so the labels stay small: 1/3, not 5/15.
        let total = lineTotal
        var shared = claims.mapValues { $0 * count }
        for person in people { shared[person, default: 0] += left }
        let divisor = shared.values.reduce(quantity * count, Self.gcd)
        claims.removeAll()
        quantity = quantity * count / divisor
        unitPrice = total / Decimal(quantity)
        claims = shared.mapValues { $0 / divisor }
        isSplit = true
        return nil
    }

    private static func gcd(_ a: Int, _ b: Int) -> Int {
        b == 0 ? a : gcd(b, a % b)
    }
}
