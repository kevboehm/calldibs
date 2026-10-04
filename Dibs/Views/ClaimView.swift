import SwiftUI
import DibsCore

/// Hosts the two claim front-ends over the same `ClaimViewModel`.
struct ClaimView: View {
    var session: ClaimViewModel
    @State var mode: ClaimMode
    let onReview: () -> Void

    var body: some View {
        let subtotal = session.summary.claimedSubtotal

        Group {
            switch mode {
            case .swipe:
                SwipeClaimView(session: session)
            case .checklist:
                ChecklistClaimView(session: session)
            }
        }
        .paperScreen()
        .navigationTitle("Call your dibs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Claim mode", selection: $mode) {
                    ForEach(ClaimMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
            }
        }
        .actionBar {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your dibs")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(Money.string(subtotal))
                        .font(.title2.bold())
                        .fontDesign(.monospaced)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: subtotal)
                }
                Spacer()
                Button("Review", systemImage: "arrow.right", action: onReview)
                    .font(.headline)
                    .lineLimit(1)
                    .fixedSize()
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
            }
        }
    }
}
