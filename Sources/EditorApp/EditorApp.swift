import SwiftUI
#if os(macOS)
import AppKit
#endif
#if os(iOS)
import UIKit
#endif

@main
struct EditorApp: App {
#if os(macOS)
    @NSApplicationDelegateAdaptor(EditorMacAppDelegate.self) private var appDelegate
#endif
#if os(iOS)
    @UIApplicationDelegateAdaptor(EditorIOSAppDelegate.self) private var appDelegate
#endif

    var body: some Scene {
        WindowGroup {
            AppEnvironment.makeRootView()
        }
        .commands {
            EditorEditingCommands()
        }
    }
}

private struct EditorEditingCommands: Commands {
    @FocusedValue(\.insertMarkdownLinkAction) private var insertMarkdownLinkAction

    var body: some Commands {
        CommandGroup(after: .textEditing) {
            Button("Insert Link") {
                insertMarkdownLinkAction?()
            }
            .keyboardShortcut("k", modifiers: .command)
            .disabled(insertMarkdownLinkAction == nil)
        }
    }
}

#if os(macOS)
@MainActor
final class EditorMacAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.requestMainWindowIfNeeded()
        }
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        if MacWindowVisibilityPolicy.shouldRequestMainWindow(hasVisibleWindows: flag) {
            requestMainWindowIfNeeded(sender)
        }
        return true
    }

    private func requestMainWindowIfNeeded(_ application: NSApplication = .shared) {
        let hasVisibleWindow = application.windows.contains { window in
            window.isVisible && window.canBecomeKey
        }
        guard MacWindowVisibilityPolicy.shouldRequestMainWindow(hasVisibleWindows: hasVisibleWindow) else {
            return
        }

        application.activate(ignoringOtherApps: true)
        if application.sendAction(Selector(("newWindow:")), to: nil, from: nil) {
            return
        }
        if application.sendAction(#selector(NSResponder.newWindowForTab(_:)), to: nil, from: nil) {
            return
        }
        if application.sendAction(#selector(NSWindowController.showWindow(_:)), to: nil, from: nil) {
            return
        }

        if let fileMenu = application.mainMenu?.item(withTitle: "File")?.submenu {
            let newWindowItemIndex = fileMenu.indexOfItem(withTitle: "New Window")
            if newWindowItemIndex >= 0 {
                fileMenu.performActionForItem(at: newWindowItemIndex)
            }
        }
    }
}
#endif

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
