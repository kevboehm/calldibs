import Foundation
import DibsCore

/// Everything needed to put the user back where they were: the bill, who has
/// called dibs on what, whose turn it is, and which screen was showing.
struct BillSnapshot: Codable {
    var receipt: Receipt
    var people: [Person]
    var currentID: Person.ID?
    var draftName: String
    var swipeIndex: Int
    var path: [Route]
    /// Where the bill was read from on its photo. The photo itself is kept
    /// beside the snapshot by `BillStore`.
    var scan: ScanSource?
}
