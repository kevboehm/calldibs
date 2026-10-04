import SwiftUI

/// Shown when the swipe stack runs out.
struct SwipeFinishedView: View {
    /// True when there was nothing to swipe in the first place.
    let isEmpty: Bool
    let onRestart: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(isEmpty ? "Nothing left to call dibs on" : "That's the whole bill", systemImage: "checkmark.circle")
        } description: {
            Text("Tap Review to see what you owe.")
        } actions: {
            if !isEmpty {
                Button("Go through them again", action: onRestart)
                    .buttonStyle(.glass)
            }
        }
    }
}
