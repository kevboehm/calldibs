import Foundation

/// One recognized piece of text with its position, in normalized image
/// coordinates with the origin at the bottom-left (Vision's convention).
public struct TextFragment: Hashable, Sendable, Codable {
    public var text: String
    public var minX: Double
    public var midX: Double
    public var midY: Double
    public var width: Double
    /// Height of the text itself, not of its (tilt-inflated) bounding box.
    public var height: Double
    /// Rise over run of the text's baseline. Zero for level text.
    public var slope: Double
    /// 0...1: how sure the OCR was of this reading.
    public var confidence: Double

    public init(
        text: String,
        minX: Double,
        midY: Double,
        height: Double,
        midX: Double? = nil,
        width: Double = 0,
        slope: Double = 0,
        confidence: Double = 1
    ) {
        self.text = text
        self.minX = minX
        self.midX = midX ?? minX
        self.midY = midY
        self.width = width
        self.height = height
        self.slope = slope
        self.confidence = confidence
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decode(String.self, forKey: .text)
        minX = try container.decode(Double.self, forKey: .minX)
        midX = try container.decode(Double.self, forKey: .midX)
        midY = try container.decode(Double.self, forKey: .midY)
        width = try container.decode(Double.self, forKey: .width)
        height = try container.decode(Double.self, forKey: .height)
        slope = try container.decode(Double.self, forKey: .slope)
        // Fragments saved before confidence was recorded.
        confidence = try container.decodeIfPresent(Double.self, forKey: .confidence) ?? 1
    }
}

/// One printed row: its text, and where it sits in the image, in the same
/// normalized bottom-left coordinates as its fragments.
public struct OCRRow: Hashable, Sendable, Codable {
    public var text: String
    public var minX: Double
    public var minY: Double
    public var width: Double
    public var height: Double
    /// The least sure of the row's fragments.
    public var confidence: Double
    /// Where each fragment of `text` sits along the row, left to right, so
    /// a name's right edge can be found. Nil for rows saved before this was
    /// recorded.
    public var spans: [Span]?

    /// One fragment's place in its row.
    public struct Span: Hashable, Sendable, Codable {
        public var minX: Double
        public var width: Double
        /// Height of the text itself.
        public var height: Double
        /// How many characters of the row's text it holds.
        public var length: Int

        public init(minX: Double, width: Double, height: Double, length: Int) {
            self.minX = minX
            self.width = width
            self.height = height
            self.length = length
        }
    }

    public init(
        text: String,
        minX: Double,
        minY: Double,
        width: Double,
        height: Double,
        confidence: Double = 1,
        spans: [Span]? = nil
    ) {
        self.text = text
        self.minX = minX
        self.minY = minY
        self.width = width
        self.height = height
        self.confidence = confidence
        self.spans = spans
    }
}

/// OCR often returns an item's name and its price as separate fragments.
/// This rejoins fragments that sit on the same printed row, even when the
/// receipt was photographed at an angle and the rows run uphill.
public enum OCRRowGrouper {
    public static func lines(from fragments: [TextFragment]) -> [String] {
        rows(from: fragments).map(\.text)
    }

    public static func rows(from fragments: [TextFragment]) -> [OCRRow] {
        let skew = Skew(fragments)
        let leveled = fragments
            .map { (fragment: $0, y: skew.leveledY(of: $0)) }
            .sorted { $0.y > $1.y }

        var rows: [[(fragment: TextFragment, y: Double)]] = []
        for entry in leveled {
            if let anchor = rows.last?.first,
               abs(anchor.y - entry.y) < 0.6 * min(anchor.fragment.height, entry.fragment.height) {
                rows[rows.count - 1].append(entry)
            } else {
                rows.append([entry])
            }
        }

        return rows.map { row in
            let fragments = row.map(\.fragment).sorted { $0.minX < $1.minX }
            let minX = fragments.map(\.minX).min() ?? 0
            let maxX = fragments.map { $0.minX + $0.width }.max() ?? 0
            let minY = fragments.map { $0.midY - $0.height / 2 }.min() ?? 0
            let maxY = fragments.map { $0.midY + $0.height / 2 }.max() ?? 0
            return OCRRow(
                text: fragments.map(\.text).joined(separator: " "),
                minX: minX,
                minY: minY,
                width: maxX - minX,
                height: maxY - minY,
                confidence: fragments.map(\.confidence).min() ?? 1,
                spans: fragments.map {
                    OCRRow.Span(minX: $0.minX, width: $0.width, height: $0.height, length: $0.text.count)
                }
            )
        }
    }

    /// How steeply the printed rows run at each height in the photo. A tilted
    /// receipt has one slope throughout; perspective makes it drift from top to
    /// bottom, so the slope is fitted as a straight-line function of y, trusting
    /// wide fragments most because their baselines are measured best.
    private struct Skew {
        private var intercept = 0.0
        private var gradient = 0.0

        init(_ fragments: [TextFragment]) {
            let measured = fragments.filter { $0.width > 0 }
            let weight = measured.reduce(0) { $0 + $1.width }
            guard weight > 0 else { return }

            let meanY = measured.reduce(0) { $0 + $1.width * $1.midY } / weight
            let meanSlope = measured.reduce(0) { $0 + $1.width * $1.slope } / weight
            let variance = measured.reduce(0) { $0 + $1.width * ($1.midY - meanY) * ($1.midY - meanY) }
            let covariance = measured.reduce(0) { $0 + $1.width * ($1.midY - meanY) * ($1.slope - meanSlope) }

            gradient = variance > 1e-9 ? covariance / variance : 0
            intercept = meanSlope - gradient * meanY
        }

        /// Where the fragment's row crosses the middle of the image.
        func leveledY(of fragment: TextFragment) -> Double {
            let slope = intercept + gradient * fragment.midY
            return fragment.midY - slope * (fragment.midX - 0.5)
        }
    }
}
