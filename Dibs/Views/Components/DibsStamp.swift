import SwiftUI

/// The rubber stamp that lands on a card when dibs is called.
struct DibsStamp: View {
    let text: String
    var size: CGFloat = 46

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .black, design: .rounded))
            .tracking(2)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Theme.Palette.paper.opacity(0.9), in: .rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(lineWidth: 5)
            }
            .foregroundStyle(.tint)
            .rotationEffect(.degrees(-11))
            .accessibilityHidden(true)
    }
}
