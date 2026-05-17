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
#if os(macOS)
        Settings {
            EditorShortcutSettingsView()
        }
#endif
    }
}

private struct EditorEditingCommands: Commands {
    @FocusedValue(\.insertMarkdownLinkAction) private var insertMarkdownLinkAction
    @FocusedValue(\.promoteDiarySelectionAction) private var promoteDiarySelectionAction
    @FocusedValue(\.createNewDocumentAction) private var createNewDocumentAction
    @FocusedValue(\.openTodayAction) private var openTodayAction
    @FocusedValue(\.navigateBackAction) private var navigateBackAction
    @FocusedValue(\.navigateForwardAction) private var navigateForwardAction
    @FocusedValue(\.showAllDocumentsAction) private var showAllDocumentsAction
    @FocusedValue(\.showFavoritesAction) private var showFavoritesAction
    @FocusedValue(\.quickOpenAction) private var quickOpenAction

    @AppStorage(EditorShortcutCommand.newDocument.userDefaultsKey) private var newDocumentShortcut = EditorShortcutCommand.newDocument.defaultShortcutRawValue
    @AppStorage(EditorShortcutCommand.openToday.userDefaultsKey) private var openTodayShortcut = EditorShortcutCommand.openToday.defaultShortcutRawValue
    @AppStorage(EditorShortcutCommand.navigateBack.userDefaultsKey) private var navigateBackShortcut = EditorShortcutCommand.navigateBack.defaultShortcutRawValue
    @AppStorage(EditorShortcutCommand.navigateForward.userDefaultsKey) private var navigateForwardShortcut = EditorShortcutCommand.navigateForward.defaultShortcutRawValue
    @AppStorage(EditorShortcutCommand.convertBlockToPage.userDefaultsKey) private var convertBlockToPageShortcut = EditorShortcutCommand.convertBlockToPage.defaultShortcutRawValue
    @AppStorage(EditorShortcutCommand.quickOpen.userDefaultsKey) private var quickOpenShortcut = EditorShortcutCommand.quickOpen.defaultShortcutRawValue
    @AppStorage(EditorShortcutCommand.showAllDocuments.userDefaultsKey) private var showAllDocumentsShortcut = EditorShortcutCommand.showAllDocuments.defaultShortcutRawValue
    @AppStorage(EditorShortcutCommand.showFavorites.userDefaultsKey) private var showFavoritesShortcut = EditorShortcutCommand.showFavorites.defaultShortcutRawValue
    @AppStorage(EditorShortcutCommand.insertMarkdownLink.userDefaultsKey) private var insertMarkdownLinkShortcut = EditorShortcutCommand.insertMarkdownLink.defaultShortcutRawValue

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("新建文档") {
                createNewDocumentAction?()
            }
            .editorKeyboardShortcut(newDocumentShortcut, fallback: .newDocument)
            .disabled(createNewDocumentAction == nil)
        }

        CommandMenu("导航") {
            Button("后退") {
                navigateBackAction?()
            }
            .editorKeyboardShortcut(navigateBackShortcut, fallback: .navigateBack)
            .disabled(navigateBackAction == nil)

            Button("前进") {
                navigateForwardAction?()
            }
            .editorKeyboardShortcut(navigateForwardShortcut, fallback: .navigateForward)
            .disabled(navigateForwardAction == nil)

            Button("跳到今天") {
                openTodayAction?()
            }
            .editorKeyboardShortcut(openTodayShortcut, fallback: .openToday)
            .disabled(openTodayAction == nil)

            Divider()

            Button("快速打开") {
                quickOpenAction?()
            }
            .editorKeyboardShortcut(quickOpenShortcut, fallback: .quickOpen)
            .disabled(quickOpenAction == nil)

            Button("全部文档") {
                showAllDocumentsAction?()
            }
            .editorKeyboardShortcut(showAllDocumentsShortcut, fallback: .showAllDocuments)
            .disabled(showAllDocumentsAction == nil)

            Button("收藏") {
                showFavoritesAction?()
            }
            .editorKeyboardShortcut(showFavoritesShortcut, fallback: .showFavorites)
            .disabled(showFavoritesAction == nil)
        }

        CommandGroup(after: .textEditing) {
            Button("插入链接") {
                insertMarkdownLinkAction?()
            }
            .editorKeyboardShortcut(insertMarkdownLinkShortcut, fallback: .insertMarkdownLink)
            .disabled(insertMarkdownLinkAction == nil)

            Button("变成页面") {
                promoteDiarySelectionAction?()
            }
            .editorKeyboardShortcut(convertBlockToPageShortcut, fallback: .convertBlockToPage)
            .disabled(promoteDiarySelectionAction == nil)
        }
    }
}

private extension View {
    func editorKeyboardShortcut(
        _ rawValue: String,
        fallback command: EditorShortcutCommand
    ) -> some View {
        let shortcut = EditorKeyboardShortcut(rawValue: rawValue)
            ?? EditorKeyboardShortcut(rawValue: command.defaultShortcutRawValue)!
        return keyboardShortcut(shortcut.keyEquivalent, modifiers: shortcut.modifiers)
    }
}

#if os(macOS)
private struct EditorShortcutSettingsView: View {
    var body: some View {
        Form {
            Section("快捷键") {
                ForEach(EditorShortcutCommand.allCases) { command in
                    ShortcutSettingRow(command: command)
                }
            }

            Button("恢复 Craft 默认快捷键") {
                restoreDefaults()
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 420)
    }

    private func restoreDefaults() {
        for command in EditorShortcutCommand.allCases {
            UserDefaults.standard.set(command.defaultShortcutRawValue, forKey: command.userDefaultsKey)
        }
    }
}

private struct ShortcutSettingRow: View {
    let command: EditorShortcutCommand
    @AppStorage private var rawValue: String

    init(command: EditorShortcutCommand) {
        self.command = command
        _rawValue = AppStorage(
            wrappedValue: command.defaultShortcutRawValue,
            command.userDefaultsKey
        )
    }

    var body: some View {
        HStack {
            Text(command.title)
            Spacer(minLength: 16)
            TextField(command.defaultShortcutRawValue, text: $rawValue)
                .textFieldStyle(.roundedBorder)
                .frame(width: 140)
                .monospaced()
                .accessibilityIdentifier("editor.shortcut.\(command.rawValue)")
        }
    }
}
#endif

#if os(macOS)
@MainActor
final class EditorMacAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        false
    }

    func applicationShouldRestoreApplicationState(_ app: NSApplication) -> Bool {
        false
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
