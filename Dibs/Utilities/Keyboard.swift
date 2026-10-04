import UIKit

enum Keyboard {
    /// Ends editing so number fields commit their value before we read it.
    static func dismiss() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
