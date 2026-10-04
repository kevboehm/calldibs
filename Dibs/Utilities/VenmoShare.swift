import Foundation
import DibsCore

/// Builds the shareable "pay me on Venmo" text that the bill payer sends to
/// friends. Each link is a `venmo.com` pay link pointed at the payer's handle
/// with the friend's amount prefilled, so tapping it opens Venmo ready to pay.
///
/// Lives in the app target (not DibsCore) because it formats currency with
/// `Money`, which follows the device locale.
enum VenmoShare {
    /// Note that rides along on the Venmo transaction.
    static let note = "Bill split"

    /// A one-person message, e.g. for DMing someone their share.
    /// Returns `nil` when there is nothing payable (no handle, zero amount).
    static func payMessage(name: String, amount: Decimal, handle: String) -> String? {
        guard let url = VenmoLink.web(action: .pay, handle: handle, amount: amount, note: note) else {
            return nil
        }
        return "\(name), your share is \(Money.string(amount)). Pay me on Venmo: \(url.absoluteString)"
    }

    /// One message listing everyone and their personalized pay link — made for
    /// dropping into a group chat. People with nothing owed are left off.
    /// Returns `nil` when nobody has a payable amount.
    static func everyoneMessage(people: [(name: String, total: Decimal)], handle: String) -> String? {
        let lines: [String] = people.compactMap { person in
            guard let url = VenmoLink.web(action: .pay, handle: handle, amount: person.total, note: note) else {
                return nil
            }
            return "• \(person.name): \(Money.string(person.total)) → \(url.absoluteString)"
        }
        guard !lines.isEmpty else { return nil }
        return (["Here's what everyone owes — pay me on Venmo:"] + lines).joined(separator: "\n")
    }
}
