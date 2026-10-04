import Foundation
import DibsCore

/// Builds the shareable "pay me" text that the bill payer sends to friends.
/// Each link points at the payer's handle with the friend's amount prefilled,
/// so tapping it opens Venmo, Cash App or PayPal ready to pay.
///
/// Lives in the app target (not DibsCore) because it formats currency with
/// `Money`, which follows the device locale.
enum PayShare {
    /// Note that rides along on the transaction, where the service takes one.
    static let note = "Bill split"

    /// A one-person message, e.g. for DMing someone their share.
    /// Returns `nil` when there is nothing payable (no handle, zero amount).
    static func payMessage(name: String, amount: Decimal, method: PaymentMethod, handle: String) -> String? {
        guard let url = method.payLink(handle: handle, amount: amount, note: note) else {
            return nil
        }
        return "\(name), your share is \(Money.string(amount)). Pay me on \(method.title): \(url.absoluteString)"
    }

    /// One message listing everyone and what they owe — made for dropping
    /// into a group chat. With a handle, each line carries that person's pay
    /// link; without one it is just the amounts. People with nothing owed are
    /// left off. Returns `nil` when nobody has a payable amount.
    static func everyoneMessage(
        people: [(name: String, total: Decimal)],
        method: PaymentMethod,
        handle: String
    ) -> String? {
        let owing = people.filter { $0.total > 0 }
        guard !owing.isEmpty else { return nil }

        let hasHandle = !method.normalize(handle).isEmpty
        let lines: [String] = owing.map { person in
            let amount = "• \(person.name): \(Money.string(person.total))"
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
