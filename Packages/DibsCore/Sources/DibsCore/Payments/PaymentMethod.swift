import Foundation

/// Where the bill payer wants to be paid back. Each one has a public link
/// form that opens with the amount filled in, so no SDK or backend is needed.
public enum PaymentMethod: String, CaseIterable, Identifiable, Hashable, Sendable, Codable {
    case venmo
    case cashApp
    case payPal

    public var id: Self { self }

    public var title: String {
        switch self {
        case .venmo: return "Venmo"
        case .cashApp: return "Cash App"
        case .payPal: return "PayPal"
        }
    }

    /// What goes in front of the handle when it is shown: "@alex", "$alex",
    /// "paypal.me/alex".
    public var prefix: String {
        switch self {
        case .venmo: return "@"
        case .cashApp: return "$"
        case .payPal: return "paypal.me/"
        }
    }

    /// The bare handle, however it was typed or pasted: without whitespace,
    /// a leading `@` or `$`, or the front of a pasted link.
    public func normalize(_ handle: String) -> String {
        var trimmed = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        if let slash = trimmed.lastIndex(of: "/") {
            trimmed = String(trimmed[trimmed.index(after: slash)...])
        }
        while let first = trimmed.first, first == "@" || first == "$" {
            trimmed.removeFirst()
        }
        return trimmed
    }

    /// A link that opens this service ready to pay `handle` the amount.
    /// Returns `nil` for an empty handle or a zero or negative amount. Only
    /// Venmo carries the note.
    public func payLink(handle: String, amount: Decimal, note: String) -> URL? {
        let handle = normalize(handle)
        guard !handle.isEmpty, let amountString = VenmoLink.formattedAmount(amount) else { return nil }

        switch self {
        case .venmo:
            return VenmoLink.web(action: .pay, handle: handle, amount: amount, note: note)
        case .cashApp:
            return link(host: "cash.app", path: "/$\(handle)/\(amountString)")
        case .payPal:
            return link(host: "paypal.me", path: "/\(handle)/\(amountString)")
        }
    }

    private func link(host: String, path: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path
        return components.url
    }
}
