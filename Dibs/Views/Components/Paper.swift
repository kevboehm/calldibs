import SwiftUI

extension View {
    /// The warm ground behind a screen. Also clears a List's own background
    /// so the ground shows through.
    func paperScreen() -> some View {
        scrollContentBackground(.hidden)
            .background(Theme.Palette.ground)
    }

    /// Sits the view on a strip of paper. A torn strip needs a little extra
    /// bottom padding from the caller, to clear the teeth.
    func paperCard(torn: Bool = true) -> some View {
        background {
            (torn ? AnyShape(TornPaper()) : AnyShape(.rect(cornerRadius: Theme.Radius.field)))
                .fill(Theme.Palette.paper)
                .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
        }
    }

    /// Styles list rows as lines on a receipt: paper, with a dotted rule
    /// underneath instead of the system separator. Works on a single row or
    /// a whole Section.
    func receiptRow() -> some View {
        listRowBackground(
            Theme.Palette.paper.overlay(alignment: .bottom) {
                RuleLine()
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    .foregroundStyle(Theme.Palette.rule)
                    .frame(height: 1)
                    .padding(.horizontal, Theme.Spacing.medium)
            }
        )
        .listRowSeparator(.hidden)
    }

    /// Fades and drops the view in, staggered by `index`, like lines coming
    /// off a printer.
    ///
    /// - Parameter isActive: false shows the view straight away, for content
    ///   that has already printed once.
    func printIn(index: Int, isActive: Bool = true) -> some View {
        modifier(PrintIn(index: index, isActive: isActive))
    }
}

private struct PrintIn: ViewModifier {
    let index: Int
    @State private var shown: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(index: Int, isActive: Bool) {
        self.index = index
        _shown = State(initialValue: !isActive)
    }

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : -4)
            .onAppear {
                guard !shown else { return }
                // Capped, so a row far down a long bill isn't kept waiting.
                let delay = Double(min(index, 12)) * 0.035
                withAnimation(reduceMotion ? nil : .smooth(duration: 0.25).delay(delay)) { shown = true }
            }
    }
}
