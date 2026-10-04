import Foundation

/// Direction of a Venmo hand-off.
public enum VenmoAction: String, Sendable {
    /// You pay someone (the shareable "pay me" direction, pointed at the payer).
    case pay
    /// You request money from someone (the per-friend request direction).
    case charge
}

/// Builds prefilled Venmo deep links so Dibs can hand off to Venmo with the
/// amount and note already filled in. The user always confirms the transaction
/// inside Venmo — these links only open the compose screen.
///
/// No SDK, API key or backend is involved. The `venmo://` scheme is undocumented
/// but widely used; the `https://venmo.com` form is the web fallback and also
/// what we share to friends who may open it on any device.
public enum VenmoLink {

    /// In-app deep link: `venmo://paycharge?txn=…&recipients=…&amount=…&note=…`
    ///
    /// `handle` may be empty for a charge — Venmo then opens with the amount and
    /// note filled and lets the user pick the recipient. A `pay` link with an
    /// empty handle is still valid for the same reason.
    /// Returns `nil` for a zero or negative amount.
    public static func app(action: VenmoAction, handle: String, amount: Decimal, note: String) -> URL? {
        guard let amountString = formattedAmount(amount) else { return nil }

        var components = URLComponents()
        components.scheme = "venmo"
        components.host = "paycharge"
        components.queryItems = [
            URLQueryItem(name: "txn", value: action.rawValue),
            URLQueryItem(name: "recipients", value: normalize(handle)),
            URLQueryItem(name: "amount", value: amountString),
            URLQueryItem(name: "note", value: note),
        ]
        return components.url
    }

    /// Shareable / fallback web link: `https://venmo.com/<handle>?txn=…&amount=…&note=…`
    ///
    /// Requires a non-empty handle (the path segment names the person). Returns
    /// `nil` for an empty handle or a zero/negative amount.
    public static func web(action: VenmoAction, handle: String, amount: Decimal, note: String) -> URL? {
        let normalized = normalize(handle)
        guard !normalized.isEmpty else { return nil }
        guard let amountString = formattedAmount(amount) else { return nil }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "venmo.com"
        components.path = "/" + normalized
        components.queryItems = [
            URLQueryItem(name: "txn", value: action.rawValue),
            URLQueryItem(name: "amount", value: amountString),
            URLQueryItem(name: "note", value: note),
        ]
        return components.url
    }

    // MARK: - Helpers

    /// Trim whitespace and drop a single leading `@` so "@alex" and "alex" match.
    public static func normalize(_ handle: String) -> String {
        var trimmed = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("@") {
            trimmed.removeFirst()
        }
        return trimmed
    }

    /// Two decimal places in a locale-independent form, so the amount is always
    /// "12.34" and never "12,34". Returns `nil` for zero or negative amounts.
    static func formattedAmount(_ amount: Decimal) -> String? {
        guard amount > 0 else { return nil }

        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.roundingMode = .halfUp
        return formatter.string(from: amount as NSDecimalNumber)
    }
}
