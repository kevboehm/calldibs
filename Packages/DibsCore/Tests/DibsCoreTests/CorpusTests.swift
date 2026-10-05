import Foundation
import Testing
import DibsCore
import DibsEval

/// Replays saved OCR output through the grouper and parser. No images or
/// Vision involved, so these run anywhere and in milliseconds.
@Suite struct CorpusTests {
    /// Receipts under `Fixtures/` are ones the parser gets entirely right.
    /// Each must stay that way.
    @Test func fixturesStayPerfect() throws {
        let fixtures = try #require(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        for (name, score) in try scores(under: fixtures) {
            #expect(score.isPerfect, "\(name) no longer parses perfectly")
        }
    }

    /// The downloaded corpus is not in the repo. Where `dibs-eval --dump` has
    /// been run, the share of perfect receipts must not fall.
    @Test func corpusScoreDoesNotRegress() throws {
        let corpus = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Corpus/wildreceipt")
        var summary = Summary()
        for (_, score) in try scores(under: corpus) { summary.add(score) }
        guard summary.receipts > 0 else { return }
        #expect(summary.perfectRate >= 0.62, "\(summary.report)")
    }

    private func scores(under folder: URL) throws -> [(name: String, score: Score)] {
        let files = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL } ?? []
        return try files.filter { $0.lastPathComponent.hasSuffix(".ocr.json") && !$0.lastPathComponent.hasSuffix(".doc.ocr.json") }
            .compactMap { ocr in
                let truthURL = ocr.deletingPathExtension().deletingPathExtension().appendingPathExtension("json")
                guard let truthData = try? Data(contentsOf: truthURL) else { return nil }
                let truth = try JSONDecoder().decode(GroundTruth.self, from: truthData)
                let fragments = try JSONDecoder().decode([TextFragment].self, from: Data(contentsOf: ocr))
                let receipt = ReceiptTextParser.parse(rows: OCRRowGrouper.rows(from: fragments))
                return (ocr.lastPathComponent, Score(parsed: receipt, truth: truth))
            }
    }
}
