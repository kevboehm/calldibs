import SwiftUI
import DibsCore

/// Past splits, newest first. Opening one brings it back as the bill in
/// hand, so it can be checked, changed or shared again.
struct HistoryView: View {
    let onOpen: (SavedSplit) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var splits = HistoryStore.all()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(splits) { split in
                        Button {
                            dismiss()
                            onOpen(split)
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(split.names)
                                    Text(split.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(Money.string(split.total))
                                    .fontDesign(.monospaced)
                            }
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: delete)
                } footer: {
                    if !splits.isEmpty {
                        Text("Kept on this phone only. Swipe a split to delete it.")
                    }
                }
                .receiptRow()
            }
            .paperScreen()
            .overlay {
                if splits.isEmpty {
                    ContentUnavailableView(
                        "No splits yet",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Bills you finish splitting are kept here.")
                    )
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { HistoryStore.delete(splits[index].id) }
        splits.remove(atOffsets: offsets)
    }
}
