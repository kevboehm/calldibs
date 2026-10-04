import SwiftUI
import DibsCore

struct SwipeClaimView: View {
    var session: ClaimViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var drag: CGSize = .zero
    /// The multi-unit item waiting on a quantity before its claim completes.
    @State private var pickerItem: LineItem?
    /// The item being divided into shares.
    @State private var splitItem: LineItem?

    /// True from the moment a card is decided until the next one is in
    /// place. Further taps and drags are ignored, so a quick double tap can't
    /// decide the next card before it has been seen.
    @State private var isLeaving = false

    /// What the stamp on the top card says, while one is showing.
    @State private var stamp: String? = SwipeClaimView.initialStamp

    // Haptic and confetti triggers.
    @State private var claimCount = 0
    @State private var skipCount = 0
    @State private var isPastThreshold = false

    /// False until this phone has decided its first card, while the deck
    /// still explains itself.
    @AppStorage("hasSwiped") private var hasSwiped = false

    private let threshold: CGFloat = 110
    /// How far the first card leans over to show that it swipes.
    private let nudge: CGFloat = 64

    // Only what other people have left.
    private var items: [LineItem] { session.swipeItems }

    private func item(at index: Int) -> LineItem? {
        items.indices.contains(index) ? items[index] : nil
    }

    /// -1...1: how far the card is towards "not mine" or "mine".
    private var dragProgress: Double {
        max(-1, min(1, drag.width / threshold))
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.large) {
            if let current = item(at: session.swipeIndex) {
                Text("\(session.swipeIndex + 1) of \(items.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())

                if !hasSwiped {
                    Text("Swipe right for yours, left for not yours.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                ZStack {
                    if let next = item(at: session.swipeIndex + 1) {
                        card(for: next)
                            .scaleEffect(0.94)
                            .offset(y: 16)
                            .opacity(0.6)
                    }
                    card(for: current)
                        .overlay {
                            TornPaper()
                                .fill(dragProgress > 0 ? Color.accentColor : Theme.Palette.notMine)
                                .opacity(abs(dragProgress) * 0.16)
                                .allowsHitTesting(false)
                        }
                        .overlay(alignment: .top) {
                            if stamp == nil, abs(dragProgress) > 0.05 {
                                SwipeHintBadge(progress: dragProgress)
                            }
                        }
                        .overlay {
                            if let stamp {
                                DibsStamp(text: stamp)
                                    .transition(reduceMotion ? .opacity : .scale(scale: 2.6).combined(with: .opacity))
                            }
                        }
                        .offset(x: drag.width, y: drag.height * 0.15)
                        .rotationEffect(.degrees(reduceMotion ? 0 : drag.width / 22))
                        .gesture(dragGesture(for: current), isEnabled: !isLeaving)
                        .id(current.id)
                        // The outgoing card has already flown off screen.
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.94).combined(with: .opacity),
                            removal: .identity
                        ))
                }
                .padding(.horizontal, Theme.Spacing.large)

                GlassEffectContainer(spacing: Theme.Spacing.large) {
                    HStack(spacing: Theme.Spacing.large) {
                        RoundGlassButton(title: "Previous item", systemImage: "arrow.uturn.backward", tint: .secondary, diameter: 48, action: goBack)
                            .disabled(session.swipeIndex == 0)
                        RoundGlassButton(title: "Not mine", systemImage: "xmark", tint: Theme.Palette.notMine, diameter: 68) { skip(current) }
                        RoundGlassButton(title: "Call dibs", systemImage: "checkmark", tint: .accentColor, diameter: 68) { claim(current) }
                        RoundGlassButton(
                            title: current.isSplit ? "Change the split" : "Split this item",
                            systemImage: "chart.pie",
                            tint: .accentColor,
                            diameter: 48
                        ) { splitItem = current }
                        .disabled(!session.canSplit(current))
                    }
                }
            } else {
                SwipeFinishedView(isEmpty: items.isEmpty) {
                    withAnimation { session.swipeIndex = 0 }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if !reduceMotion {
                ConfettiBurst(trigger: claimCount)
            }
        }
        .task(showSwipe)
        .sensoryFeedback(.impact(weight: .heavy), trigger: claimCount)
        .sensoryFeedback(.impact(weight: .light), trigger: skipCount)
        .sensoryFeedback(.selection, trigger: isPastThreshold)
        .sheet(item: $pickerItem) { item in
            QuantityPicker(
                item: item,
                claimed: session.claimed(item),
                available: session.available(item),
                minimum: 1
            ) { count in
                session.setClaimed(count, for: item.id)
                pickerItem = nil
                callDibs(count: count)
            }
            .padding()
            .presentationDetents([.height(320)])
            .presentationBackground(Theme.Palette.ground)
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $splitItem) { item in
            // The card stays put after a split; swiping right then asks how
            // many shares were theirs.
            SplitPicker(item: item) { parts in
                session.split(item.id, into: parts)
                splitItem = nil
            }
            .padding()
            .presentationDetents([.height(340)])
            .presentationBackground(Theme.Palette.ground)
            .presentationDragIndicator(.visible)
        }
    }

