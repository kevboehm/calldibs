import Foundation
import DibsCore

/// Builds the shareable "pay me" text that the bill payer sends to friends.
/// Each link points at the payer's handle with the friend's amount prefilled,
/// so tapping it opens Venmo, Cash App or PayPal ready to pay.
///
/// Lives in the app target (not DibsCore) because it formats currency with
/// `Money`, in the phone's language.
enum PayShare {
    /// Note that rides along on the transaction, where the service takes one.
    static let note = "Bill split"

    /// A one-person message, e.g. for DMing someone their share: the amount
    /// and pay link first, then the items, tax and tip that make it up.
    /// Returns `nil` when there is nothing payable (no handle, zero amount).
    static func payMessage(
        name: String,
        summary: ShareSummary,
        method: PaymentMethod,
        handle: String,
        money: Money
    ) -> String? {
        guard let url = method.payLink(handle: handle, amount: summary.total, note: note) else {
            return nil
        }
        let heading = "\(name), your share is \(money.string(summary.total)). Pay me on \(method.title): \(url.absoluteString)"
        let lines = summary.breakdown.map { "• \($0.label): \(money.string($0.amount))" }
        return ([heading, ""] + lines).joined(separator: "\n")
    }

    /// One message listing everyone and what they owe — made for dropping
    /// into a group chat. With a handle, each line carries that person's pay
    /// link; without one it is just the amounts. People with nothing owed are
    /// left off. Returns `nil` when nobody has a payable amount.
    static func everyoneMessage(
        people: [(name: String, total: Decimal)],
        method: PaymentMethod,
        handle: String,
        money: Money
    ) -> String? {
        let owing = people.filter { $0.total > 0 }
        guard !owing.isEmpty else { return nil }

        let hasHandle = !method.normalize(handle).isEmpty
        let lines: [String] = owing.map { person in
            let amount = "• \(person.name): \(money.string(person.total))"
            guard let url = method.payLink(handle: handle, amount: person.total, note: note) else {
                return amount
            }
            return "\(amount) → \(url.absoluteString)"
        }
        let heading = hasHandle
            ? "Here's what everyone owes — pay me on \(method.title):"
            : "Here's what everyone owes:"
        return ([heading] + lines).joined(separator: "\n")
    }
}
