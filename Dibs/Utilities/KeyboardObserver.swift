import SwiftUI
import UIKit

extension View {
    /// Reports whether the software keyboard is on screen.
    func onKeyboardVisibilityChange(_ action: @escaping (Bool) -> Void) -> some View {
        self
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                action(true)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                action(false)
            }
    }
}
