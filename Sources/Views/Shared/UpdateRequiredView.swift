import SwiftUI
import UIKit

/// Full-screen, non-dismissible gate shown once `AppUpdateChecker` finds a
/// newer App Store version -- intentionally has no "not now"/close button,
/// mirroring how iOS's own "Update Required" prompt lets you go straight to
/// the App Store and nowhere else.
struct UpdateRequiredView: View {
    let appStoreURL: URL?

    var body: some View {
        ZStack {
            Theme.pageBackground.ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Theme.mint)

                Text("Update Available")
                    .font(.themeHeading(22))

                Text("A new version of this app is available. Please update to continue.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)

                Spacer()

                Button {
                    guard let appStoreURL else { return }
                    UIApplication.shared.open(appStoreURL)
                } label: {
                    Text("Update")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.mint, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
    }
}

#Preview {
    UpdateRequiredView(appStoreURL: URL(string: "https://apps.apple.com"))
}
