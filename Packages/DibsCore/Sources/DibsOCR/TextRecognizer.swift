import CoreGraphics
import ImageIO
import Vision
import DibsCore

/// On-device OCR with Vision. Lives outside the app so the same call runs on
/// the phone and in `dibs-eval` on the Mac.
public enum TextRecognizer {
    public static func fragments(
        in image: CGImage,
        orientation: CGImagePropertyOrientation = .up
    ) throws -> [TextFragment] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        // Language correction tends to "fix" prices and menu names.
        request.usesLanguageCorrection = false

        let handler = VNImageRequestHandler(cgImage: image, orientation: orientation)
        try handler.perform([request])

        return (request.results ?? []).compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            var fragment = fragment(
                candidate.string,
                bottomLeft: observation.bottomLeft,
                bottomRight: observation.bottomRight,
                topLeft: observation.topLeft,
                box: observation.boundingBox
            )
            fragment.confidence = Double(candidate.confidence)
            return fragment
        }
    }

    /// The same text read through Vision's document reader, which finds lines
    /// by understanding the page layout first.
    @available(iOS 26.0, macOS 26.0, *)
    public static func documentFragments(
        in image: CGImage,
        orientation: CGImagePropertyOrientation = .up
    ) async throws -> [TextFragment] {
        var request = RecognizeDocumentsRequest()
        request.textRecognitionOptions.useLanguageCorrection = false

        let observations = try await request.perform(on: image, orientation: orientation)
        return observations.flatMap(\.document.text.lines).map { line in
            fragment(
                line.transcript,
                bottomLeft: line.bottomLeft.cgPoint,
                bottomRight: line.bottomRight.cgPoint,
                topLeft: line.topLeft.cgPoint,
                box: line.boundingBox.cgRect
            )
        }
    }

    private static func fragment(
        _ text: String,
        bottomLeft: CGPoint,
        bottomRight: CGPoint,
        topLeft: CGPoint,
        box: CGRect
    ) -> TextFragment {
        // The corners follow the text itself, so they give its tilt.
        let run = bottomRight.x - bottomLeft.x
        let rise = bottomRight.y - bottomLeft.y
        return TextFragment(
            text: text,
            minX: Double(box.minX),
            midY: Double(box.midY),
            height: Double(hypot(topLeft.x - bottomLeft.x, topLeft.y - bottomLeft.y)),
            midX: Double(box.midX),
            width: Double(box.width),
            slope: run > 0 ? Double(rise / run) : 0
        )
    }
}
