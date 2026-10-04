import SwiftUI

/// A short burst of confetti from the middle of the view, fired each time
/// `trigger` changes. Purely decorative and never intercepts touches.
struct ConfettiBurst: View {
    let trigger: Int

    @State private var startDate: Date?
    @State private var pieces: [Piece] = []

    private let duration = 0.9
    private let gravity = 900.0

    private struct Piece {
        var velocity: CGVector
        var spin: Double
        var size: Double
        var color: Color
    }

    var body: some View {
        TimelineView(.animation(paused: startDate == nil)) { context in
            Canvas { canvas, size in
                guard let startDate else { return }
                let time = context.date.timeIntervalSince(startDate)
                guard time < duration else { return }

                for piece in pieces {
                    var layer = canvas
                    layer.opacity = 1 - time / duration
                    layer.translateBy(
                        x: size.width / 2 + piece.velocity.dx * time,
                        y: size.height * 0.42 + piece.velocity.dy * time + 0.5 * gravity * time * time
                    )
                    layer.rotate(by: .radians(piece.spin * time))
                    let rect = CGRect(x: -piece.size / 2, y: -piece.size / 4, width: piece.size, height: piece.size / 2)
                    layer.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(piece.color))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: trigger) { fire() }
    }

    private func fire() {
        let colors: [Color] = [.accentColor, .yellow, Theme.Palette.notMine, Theme.Palette.paper]
        pieces = (0..<26).map { _ in
            let angle = Double.random(in: 0..<(2 * .pi))
            let speed = Double.random(in: 180...460)
            return Piece(
                velocity: CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed - 260),
                spin: Double.random(in: -9...9),
                size: Double.random(in: 8...14),
                color: colors.randomElement() ?? .accentColor
            )
        }
        let started = Date.now
        startDate = started
        Task {
            try? await Task.sleep(for: .seconds(duration))
            // A newer burst may have started; only stop our own.
            if startDate == started { startDate = nil }
        }
    }
}
