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
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .sensoryFeedback(.impact(weight: .light), trigger: taps)
    }
}
