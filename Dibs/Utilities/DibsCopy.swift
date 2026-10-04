import Foundation

/// Shared wording for who has called dibs on something.
enum DibsCopy {
    /// "Sam called dibs" for one person, "Dibs: Sam ×2, Alex ×1" for a tally.
    static func others(_ claims: String) -> String {
        claims.contains(",") || claims.contains("×") ? "Dibs: \(claims)" : "\(claims) called dibs"
    }
}
