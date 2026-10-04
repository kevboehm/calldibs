import Foundation

/// Someone taking a turn with the bill. Each person sets their own tip.
public struct Person: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public var name: String
    public var tip: TipConfig

    public init(id: UUID = UUID(), name: String, tip: TipConfig = .default) {
        self.id = id
        self.name = name
        self.tip = tip
    }
}
