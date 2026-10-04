import Foundation
import ImageIO
import DibsCore
import DibsOCR
import DibsEval
import DibsLLM

// Scores the receipt pipeline against a folder of photos.
//
//   dibs-eval <folder> [--dump] [--replay] [--failures] [--lines] [--documents]
//
// Each `x.jpg` is scored against `x.json` (see `GroundTruth`).
//   --dump      save each photo's OCR fragments to `x.ocr.json`
//   --replay    read `x.ocr.json` instead of running OCR, when it exists
//   --failures  list every receipt that is not perfect, with what was parsed
//   --lines     print the OCR lines of every photo (for writing ground truth)
//   --llm       let the on-device language model retry receipts that don't add up
//   --documents read text with RecognizeDocumentsRequest instead (cached as
//               `x.doc.ocr.json`), to compare the two OCR backends

let arguments = CommandLine.arguments.dropFirst()
let flags = Set(arguments.filter { $0.hasPrefix("--") })
guard let folder = arguments.first(where: { !$0.hasPrefix("--") }) else {
    print("usage: dibs-eval <folder> [--dump] [--replay] [--failures] [--lines] [--documents]")
    exit(2)
}

let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "heic"]
let root = URL(fileURLWithPath: folder)
let images = (FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)?
    .compactMap { $0 as? URL } ?? [])
    .filter { imageExtensions.contains($0.pathExtension.lowercased()) }
    .sorted { $0.path < $1.path }

func recognize(_ url: URL) async throws -> [TextFragment] {
    let documents = flags.contains("--documents")
    let cached = url.deletingPathExtension().appendingPathExtension(documents ? "doc.ocr.json" : "ocr.json")
    if flags.contains("--replay"), let data = try? Data(contentsOf: cached) {
        return try JSONDecoder().decode([TextFragment].self, from: data)
    }
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw CocoaError(.fileReadCorruptFile)
    }
    let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
    let orientation = (properties?[kCGImagePropertyOrientation] as? UInt32)
        .flatMap(CGImagePropertyOrientation.init(rawValue:)) ?? .up

    let fragments: [TextFragment]
    if documents, #available(macOS 26.0, *) {
        fragments = try await TextRecognizer.documentFragments(in: image, orientation: orientation)
    } else {
        fragments = try TextRecognizer.fragments(in: image, orientation: orientation)
    }
    if flags.contains("--dump") {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(fragments).write(to: cached)
    }
    return fragments
}

var summary = Summary()
var llmWins = 0
for url in images {
    let name = url.path.replacingOccurrences(of: root.path + "/", with: "")
    let truthURL = url.deletingPathExtension().appendingPathExtension("json")
    let truth = (try? Data(contentsOf: truthURL)).flatMap { try? JSONDecoder().decode(GroundTruth.self, from: $0) }
    guard truth != nil || flags.contains("--lines") || flags.contains("--dump") else { continue }

    let lines: [String]
    do {
        lines = OCRRowGrouper.lines(from: try await recognize(url))
    } catch {
        print("\(name): \(error.localizedDescription)")
        continue
    }
    if flags.contains("--lines") {
        print("==== \(name)")
        lines.forEach { print($0) }
    }
    guard let truth else { continue }

    var parsed = ReceiptTextParser.parse(lines: lines)
    if flags.contains("--llm"), #available(macOS 26.0, *),
       let improved = await LanguageModelReceiptParser.improve(parsed, lines: lines) {
        parsed = improved
        llmWins += 1
    }
    let score = Score(parsed: parsed, truth: truth)
    summary.add(score)

    if flags.contains("--failures"), !score.isPerfect {
        print("---- \(name): \(score.matchedItems)/\(score.truthItems) items, \(score.parsedItems) parsed")
        for item in parsed.items {
            print("   \(item.quantity) x \(item.name)  \(item.lineTotal)")
        }
        print("   subtotal \(parsed.subtotal.map { "\($0)" } ?? "-")  tax \(parsed.tax)  total \(parsed.total.map { "\($0)" } ?? "-")")
    }
}

print(summary.report)
if flags.contains("--llm") {
    if #available(macOS 26.0, *), !LanguageModelReceiptParser.isAvailable {
        print("language model     \(LanguageModelReceiptParser.availability)")
    } else {
        print("language model     replaced \(llmWins) parses")
    }
}
