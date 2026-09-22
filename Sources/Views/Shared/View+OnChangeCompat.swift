import SwiftUI

extension View {
    /// `onChange(of:perform:)`'s single-value closure was deprecated in
    /// iOS 17 in favor of a two-parameter `{ old, new in }` closure -- but
    /// this app's deployment target is iOS 16, so the new API alone isn't
    /// available everywhere it runs. This picks whichever one the current
    /// OS actually has, so call sites keep the old single-value closure
    /// without a deprecation warning on newer OS versions.
    @ViewBuilder
    func onChangeCompat<Value: Equatable>(of value: Value, perform action: @escaping (Value) -> Void) -> some View {
        if #available(iOS 17.0, *) {
            onChange(of: value) { _, newValue in
                action(newValue)
            }
        } else {
            onChange(of: value, perform: action)
        }
    }
}
