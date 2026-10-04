import SwiftUI

extension View {
    /// A font at a custom size that still grows and shrinks with the user's
    /// text size, the way `textStyle` does.
    func scaledFont(
        size: CGFloat,
        weight: Font.Weight,
        design: Font.Design,
        relativeTo textStyle: Font.TextStyle = .largeTitle
    ) -> some View {
        modifier(ScaledFont(size: size, weight: weight, design: design, textStyle: textStyle))
    }

    /// The big "you owe" number.
    func heroAmountFont() -> some View {
        scaledFont(size: 56, weight: .bold, design: .rounded)
    }

    /// Prices on the swipe card.
    func cardAmountFont() -> some View {
        scaledFont(size: 40, weight: .semibold, design: .monospaced)
    }

    /// The count in the quantity pickers.
    func counterFont() -> some View {
        scaledFont(size: 48, weight: .bold, design: .rounded)
    }
}

private struct ScaledFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight
    private let design: Font.Design

    init(size: CGFloat, weight: Font.Weight, design: Font.Design, textStyle: Font.TextStyle) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: textStyle)
        self.weight = weight
        self.design = design
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight, design: design))
    }
}
