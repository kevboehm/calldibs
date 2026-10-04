import UIKit
import DibsCore

/// Opens Venmo for a prefilled pay/request, falling back to the web form when
/// the Venmo app is not installed.
///
/// We deliberately do not call `canOpenURL`, so there is no need for a
/// `LSApplicationQueriesSchemes` entry in Info.plist. `UIApplication.open`
/// reports success/failure in its completion handler, and we use that to decide
/// whether to fall back to `https://venmo.com`.
enum VenmoLauncher {

    /// Hand off to Venmo. On the main actor because it touches `UIApplication`.
    @MainActor
    static func open(action: VenmoAction, handle: String, amount: Decimal, note: String) {
        let app = UIApplication.shared
        let webURL = VenmoLink.web(action: action, handle: handle, amount: amount, note: note)

        guard let appURL = VenmoLink.app(action: action, handle: handle, amount: amount, note: note) else {
            // Nil only for a bad amount; nothing sensible to open.
            if let webURL { app.open(webURL) }
            return
        }

        app.open(appURL) { opened in
            if !opened, let webURL {
                app.open(webURL)
            }
        }
    }
}
