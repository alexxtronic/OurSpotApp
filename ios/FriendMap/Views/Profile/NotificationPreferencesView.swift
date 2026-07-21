import SwiftUI

/// Notification preferences settings view
struct NotificationPreferencesView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var notificationsEnabled = true
    @State private var chatNotificationsEnabled = true
    @State private var isLoading = false
    @State private var showPermissionAlert = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("All Notifications", isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { _, newValue in
                            savePreferences()
                        }
                } footer: {
                    Text("Turn off to disable all push notifications from OurSpot.")
                }
                
                Section {
                    Toggle("Chat Messages", isOn: $chatNotificationsEnabled)
                        .disabled(!notificationsEnabled)
                        .onChange(of: chatNotificationsEnabled) { _, newValue in
                            savePreferences()
                        }
                } header: {
                    Text("Notification Types")
                } footer: {
                    Text("Get notified when someone sends a message in an event chat you're part of.")
                }
                
                Section {
                    Button {
                        Task {
                            await requestNotificationPermission()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "bell.badge")
                            Text("Request Notification Permission")
                        }
                    }
                } footer: {
                    Text("Tap to enable push notifications for this device.")
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadPreferences()
            }
            .overlay {
                if isLoading {
                    ProgressView()
                }
            }
            .alert("Permission Required", isPresented: $showPermissionAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Push notifications are disabled in Settings. Please enable them to receive chat notifications.")
            }
        }
    }
    
    private func loadPreferences() {
        let user = sessionStore.currentUser
        notificationsEnabled = user.notificationsEnabled ?? true
        chatNotificationsEnabled = user.chatNotificationsEnabled ?? true
    }
    
    private func savePreferences() {
        Task {
            await sessionStore.updateNotificationPreferences(
                notificationsEnabled: notificationsEnabled,
                chatNotificationsEnabled: chatNotificationsEnabled
            )
        }
    }
    
    private func requestNotificationPermission() async {
        let status = await PushNotificationManager.checkAuthorizationStatus()
        
        switch status {
        case .notDetermined:
            let granted = await PushNotificationManager.requestPermission()
            if granted {
                HapticManager.success()
            }
        case .denied:
            showPermissionAlert = true
        case .authorized, .provisional, .ephemeral:
            await PushNotificationManager.registerIfAuthorized()
            HapticManager.success()
        @unknown default:
            break
        }
    }
}

#Preview {
    NotificationPreferencesView()
        .environmentObject(SessionStore())
}
