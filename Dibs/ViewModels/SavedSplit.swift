import Foundation
import DibsCore

/// A finished split kept in History, so it can be looked at or shared again.
struct SavedSplit: Codable, Identifiable {
    /// The bill's own id, so saving the same bill again replaces it.
    let id: Receipt.ID
    /// When it was first kept.
    var date: Date
    /// The bill and who had what. The receipt photo is not kept.
    var snapshot: BillSnapshot

    /// The currency the bill was in.
    var money: Money { snapshot.receipt.money }

    /// What to call it: the bill's name, or who was on it.
    var title: String { snapshot.name ?? names }

    /// Everyone on the split, e.g. "Sam, Kevin and Person 3".
    var names: String {
        shares.map(\.name).formatted(.list(type: .and))
    }

    /// What everyone owes between them, tax and tip included.
    var total: Decimal {
        shares.reduce(0) { $0 + $1.summary.total }
    }

    /// Each person and what they owed, in the order they went.
    var shares: [(name: String, summary: ShareSummary)] {
        snapshot.people.enumerated().map { index, person in
            (
                person.name.isEmpty ? "Person \(index + 1)" : person.name,
                ShareCalculator.summary(for: snapshot.receipt, person: person)
            )
        }
    }
}
