import SwiftUI

/// A rounded top with a zigzag bottom edge, like paper torn off a till roll.
struct TornPaper: Shape {
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 18
        let tooth: CGFloat = 8
        let count = max(1, Int((rect.width / (tooth * 2)).rounded()))
        let step = rect.width / CGFloat(count)

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY - tooth))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + radius), control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - tooth))
        for index in 0..<count {
            let right = rect.maxX - CGFloat(index) * step
            path.addLine(to: CGPoint(x: right - step / 2, y: rect.maxY))
            path.addLine(to: CGPoint(x: right - step, y: rect.maxY - tooth))
        }
        path.closeSubpath()
        return path
    }
}

/// A horizontal line through the middle of its frame, for dashed rules.
struct RuleLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}
