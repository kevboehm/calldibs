import Foundation
import DibsCore

/// What a receipt really says, written by hand (or converted from a labeled
/// dataset) next to its photo as `<name>.json`. Amounts are plain JSON numbers.
public struct GroundTruth: Codable, Sendable {
    public struct Item: Codable, Sendable {
        public var name: String
        /// Nil when the labels don't say, so it is not scored.
        public var quantity: Int?
        /// The line total as printed, not the unit price.
        public var total: Double

        public init(name: String, quantity: Int? = nil, total: Double) {
            self.name = name
            self.quantity = quantity
            self.total = total
        }
    }

    public var items: [Item]
    public var subtotal: Double?
    public var tax: Double?
    public var total: Double?

    public init(items: [Item], subtotal: Double? = nil, tax: Double? = nil, total: Double? = nil) {
        self.items = items
        self.subtotal = subtotal
        self.tax = tax
        self.total = total
    }
}

func cents(_ amount: Double) -> Int { Int((amount * 100).rounded()) }

func cents(_ amount: Decimal) -> Int {
    Int((NSDecimalNumber(decimal: amount).doubleValue * 100).rounded())
}
