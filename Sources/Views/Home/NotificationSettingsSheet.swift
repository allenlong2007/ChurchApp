import SwiftUI
import UIKit

/// Presented from the bell icon on Home. Lets the user opt in to a local
/// notification whenever the app checks for content and finds something
/// new -- see NotificationManager for why this can't be a true always-on
/// push notification without a backend.
struct NotificationSettingsSheet: View {
    @AppStorage(newContentNotificationsKey) private var notificationsEnabled = false
    @EnvironmentObject private var notifications: NotificationManager
    @Environment(\.dismiss) private var dismiss
    @State private var showSystemSettingsPrompt = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("New Content Notifications", isOn: Binding(
                        get: { notificationsEnabled },
                        set: { toggle($0) }
                    ))
                } footer: {
                    Text("Get notified when new podcasts or hymns are added. This is checked whenever the app is opened, refreshed, or you pull to refresh -- it can't notify you while the app is fully closed.")
                }

                if showSystemSettingsPrompt {
                    Section {
                        Button("Open iOS Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    } footer: {
                        Text("Notifications for this app are turned off in iOS Settings. Turn them on there first, then come back and enable this.")
                    }
                }
            }
            .navigationTitle(Text("Notifications"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            await notifications.refreshAuthorizationStatus()
            showSystemSettingsPrompt = notificationsEnabled && !notifications.isAuthorized
        }
    }

    private func toggle(_ newValue: Bool) {
        guard newValue else {
            notificationsEnabled = false
            return
        }
        Task {
            let granted = await notifications.requestAuthorization()
            notificationsEnabled = granted
            showSystemSettingsPrompt = !granted
        }
    }
}

#Preview {
    NotificationSettingsSheet()
        .environmentObject(NotificationManager.shared)
}
