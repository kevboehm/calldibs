import SwiftUI
import DibsCore

/// Start of each person's turn: whoever is holding the phone says who they are.
/// Also the first step when an earlier person's turn is reopened.
struct NameEntryView: View {
    @Bindable var session: ClaimViewModel
    let onContinue: () -> Void
    let onShowSplit: () -> Void

    @FocusState private var nameFocused: Bool

    /// A turn is already open: we're changing that person, not adding one.
    private var isEditing: Bool { session.current != nil }
    private var isFirstPerson: Bool { session.people.isEmpty }

    private var heading: String {
        if let current = session.current { return "Editing \(session.displayName(current))" }
        return isFirstPerson ? "Who's going first?" : "Who's next?"
    }

    private var subheading: String {
        if isEditing { return "Fix the name if you need to, then change the dibs." }
        if isFirstPerson { return "Add a name so everyone can see who had what." }
        let count = session.receipt.unclaimedItems.count
        return "Pass the phone along. \(count) \(count == 1 ? "item is" : "items are") still up for grabs."
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.large) {
            badge
                .foregroundStyle(.tint)
                .frame(width: 96, height: 96)
                .background(.tint.opacity(0.14), in: .circle)
                .accessibilityHidden(true)
                .padding(.top, Theme.Spacing.xLarge)

            VStack(spacing: Theme.Spacing.small) {
                Text(heading)
                    .font(.title.bold())
                Text(subheading)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            TextField("Your name", text: $session.draftName)
                .textContentType(.givenName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.continue)
                .focused($nameFocused)
                .onSubmit(continueIfNamed)
                .font(.title3)
                .multilineTextAlignment(.center)
                .fontDesign(.monospaced)
                .padding()
                .padding(.bottom, Theme.Spacing.small)
                .paperCard()

            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.large)
        .paperScreen()
        .navigationTitle(isEditing ? "Edit" : isFirstPerson ? "Your name" : "Next person")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { nameFocused = !isEditing }
        .actionBar {
            VStack(spacing: Theme.Spacing.medium) {
                PrimaryButton(isEditing ? "Change my dibs" : "Call my dibs", action: continueIfNamed)
                    .disabled(session.trimmedName.isEmpty)

                // Just working out your own share doesn't need a name.
                Button(isEditing ? "Keep the name as it is" : "Skip, no name needed", action: skip)

                if !isEditing && !isFirstPerson {
                    Button("Nobody else, show the split", action: onShowSplit)
                }
            }
        }
    }

    /// The typed initial, so the circle becomes that person's as they type.
    @ViewBuilder
    private var badge: some View {
        if !isEditing, let initial = session.trimmedName.first {
            Text(String(initial).uppercased())
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .contentTransition(.numericText())
                .animation(.snappy, value: initial)
        } else {
            Image(systemName: isEditing ? "pencil" : "person.fill")
                .font(.system(size: 40))
        }
    }

    private func continueIfNamed() {
        guard !session.trimmedName.isEmpty else { return }
        onContinue()
    }

    private func skip() {
        // When editing, skipping leaves the person's existing name alone.
        session.draftName = session.current?.name ?? ""
        onContinue()
    }
}
