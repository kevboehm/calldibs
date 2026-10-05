import SwiftUI
import DibsCore

/// Past splits, newest first. Opening one shows what everyone owed; from
/// there it can be brought back as the bill in hand.
struct HistoryView: View {
    let onOpen: (SavedSplit) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var splits = HistoryStore.all()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(splits) { split in
                        NavigationLink {
                            SavedSplitView(split: split) {
                                dismiss()
                                onOpen(split)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(split.title)
                                    if split.snapshot.name != nil {
                                        Text(split.names)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(split.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(split.money.string(split.total))
                                    .fontDesign(.monospaced)
                            }
                        }
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
