import SwiftUI
import UIKit
import CoreTransferable

/// A `ShareCard` that the share sheet can send as a PNG. The picture is only
/// rendered once the user actually picks somewhere to send it.
struct ShareCardImage: Transferable {
    let card: ShareCard

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { image in
            try await image.png()
        }
        .suggestedFileName("Call Dibs.png")
    }

    @MainActor
    func png() throws -> Data {
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        guard let data = renderer.uiImage?.pngData() else {
            throw CocoaError(.fileWriteUnknown)
        }
        return data
    }
}
