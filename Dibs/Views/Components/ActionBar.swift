import SwiftUI

extension View {
    /// Pins the screen's actions to the bottom, with content scrolling
    /// underneath and fading out behind them.
    ///
    /// - Parameter hidesWithKeyboard: for screens with fields in a scrolling
    ///   list, where the bar would otherwise float above the keyboard and
    ///   cover what is being typed.
    func actionBar<Content: View>(
        hidesWithKeyboard: Bool = false,
        @ViewBuilder _ content: @escaping () -> Content
    ) -> some View {
        modifier(ActionBar(hidesWithKeyboard: hidesWithKeyboard, bar: content))
    }
}

private struct ActionBar<Bar: View>: ViewModifier {
    let hidesWithKeyboard: Bool
    @ViewBuilder let bar: () -> Bar
    @State private var isKeyboardVisible = false

    func body(content: Content) -> some View {
        content
            .safeAreaBar(edge: .bottom) {
                if !(hidesWithKeyboard && isKeyboardVisible) {
                    bar()
                        .padding(.horizontal, Theme.Spacing.large)
                        .padding(.vertical, Theme.Spacing.medium)
                }
            }
            // A firm edge, so list rows don't show through behind the buttons.
            .scrollEdgeEffectStyle(.hard, for: .bottom)
            .onKeyboardVisibilityChange { isKeyboardVisible = $0 }
    }
}