    private func card(for item: LineItem) -> some View {
        SwipeItemCard(
            item: item,
            claimed: session.claimed(item),
            available: session.available(item),
            othersClaims: session.othersClaims(on: item)
        )
    }

    // MARK: - Actions

    private func dragGesture(for item: LineItem) -> some Gesture {
        DragGesture()
            .onChanged { value in
                drag = value.translation
                isPastThreshold = abs(value.translation.width) > threshold
            }
            .onEnded { value in
                isPastThreshold = false
                if value.translation.width > threshold {
                    claim(item)
                } else if value.translation.width < -threshold {
                    skip(item)
                } else {
                    withAnimation(.spring) { drag = .zero }
                }
            }
    }

    private func claim(_ item: LineItem) {
        guard !isLeaving else { return }
        if session.available(item) > 1 {
            // The card returns to the stack; only the picker's confirm claims.
            withAnimation(.spring) { drag = .zero }
            pickerItem = item
        } else {
            session.setClaimed(1, for: item.id)
            callDibs(count: 1)
        }
    }

    private func skip(_ item: LineItem) {
        guard !isLeaving else { return }
        isLeaving = true
        hasSwiped = true
        session.setClaimed(0, for: item.id)
        skipCount += 1
        flyOff(towards: -1)
    }

    /// The playful bit: the stamp slams onto the card with a thump and some
    /// confetti, then the card leaves.
    private func callDibs(count: Int) {
        isLeaving = true
        hasSwiped = true
        claimCount += 1
        withAnimation(.spring) { drag = .zero }
        withAnimation(Theme.Motion.stamp) {
            stamp = count > 1 ? "DIBS ×\(count)" : "DIBS!"
        } completion: {
            flyOff(towards: 1)
        }
    }

    /// Leans the first card towards "mine" and back, once, so a new user
    /// sees that it swipes. Left alone if they have already taken hold of it.
    private func showSwipe() async {
        guard !hasSwiped, !reduceMotion else { return }
        try? await Task.sleep(for: .seconds(0.7))
        guard !Task.isCancelled, drag == .zero, !isLeaving, stamp == nil else { return }
        withAnimation(.smooth(duration: 0.35)) { drag.width = nudge }
        try? await Task.sleep(for: .seconds(0.7))
        guard drag == CGSize(width: nudge, height: 0), !isLeaving else { return }
        withAnimation(.spring) { drag = .zero }
    }

    /// Sends the card off one side, then brings up the next one.
    private func flyOff(towards direction: CGFloat) {
        guard !reduceMotion else {
            advance()
            return
        }
        withAnimation(.smooth(duration: 0.22)) {
            drag = CGSize(width: direction * 520, height: drag.height)
        } completion: {
            advance()
        }
    }

    private func advance() {
        withAnimation(.snappy) {
            drag = .zero
            stamp = nil
            session.swipeIndex += 1
        }
        isLeaving = false
    }

    /// Lets a debug launch show the stamp for a screenshot.
    private static var initialStamp: String? {
        #if DEBUG
        DebugSeed.requestedScreen == "stamp" ? "DIBS!" : nil
        #else
        nil
        #endif
    }

    private func goBack() {
        guard !isLeaving else { return }
        withAnimation(.snappy) {
            drag = .zero
            session.swipeIndex = max(0, session.swipeIndex - 1)
        }
    }
}
