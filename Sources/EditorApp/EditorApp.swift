import SwiftUI
#if os(iOS)
import UIKit
#endif

@main
struct EditorApp: App {
#if os(iOS)
    @UIApplicationDelegateAdaptor(EditorIOSAppDelegate.self) private var appDelegate
#endif

    var body: some Scene {
        WindowGroup {
            AppEnvironment.makeRootView()
        }
    }
}

#if os(iOS)
final class EditorIOSAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        completionHandler(AppEnvironment.handleRemoteNotificationSync().uiBackgroundFetchResult)
    }
}

private extension RemoteNotificationSyncResult {
    var uiBackgroundFetchResult: UIBackgroundFetchResult {
        switch self {
        case .newData:
            return .newData
        case .noData:
            return .noData
        case .failed:
            return .failed
        }
    }
}
#endif
