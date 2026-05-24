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
                .onAppear {
                    EditorBundledFontRegistry.registerBundledFontsIfNeeded()
                }
        }
#if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1600, height: 860)
#endif
        .commands {
            EditorEditingCommands()
        }
#if os(macOS)
        Settings {
            EditorSettingsView()
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
    @FocusedValue(\.toggleFocusModeAction) private var toggleFocusModeAction
    @FocusedValue(\.quickOpenAction) private var quickOpenAction

    @AppStorage(EditorShortcutCommand.newDocument.userDefaultsKey) private var newDocumentShortcut = EditorShortcutCommand.newDocument.defaultShortcutRawValue
    @AppStorage(EditorShortcutCommand.openToday.userDefaultsKey) private var openTodayShortcut = EditorShortcutCommand.openToday.defaultShortcutRawValue
    @AppStorage(EditorShortcutCommand.navigateBack.userDefaultsKey) private var navigateBackShortcut = EditorShortcutCommand.navigateBack.defaultShortcutRawValue
    @AppStorage(EditorShortcutCommand.navigateForward.userDefaultsKey) private var navigateForwardShortcut = EditorShortcutCommand.navigateForward.defaultShortcutRawValue
    @AppStorage(EditorShortcutCommand.convertBlockToPage.userDefaultsKey) private var convertBlockToPageShortcut = EditorShortcutCommand.convertBlockToPage.defaultShortcutRawValue
    @AppStorage(EditorShortcutCommand.quickOpen.userDefaultsKey) private var quickOpenShortcut = EditorShortcutCommand.quickOpen.defaultShortcutRawValue
    @AppStorage(EditorShortcutCommand.showAllDocuments.userDefaultsKey) private var showAllDocumentsShortcut = EditorShortcutCommand.showAllDocuments.defaultShortcutRawValue
    @AppStorage(EditorShortcutCommand.showFavorites.userDefaultsKey) private var showFavoritesShortcut = EditorShortcutCommand.showFavorites.defaultShortcutRawValue
    @AppStorage(EditorShortcutCommand.toggleFocusMode.userDefaultsKey) private var toggleFocusModeShortcut = EditorShortcutCommand.toggleFocusMode.defaultShortcutRawValue
    @AppStorage(EditorShortcutCommand.insertMarkdownLink.userDefaultsKey) private var insertMarkdownLinkShortcut = EditorShortcutCommand.insertMarkdownLink.defaultShortcutRawValue

    var body: some Commands {
        CommandGroup(after: .newItem) {
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

            Button("跳转到今日笔记") {
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

        CommandMenu("视图") {
            Button("专注模式") {
                toggleFocusModeAction?()
            }
            .editorKeyboardShortcut(toggleFocusModeShortcut, fallback: .toggleFocusMode)
            .disabled(toggleFocusModeAction == nil)
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
private struct EditorSettingsView: View {
    @AppStorage(EditorContentFont.appStorageKey) private var contentFontRawValue = EditorContentFont.defaultRawValue

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SettingsSection(title: "外观") {
                    HStack(spacing: 16) {
                        Text("正文字体")
                            .font(.body.weight(.medium))
                            .foregroundStyle(EditorDesignTokens.Colors.primaryText.color)
                            .frame(width: 136, alignment: .leading)

                        Spacer(minLength: 16)

                        Picker("正文字体", selection: $contentFontRawValue) {
                            ForEach(EditorContentFont.allCases) { font in
                                Text(font.displayName).tag(font.rawValue)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 190, alignment: .trailing)
                        .accessibilityIdentifier("editor.settings.content-font")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }

                SettingsSection(title: "快捷键") {
                    VStack(spacing: 0) {
                        ForEach(Array(EditorShortcutCommand.visibleCommands.enumerated()), id: \.element.id) { index, command in
                            ShortcutSettingRow(command: command)
                            if index < EditorShortcutCommand.visibleCommands.count - 1 {
                                Divider()
                                    .padding(.leading, 168)
                                    .opacity(0.55)
                            }
                        }
                    }
                }

                HStack(spacing: 16) {
                    Spacer()
                    Button {
                        restoreDefaults()
                    } label: {
                        Label("恢复默认", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .tint(EditorDesignTokens.Colors.accent.color)
                }
            }
            .padding(28)
        }
        .scrollIndicators(.hidden)
        .background(SettingsChrome.backgroundColor)
        .frame(width: 620)
        .frame(minHeight: 560)
    }

    private func restoreDefaults() {
        contentFontRawValue = EditorContentFont.defaultRawValue
        for command in EditorShortcutCommand.visibleCommands {
            UserDefaults.standard.set(command.defaultShortcutRawValue, forKey: command.userDefaultsKey)
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(EditorDesignTokens.Colors.primaryText.color)

            content
                .background(SettingsChrome.surfaceColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(SettingsChrome.borderColor, lineWidth: 1)
                )
        }
    }
}

private struct ShortcutSettingRow: View {
    let command: EditorShortcutCommand
    @AppStorage private var rawValue: String
    @State private var isRecording = false
    @State private var feedback: String?

    init(command: EditorShortcutCommand) {
        self.command = command
        _rawValue = AppStorage(
            wrappedValue: command.defaultShortcutRawValue,
            command.userDefaultsKey
        )
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(command.title)
                .font(.body.weight(.medium))
                .foregroundStyle(EditorDesignTokens.Colors.primaryText.color)
                .frame(width: 154, alignment: .leading)

            Spacer(minLength: 12)

            statusView

            ShortcutKeyCapsule(
                displayValue: shortcut?.displayValue ?? "无效",
                isRecording: isRecording,
                isInvalid: statusMessage != nil
            )
            .accessibilityIdentifier("editor.shortcut.value.\(command.rawValue)")

            Button {
                isRecording.toggle()
                if isRecording {
                    feedback = nil
                }
            } label: {
                ShortcutRecordButtonLabel(isRecording: isRecording)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("editor.shortcut.record.\(command.rawValue)")
            .background(
                ShortcutCaptureHost(
                    isRecording: $isRecording,
                    onCapture: applyRecordedShortcut,
                    onInvalidCapture: {
                        feedback = "需要修饰键"
                        isRecording = false
                    },
                    onCancel: {
                        feedback = nil
                        isRecording = false
                    }
                )
                .frame(width: 0, height: 0)
            )

            Button {
                rawValue = command.defaultShortcutRawValue
                feedback = nil
                isRecording = false
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(EditorDesignTokens.Colors.tertiaryText.color)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("恢复默认")
            .accessibilityLabel("恢复默认")
            .accessibilityIdentifier("editor.shortcut.reset.\(command.rawValue)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
    }

    private var shortcut: EditorKeyboardShortcut? {
        EditorKeyboardShortcut(rawValue: rawValue)
    }

    private var statusMessage: String? {
        if let feedback {
            return feedback
        }
        guard shortcut != nil else {
            return "不可用"
        }
        if let conflict = EditorShortcutConfiguration().conflictingCommand(for: rawValue, excluding: command) {
            return "和 \(conflict.title) 冲突"
        }
        return nil
    }

    @ViewBuilder
    private var statusView: some View {
        if let statusMessage {
            Text(statusMessage)
                .font(.caption.weight(.medium))
                .foregroundStyle(SettingsChrome.dangerColor)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(width: 108, alignment: .trailing)
                .accessibilityIdentifier("editor.shortcut.status.\(command.rawValue)")
        } else {
            Color.clear
                .frame(width: 108, height: 1)
        }
    }

    private func applyRecordedShortcut(_ recordedRawValue: String) {
        guard let recordedShortcut = EditorKeyboardShortcut(rawValue: recordedRawValue) else {
            feedback = "不可用"
            isRecording = false
            return
        }

        if let conflict = EditorShortcutConfiguration().conflictingCommand(
            for: recordedShortcut.rawValue,
            excluding: command
        ) {
            feedback = "和 \(conflict.title) 冲突"
            isRecording = false
            return
        }

        rawValue = recordedShortcut.rawValue
        feedback = nil
        isRecording = false
    }
}

private struct ShortcutRecordButtonLabel: View {
    let isRecording: Bool

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: isRecording ? "record.circle.fill" : "record.circle")
                .font(.system(size: 13, weight: .semibold))
            Text(isRecording ? "按键" : "录制")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(isRecording ? Color.white : EditorDesignTokens.Colors.primaryText.color)
        .frame(width: 68, height: 28)
        .background(
            isRecording
                ? SettingsChrome.recordingColor
                : SettingsChrome.subtleControlColor,
            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(isRecording ? Color.clear : SettingsChrome.borderColor, lineWidth: 1)
        )
    }
}

private struct ShortcutKeyCapsule: View {
    let displayValue: String
    let isRecording: Bool
    let isInvalid: Bool

    var body: some View {
        Text(isRecording ? "录制中" : displayValue)
            .font(.system(.body, design: .monospaced).weight(.semibold))
            .foregroundStyle(isInvalid ? SettingsChrome.dangerColor : EditorDesignTokens.Colors.primaryText.color)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(width: 112, height: 30)
            .background(keyBackground, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(
                        isRecording
                            ? SettingsChrome.recordingColor.opacity(0.75)
                            : isInvalid
                                ? SettingsChrome.dangerColor.opacity(0.65)
                                : SettingsChrome.keyBorderColor,
                        lineWidth: 1
                    )
            )
    }

    private var keyBackground: Color {
        if isRecording {
            return SettingsChrome.recordingColor.opacity(0.10)
        }
        if isInvalid {
            return SettingsChrome.dangerColor.opacity(0.08)
        }
        return SettingsChrome.keycapColor
    }
}

private enum SettingsChrome {
    static let backgroundColor = EditorDesignTokens.Colors.appBackground.color
    static let surfaceColor = EditorDesignTokens.Colors.elevatedSurface.color.opacity(0.94)
    static let subtleControlColor = EditorDesignTokens.Colors.controlBackground.color
    static let keycapColor = EditorDesignTokens.Colors.controlBackgroundSubtle.color
    static let borderColor = EditorDesignTokens.Colors.border.color.opacity(0.80)
    static let keyBorderColor = EditorDesignTokens.Colors.border.color
    static let recordingColor = EditorDesignTokens.Colors.accent.color
    static let dangerColor = EditorDesignTokens.Colors.danger.color
}

private struct ShortcutCaptureHost: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onCapture: (String) -> Void
    let onInvalidCapture: () -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> ShortcutCaptureNSView {
        let view = ShortcutCaptureNSView(frame: .zero)
        view.onCapture = onCapture
        view.onInvalidCapture = onInvalidCapture
        view.onCancel = onCancel
        return view
    }

    func updateNSView(_ nsView: ShortcutCaptureNSView, context: Context) {
        nsView.onCapture = onCapture
        nsView.onInvalidCapture = onInvalidCapture
        nsView.onCancel = onCancel
        if isRecording {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        } else if nsView.window?.firstResponder === nsView {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nil)
            }
        }
    }

    final class ShortcutCaptureNSView: NSView {
        var onCapture: (String) -> Void = { _ in }
        var onInvalidCapture: () -> Void = {}
        var onCancel: () -> Void = {}

        override var acceptsFirstResponder: Bool {
            true
        }

        override func keyDown(with event: NSEvent) {
            if event.keyCode == 53 {
                onCancel()
                return
            }
            guard let rawValue = event.editorShortcutRawValue else {
                NSSound.beep()
                onInvalidCapture()
                return
            }
            onCapture(rawValue)
        }
    }
}

#endif

#if os(macOS)
@MainActor
final class EditorMacAppDelegate: NSObject, NSApplicationDelegate {
    private var keyWindowObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        keyWindowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let window = notification.object as? NSWindow else {
                return
            }
            MainActor.assumeIsolated {
                self?.configureMainWindowChrome(window)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.requestMainWindowIfNeeded()
        }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        false
    }

    func applicationShouldSaveApplicationState(_ app: NSApplication) -> Bool {
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
        let hasMainWindow = application.windows.contains { window in
            window.canBecomeKey
        }

        application.activate(ignoringOtherApps: true)
        if MacWindowVisibilityPolicy.shouldRequestMainWindow(hasVisibleWindows: hasMainWindow) {
            requestNewWindow(application)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.bringMainWindowsToFront(application)
        }
    }

    private func requestNewWindow(_ application: NSApplication) {
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

    private func bringMainWindowsToFront(_ application: NSApplication) {
        application.activate(ignoringOtherApps: true)
        for window in application.windows where window.canBecomeKey {
            configureMainWindowChrome(window)
            window.collectionBehavior = window.collectionBehavior.union(.moveToActiveSpace)
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
            window.makeMain()
        }
    }

    private func configureMainWindowChrome(_ window: NSWindow) {
        window.styleMask.insert(.fullSizeContentView)
        window.toolbar = nil
        window.title = ""
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        if #available(macOS 11.0, *) {
            window.titlebarSeparatorStyle = .none
        }
        let backgroundColor = EditorDesignTokens.Colors.appBackground.nsColor
        window.backgroundColor = backgroundColor
        window.isOpaque = false
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = backgroundColor.cgColor
        window.contentView?.superview?.wantsLayer = true
        window.contentView?.superview?.layer?.backgroundColor = backgroundColor.cgColor
    }
}
#endif

#if os(iOS)
final class EditorIOSAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        RemoteNotificationRegistrationPolicy.registerIfNeeded(
            hasCloudKitContainers: CloudKitEntitlementInspector.currentProcessHasCloudKitContainers(),
            registrar: application
        )
        if let shortcutItem = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem {
            _ = handleHomeScreenQuickAction(shortcutItem)
            return false
        }
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: nil,
            sessionRole: connectingSceneSession.role
        )
        if connectingSceneSession.role == .windowApplication {
            configuration.delegateClass = EditorIOSSceneDelegate.self
        }
        return configuration
    }

    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(handleHomeScreenQuickAction(shortcutItem))
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping @Sendable (UIBackgroundFetchResult) -> Void
    ) {
        DispatchQueue.global(qos: .utility).async {
            let result = AppEnvironment.handleRemoteNotificationSync()
            DispatchQueue.main.async {
                completionHandler(result.uiBackgroundFetchResult)
            }
        }
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        EditorLog.sync.debug(
            "remote_notification_registration_succeeded token_length=\(deviceToken.count, privacy: .public)"
        )
        AppEnvironment.recordRuntimeDiagnostic(
            eventName: "remote_notification_registration_succeeded",
            payload: ["token_length": deviceToken.count]
        )
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        EditorLog.sync.error(
            "remote_notification_registration_failed error=\(String(describing: error), privacy: .public)"
        )
        AppEnvironment.recordRuntimeDiagnostic(
            eventName: "remote_notification_registration_failed",
            payload: ["error": String(describing: error)]
        )
    }

    private func handleHomeScreenQuickAction(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        dispatchHomeScreenQuickAction(shortcutItem, source: "app_delegate")
    }
}

final class EditorIOSSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let shortcutItem = connectionOptions.shortcutItem else {
            return
        }
        _ = dispatchHomeScreenQuickAction(shortcutItem, source: "scene_will_connect")
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(dispatchHomeScreenQuickAction(shortcutItem, source: "scene_perform_action_completion"))
    }
}

@discardableResult
@MainActor
private func dispatchHomeScreenQuickAction(
    _ shortcutItem: UIApplicationShortcutItem,
    source: String
) -> Bool {
    let accepted = EditorHomeScreenQuickActionCenter.shared.request(shortcutItem)
    EditorLog.input.debug(
        "home_screen_quick_action_received source=\(source, privacy: .public) type=\(shortcutItem.type, privacy: .public) accepted=\(accepted, privacy: .public)"
    )
    AppEnvironment.recordRuntimeDiagnostic(
        eventName: "home_screen_quick_action_received",
        payload: [
            "source": source,
            "type": shortcutItem.type,
            "accepted": accepted
        ]
    )
    return accepted
}

extension UIApplication: RemoteNotificationRegistering {}

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
