import SwiftUI
import DibsCore

/// Collects the bill payer's own Venmo username so Dibs can build "pay me"
/// links. Stores the normalized handle (no leading `@`, no whitespace).
struct VenmoHandleSheet: View {
    @Binding var handle: String
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 4) {
                        Text("@")
                            .foregroundStyle(.secondary)
                        TextField("your-venmo", text: $draft)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textContentType(.username)
                            .submitLabel(.done)
                            .onSubmit(save)
                    }
                } footer: {
                    Text("This is your Venmo username — the part after the @. Friends tap your links to pay you their share.")
                }
                .receiptRow()
            }
            .paperScreen()
            .navigationTitle("Your Venmo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(VenmoLink.normalize(draft).isEmpty)
                }
            }
            .onAppear { draft = handle }
        }
    }

    private func save() {
        let normalized = VenmoLink.normalize(draft)
        guard !normalized.isEmpty else { return }
        handle = normalized
        dismiss()
    }
}
