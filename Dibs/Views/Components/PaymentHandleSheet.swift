import SwiftUI
import DibsCore

/// Collects where the bill payer wants to be paid and their handle there, so
/// Dibs can build "pay me" links. Stores the normalized handle (no leading
/// `@` or `$`, no whitespace).
struct PaymentHandleSheet: View {
    var payout = PayoutSettings()
    @Environment(\.dismiss) private var dismiss
    @State private var method = PaymentMethod.venmo
    @State private var draft = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Pay me on", selection: $method) {
                        ForEach(PaymentMethod.allCases) { method in
                            Text(method.title).tag(method)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack(spacing: 4) {
                        Text(method.prefix)
                            .foregroundStyle(.secondary)
                        TextField("your-handle", text: $draft)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textContentType(.username)
                            .submitLabel(.done)
                            .onSubmit(save)
                    }
                } footer: {
                    Text("This is your \(method.title) username — the part after \(method.prefix). Friends tap your links to pay you their share.")
                }
                .receiptRow()
            }
            .paperScreen()
            .navigationTitle("How you get paid")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(method.normalize(draft).isEmpty)
                }
            }
            .onAppear {
                method = payout.method
                draft = payout.handle
            }
            // Each service keeps its own handle.
            .onChange(of: method) { draft = payout.handle(for: method) }
        }
    }

    private func save() {
        let normalized = method.normalize(draft)
        guard !normalized.isEmpty else { return }
        payout.save(normalized, for: method)
        dismiss()
    }
}
