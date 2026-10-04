import SwiftUI

/// The printed row an item was read from, cut out of the receipt photo, so a
/// misread name or price can be fixed without finding the paper.
struct ScanStrip: View {
    let image: UIImage

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: 44, alignment: .leading)
            .clipShape(.rect(cornerRadius: 6))
            // The fields beneath say the same thing.
            .accessibilityHidden(true)
    }
}
