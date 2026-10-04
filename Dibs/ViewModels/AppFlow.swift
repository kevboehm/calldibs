import UIKit
import Observation
import DibsCore

enum Route: Hashable, Codable {
    case edit
    case name
    case claim(ClaimMode)
    case summary
    case overview
}

/// Where the user is in the app and the bill they are working on. Held in one
/// observable object so pushed screens always read the live session, rather
/// than a value captured when the navigation destination was declared.
@Observable
final class AppFlow {
    var session: ClaimViewModel?
    var path: [Route] = []

    init() {
        #if DEBUG
        if let screen = DebugSeed.requestedScreen, let seed = DebugSeed.session(for: screen) {
            session = seed.session
            path = seed.path
        }
        #endif
    }

    // MARK: - Saving and restoring

    /// The bill and the user's place in it, or nil on the home screen where
    /// there is nothing to come back to.
    var savedState: Data? {
        guard let session, !path.isEmpty else { return nil }
        // A property list keeps Decimal amounts exact; JSON would not.
        return try? PropertyListEncoder().encode(session.snapshot(path: path))
    }

    func restore(from data: Data, scanImage: UIImage?) {
        guard session == nil,
              let snapshot = try? PropertyListDecoder().decode(BillSnapshot.self, from: data) else { return }
        let session = ClaimViewModel(snapshot: snapshot)
        session.scanImage = scanImage
        self.session = session
        path = snapshot.path
    }

    func start(with scanned: ScannedReceipt) {
        start(with: scanned.receipt, scan: scanned.scan, scanImage: scanned.image)
    }

    func start(with receipt: Receipt, scan: ScanSource? = nil, scanImage: UIImage? = nil) {
        let session = ClaimViewModel(receipt: receipt)
        session.scan = scan
        session.scanImage = scanImage
        if receipt.items.isEmpty { session.addItem() }
        self.session = session
        path = [.edit]
    }
}
