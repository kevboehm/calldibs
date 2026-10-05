import SwiftUI

/// The one main action on a screen: full width, prominent glass.
struct PrimaryButton: View {
    let title: String
    var systemImage: String?
    let action: () -> Void
    /// Haptic trigger.
    @State private var taps = 0

    init(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button {
            taps += 1
            action()
        } label: {
            PrimaryButtonLabel(title: title, systemImage: systemImage)
        }
        .primaryButtonStyle()
        .sensoryFeedback(.impact(weight: .light), trigger: taps)
    }
}

/// What a `PrimaryButton` says, for controls that aren't plain buttons (a
/// `ShareLink`, say) but are the main action all the same.
struct PrimaryButtonLabel: View {
    let title: String
    var systemImage: String?

    var body: some View {
        Group {
            if let systemImage {
                Label(title, systemImage: systemImage)
            } else {
                Text(title)
            }
        }
        .font(.headline)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.small)
    }
}

extension View {
    /// The full-width prominent glass of the screen's main action.
    func primaryButtonStyle() -> some View {
        buttonStyle(.glassProminent)
            .controlSize(.large)
    }
}
