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

    /// Everyone on the split, e.g. "Sam, Kevin and Person 3".
    var names: String {
        snapshot.people.enumerated()
            .map { $1.name.isEmpty ? "Person \($0 + 1)" : $1.name }
            .formatted(.list(type: .and))
    }

    /// What everyone owes between them, tax and tip included.
    var total: Decimal {
        snapshot.people.reduce(0) { $0 + ShareCalculator.summary(for: snapshot.receipt, person: $1).total }
    }
}
