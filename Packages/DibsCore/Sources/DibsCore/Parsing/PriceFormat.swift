import Foundation

/// How a receipt writes its amounts, worked out from the whole receipt
/// before any one line is read.
public struct PriceFormat: Sendable {
    /// Amounts are whole numbers, as in yen: "¥1,200", not "12.00".
    var wholeUnits = false
    /// A whole number is only a price with a currency sign beside it.
    var needsSign = false
    /// Thousands are set off with a space, as in "1 234,56".
    var spaceGrouping = false

    /// Two decimals behind a point or a comma, as on a US receipt.
    public static let standard = PriceFormat()

    private init() {}

    public init(lines: [String], currencyCode: String?) {
        var commas = 0, points = 0
        for line in lines {
            guard let mark = line.firstMatch(of: #/\d([.,])\d{2}\D{0,7}$/#)?.1 else { continue }
            if mark == "," { commas += 1 } else { points += 1 }
        }
        // A space only groups digits where the comma is the decimal mark;
        // elsewhere "Item 2 150.00" is an item called "Item 2".
        spaceGrouping = commas > points
        guard let currencyCode else { return }
        let noDecimals = Currency.fractionDigits(for: currencyCode) == 0
        wholeUnits = noDecimals || commas + points == 0
        needsSign = !noDecimals
    }

    /// How many decimal places the amounts have.
    var places: Int { wholeUnits ? 0 : 2 }

    /// Every amount printed on a line, wherever it stands.
    public func amounts(in line: String) -> [Decimal] {
        if wholeUnits {
            return line.matches(of: #/\d[\d.,'’]*/#).compactMap { Self.value(of: $0.output, places: 0) }
        }
        return line.matches(of: #/\d[\d.,'’]*[.,]\d{2}/#).compactMap { Self.value(of: $0.output, places: 2) }
    }

    /// An amount on its own, like "19.00", "12,50 €" or "¥1,200".
    public func amount(_ text: String) -> Decimal? {
        amounts(in: text).first ?? Decimal(string: text.filter(\.isNumber))
    }

    /// The digits of a printed amount, the last `places` of them decimals.
    static func value(of printed: some StringProtocol, places: Int) -> Decimal? {
        guard let digits = Decimal(string: String(printed.filter(\.isNumber))) else { return nil }
        return Decimal(sign: .plus, exponent: -places, significand: digits)
    }
}
