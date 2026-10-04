import Foundation

/// Something on the bill that isn't an item or tax: a service charge, an
/// automatic gratuity, a delivery or card fee. A negative amount is a
/// discount. Everyone carries it in proportion to what they had.
public struct Charge: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public var name: String
    public var amount: Decimal

    public init(id: UUID = UUID(), name: String, amount: Decimal) {
        self.id = id
        self.name = name
        self.amount = amount
    }

    /// True when the charge already tips the staff, so a tip on top would
    /// usually be paying twice. "Parties of 6+" is one under another name.
    public var isGratuity: Bool {
        let lower = name.lowercased()
        return amount > 0 && ["gratuity", "service", "tip", "party of", "parties of"].contains { lower.contains($0) }
    }
}
