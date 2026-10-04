import Foundation

public struct TipConfig: Hashable, Sendable, Codable {
    public enum Base: String, Hashable, Sendable, Codable {
        case postTax
        case preTax
    }

    public var rate: Decimal
    public var base: Base

    public init(rate: Decimal = TipConfig.defaultRate, base: Base = TipConfig.defaultBase) {
        self.rate = rate
        self.base = base
    }

    public static let defaultRate = Decimal(string: "0.20")!
    /// The single place that decides what the tip is calculated on.
    public static let defaultBase: Base = .postTax
    public static let `default` = TipConfig()
}
