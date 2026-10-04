import Foundation

public struct Receipt: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public var items: [LineItem]
    /// Exact tax amount read from the receipt's own tax line.
    public var tax: Decimal
    /// Pre-tax subtotal as printed on the receipt, when one was found.
    public var subtotal: Decimal?
    /// Receipt total as printed, when one was found.
    public var total: Decimal?
    /// Service charges, fees and discounts, shared out like tax.
    public var charges: [Charge]

    public init(
        id: UUID = UUID(),
        items: [LineItem] = [],
        tax: Decimal = 0,
        subtotal: Decimal? = nil,
        total: Decimal? = nil,
        charges: [Charge] = []
    ) {
        self.id = id
        self.items = items
        self.tax = tax
        self.subtotal = subtotal
        self.total = total
        self.charges = charges
    }

    public var itemsSubtotal: Decimal {
        items.reduce(0) { $0 + $1.lineTotal }
    }

    /// The base that tax is apportioned against: the printed subtotal when the
    /// receipt had one, otherwise the sum of the line items.
    public var preTaxSubtotal: Decimal {
        subtotal ?? itemsSubtotal
    }

    /// Whether the items, tax and charges come to the printed total, to the
    /// cent. Nil when no total was printed, so there is nothing to check
    /// against.
    public var reconciles: Bool? {
        guard let total else { return nil }
        return !items.isEmpty && (computedTotal - total).roundedToCents() == 0
    }

    public var chargesTotal: Decimal {
        charges.reduce(0) { $0 + $1.amount }
    }

    /// What the whole bill comes to before any tip.
    public var computedTotal: Decimal {
        itemsSubtotal + tax + chargesTotal
    }

    /// True when the bill already carries a gratuity or service charge.
    public var includesGratuity: Bool {
        charges.contains(where: \.isGratuity)
    }

    /// Items with units that nobody has claimed yet.
    public var unclaimedItems: [LineItem] {
        items.filter { $0.unclaimedQuantity > 0 }
    }

    /// Shares every unclaimed unit equally among `people`, so the bill ends
    /// up fully covered.
    public mutating func splitUnclaimedEvenly(among people: [Person.ID]) {
        var shared: [LineItem] = []
        for var item in items {
            let rest = item.shareUnclaimed(among: people)
            shared.append(item)
            if let rest { shared.append(rest) }
        }
        items = shared
    }

    public mutating func removeClaims(by person: Person.ID) {
        for index in items.indices {
            items[index].removeClaims(by: person)
        }
    }
}
