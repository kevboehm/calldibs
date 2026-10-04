import SwiftUI

/// The scanned receipt, full width, to check the bill against. Pinch or
/// double tap to zoom.
struct ScanViewer: View {
    let image: UIImage

    @Environment(\.dismiss) private var dismiss
    @State private var zoom: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1

    private let maxZoom: CGFloat = 4

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollView([.horizontal, .vertical]) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: proxy.size.width * min(max(1, zoom * pinch), maxZoom))
                        .accessibilityLabel("Photo of the receipt")
                        .onTapGesture(count: 2) {
                            withAnimation(.snappy) { zoom = zoom > 1 ? 1 : 2.5 }
                        }
                }
                .simultaneousGesture(
                    MagnifyGesture()
                        .updating($pinch) { value, state, _ in state = value.magnification }
                        .onEnded { value in zoom = min(max(1, zoom * value.magnification), maxZoom) }
                )
            }
            .background(Theme.Palette.ground)
            .navigationTitle("The receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
