import SwiftUI
import UserNotifications

@main
struct ElonWatchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var introFinished = false

    var body: some Scene {
        WindowGroup {
            if introFinished {
                ContentView()
                    .frame(minWidth: 1100, minHeight: 700)
            } else {
                IntroPlayerView {
                    introFinished = true
                }
                .frame(minWidth: 1100, minHeight: 700)
            }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate,
                   UNUserNotificationCenterDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { _, _ in }

        // Dark mode always
        NSApp.appearance = NSAppearance(named: .darkAqua)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler:
            @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
