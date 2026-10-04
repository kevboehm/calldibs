import SwiftUI

/// Shared design constants, so every screen uses the same spacing, rounding,
/// and colors. The money typography is in `ScaledFont`.
enum Theme {
    enum Spacing {
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let xLarge: CGFloat = 32
    }

    enum Radius {
        static let field: CGFloat = 16
        static let card: CGFloat = 28
    }

    /// The till-roll look: warm paper on a darker ground, with the accent
    /// green as the only strong color.
    enum Palette {
        /// Behind every screen.
        static let ground = Color("Ground")
        /// Cards and list rows.
        static let paper = Color("Paper")
        /// Dotted rules and quiet borders.
        static let rule = Color("Rule")
        /// "Not mine", unclaimed items and warnings.
        static let notMine = Color("NotMine")
    }

    enum Motion {
        /// The stamp slamming down.
        static let stamp = Animation.bouncy(duration: 0.26, extraBounce: 0.2)
    }
}
