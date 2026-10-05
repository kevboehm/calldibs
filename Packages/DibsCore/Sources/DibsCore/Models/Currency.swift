import Foundation

/// What the app needs to know about a currency, by its ISO 4217 code.
public enum Currency {
    /// How many decimal places amounts are written with: 2 for most, 0 for
    /// yen, won and the like.
    public static func fractionDigits(for code: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        if let known = digits[code] { return known }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        let found = formatter.maximumFractionDigits
        digits[code] = found
        return found
    }

    /// Whether a bill in this currency starts with a tip on top. Elsewhere
    /// service is in the prices, or a tip is a rounding-up.
    public static func tipsByDefault(_ code: String) -> Bool {
        code == "USD" || code == "CAD"
    }

    /// Venmo and Cash App only move US dollars, so links with an amount
    /// filled in are only right for a dollar bill.
    public static func supportsPayLinks(_ code: String) -> Bool {
        code == "USD"
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var digits: [String: Int] = [:]
}
