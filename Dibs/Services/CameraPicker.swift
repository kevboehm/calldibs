import SwiftUI
import UIKit
import VisionKit

/// The system document scanner, wrapped for SwiftUI. It finds the receipt's
/// edges, flattens the perspective and cleans up the contrast, which gives
/// the OCR a far better image than a plain photo.
struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    let onError: (Error) -> Void
    @Environment(\.dismiss) private var dismiss

    static var isAvailable: Bool {
        VNDocumentCameraViewController.isSupported
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let parent: CameraPicker

        init(_ parent: CameraPicker) { self.parent = parent }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            let pages = (0..<scan.pageCount).map(scan.imageOfPage(at:))
            if let image = Self.stacked(pages) {
                parent.onImage(image)
            }
            parent.dismiss()
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.dismiss()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            parent.onError(error)
            parent.dismiss()
        }

        /// A long receipt scanned in several pages, joined top to bottom so it
        /// reads as one.
        private static func stacked(_ pages: [UIImage]) -> UIImage? {
            guard pages.count > 1, let width = pages.map(\.size.width).max() else { return pages.first }
            let heights = pages.map { $0.size.height * width / $0.size.width }
            let size = CGSize(width: width, height: heights.reduce(0, +))
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            return UIGraphicsImageRenderer(size: size, format: format).image { _ in
                var y: CGFloat = 0
                for (page, height) in zip(pages, heights) {
                    page.draw(in: CGRect(x: 0, y: y, width: width, height: height))
                    y += height
                }
            }
        }
    }
}
