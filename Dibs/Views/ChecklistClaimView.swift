import SwiftUI
import DibsCore

struct ChecklistClaimView: View {
    var session: ClaimViewModel
    /// The multi-unit row whose quantity picker is open.
    @State private var expandedID: LineItem.ID?
    /// The item being divided into shares.
    @State private var splitItem: LineItem?
    /// Haptic trigger.
    @State private var toggleCount = 0

    var body: some View {
        List(session.receipt.items) { item in
            let claimed = session.claimed(item)
            let available = session.available(item)

            VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                HStack(spacing: 12) {
                    Button {
                        tap(item, available: available)
                    } label: {
                        ChecklistRow(
                            item: item,
                            claimed: claimed,
                            available: available,
                            othersClaims: session.othersClaims(on: item)
                        )
                    }
                    .buttonStyle(.plain)
                    // Other people hold every unit: crossed out for this person.
                    .disabled(available == 0)

                    if session.canSplit(item) {
                        Button(item.isSplit ? "Change the split" : "Split this item", systemImage: "chart.pie") {
                            splitItem = item
                        }
                        .labelStyle(.iconOnly)
                        .font(.title3)
                        .buttonStyle(.borderless)
                        .frame(minWidth: 44, minHeight: 44)
                    }
                }

                if expandedID == item.id {
                    QuantityPicker(item: item, claimed: claimed, available: available, minimum: 0) { count in
                        session.setClaimed(count, for: item.id)
                        toggleCount += 1
                        withAnimation(.snappy) { expandedID = nil }
                    }
                }
            }
            .receiptRow()
        }
        .sensoryFeedback(.selection, trigger: toggleCount)
        .sheet(item: $splitItem) { item in
            SplitPicker(item: item) { parts in
                session.split(item.id, into: parts)
                splitItem = nil
                // Straight on to "how many shares were yours?".
                withAnimation(.snappy) { expandedID = parts > 1 ? item.id : nil }
            }
            .padding()
            .presentationDetents([.height(340)])
            .presentationBackground(Theme.Palette.ground)
            .presentationDragIndicator(.visible)
        }
    }

    private func tap(_ item: LineItem, available: Int) {
        if available > 1 {
            withAnimation(.snappy) { expandedID = expandedID == item.id ? nil : item.id }
        } else {
            session.toggleClaimed(item.id)
            toggleCount += 1
        }
    }
}
