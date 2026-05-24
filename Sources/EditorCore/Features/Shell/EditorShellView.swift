import Foundation
import Dispatch
import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

enum EditorThemeScheme: Equatable, Sendable {
    case light
    case dark
}

struct EditorColorComponents: Equatable, Sendable {
    let red: Double
    let green: Double
    let blue: Double

    static func hex(_ red: Int, _ green: Int, _ blue: Int) -> EditorColorComponents {
        EditorColorComponents(
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255
        )
    }
}

struct EditorColorToken: Equatable, Sendable {
    private let lightComponents: EditorColorComponents
    private let darkComponents: EditorColorComponents

    var red: Double {
        lightComponents.red
    }

    var green: Double {
        lightComponents.green
    }

    var blue: Double {
        lightComponents.blue
    }

    var color: Color {
#if os(macOS)
        Color(nsColor)
#elseif os(iOS)
        Color(uiColor)
#else
        Color(red: red, green: green, blue: blue)
#endif
    }

#if os(macOS)
    var nsColor: NSColor {
        NSColor(name: nil) { appearance in
            nsColor(for: EditorThemeScheme(appearance: appearance))
        }
    }

    func nsColor(for scheme: EditorThemeScheme) -> NSColor {
        let components = components(for: scheme)
        return NSColor(
            red: components.red,
            green: components.green,
            blue: components.blue,
            alpha: 1
        )
    }
#elseif os(iOS)
    var uiColor: UIColor {
        UIColor { traits in
            uiColor(for: traits.userInterfaceStyle == .dark ? .dark : .light)
        }
    }

    func uiColor(for scheme: EditorThemeScheme) -> UIColor {
        let components = components(for: scheme)
        return UIColor(
            red: components.red,
            green: components.green,
            blue: components.blue,
            alpha: 1
        )
    }
#endif

    func components(for scheme: EditorThemeScheme) -> EditorColorComponents {
        switch scheme {
        case .light:
            return lightComponents
        case .dark:
            return darkComponents
        }
    }

    static func hex(_ red: Int, _ green: Int, _ blue: Int) -> EditorColorToken {
        EditorColorToken(
            lightComponents: .hex(red, green, blue),
            darkComponents: .hex(red, green, blue)
        )
    }

    static func hex(
        light: (Int, Int, Int),
        dark: (Int, Int, Int)
    ) -> EditorColorToken {
        EditorColorToken(
            lightComponents: .hex(light.0, light.1, light.2),
            darkComponents: .hex(dark.0, dark.1, dark.2)
        )
    }
}

#if os(macOS)
extension EditorThemeScheme {
    init(appearance: NSAppearance) {
        let match = appearance.bestMatch(from: [.darkAqua, .aqua])
        self = match == .darkAqua ? .dark : .light
    }
}
#endif

struct EditorShadowToken: Equatable, Sendable {
    let color: EditorColorToken
    let opacity: Double
    let radius: Double
    let x: Double
    let y: Double

    var swiftUIColor: Color {
        color.color.opacity(opacity)
    }
}

enum EditorDesignTokens {
    enum Colors {
        static let appBackground = EditorColorToken.hex(
            light: (0xF7, 0xF7, 0xF5),
            dark: (0x15, 0x15, 0x14)
        )
        static let sidebarBackground = EditorColorToken.hex(
            light: (0xF2, 0xF2, 0xEF),
            dark: (0x1D, 0x1B, 0x19)
        )
        static let documentListBackground = EditorColorToken.hex(
            light: (0xF8, 0xF8, 0xF6),
            dark: (0x18, 0x18, 0x17)
        )
        static let editorBackground = EditorColorToken.hex(
            light: (0xFF, 0xFF, 0xFF),
            dark: (0x10, 0x11, 0x11)
        )
        static let primaryText = EditorColorToken.hex(
            light: (0x22, 0x21, 0x1F),
            dark: (0xEF, 0xED, 0xEA)
        )
        static let secondaryText = EditorColorToken.hex(
            light: (0x5F, 0x61, 0x66),
            dark: (0xB8, 0xB2, 0xAA)
        )
        static let tertiaryText = EditorColorToken.hex(
            light: (0x8B, 0x8D, 0x91),
            dark: (0x81, 0x7C, 0x73)
        )
        static let border = EditorColorToken.hex(
            light: (0xE6, 0xE5, 0xE1),
            dark: (0x37, 0x32, 0x2C)
        )
        static let accent = EditorColorToken.hex(
            light: (0xE5, 0x45, 0x4F),
            dark: (0xFF, 0x63, 0x6E)
        )
        static let shadow = EditorColorToken.hex(
            light: (0x1E, 0x19, 0x12),
            dark: (0x00, 0x00, 0x00)
        )
        static let elevatedSurface = EditorColorToken.hex(
            light: (0xFF, 0xFF, 0xFF),
            dark: (0x20, 0x1F, 0x1D)
        )
        static let controlBackground = EditorColorToken.hex(
            light: (0xF3, 0xF3, 0xF0),
            dark: (0x26, 0x24, 0x21)
        )
        static let controlBackgroundSubtle = EditorColorToken.hex(
            light: (0xFA, 0xFA, 0xF8),
            dark: (0x1B, 0x1B, 0x1A)
        )
        static let codeBlockBackground = EditorColorToken.hex(
            light: (0xF6, 0xF7, 0xF8),
            dark: (0x1A, 0x1C, 0x1E)
        )
        static let calloutBackground = EditorColorToken.hex(
            light: (0xF6, 0xF7, 0xF8),
            dark: (0x1B, 0x20, 0x26)
        )
        static let quoteBackground = EditorColorToken.hex(
            light: (0xE6, 0xE5, 0xE1),
            dark: (0x23, 0x20, 0x1B)
        )
        static let attachmentBackground = EditorColorToken.hex(
            light: (0xF6, 0xF7, 0xF8),
            dark: (0x1B, 0x1D, 0x1F)
        )
        static let tableHeaderBackground = EditorColorToken.hex(
            light: (0xE6, 0xE5, 0xE1),
            dark: (0x21, 0x20, 0x1E)
        )
        static let drawingCanvasBackground = EditorColorToken.hex(
            light: (0xFB, 0xFC, 0xFD),
            dark: (0x18, 0x19, 0x1A)
        )
        static let inlineCodeBackground = EditorColorToken.hex(
            light: (0xF4, 0xF3, 0xF1),
            dark: (0x27, 0x25, 0x22)
        )
        static let searchHighlightFill = EditorColorToken.hex(
            light: (0xFF, 0xD6, 0x42),
            dark: (0xF4, 0xBC, 0x44)
        )
        static let searchHighlightStroke = EditorColorToken.hex(
            light: (0xDB, 0x8A, 0x0A),
            dark: (0xFF, 0xD1, 0x63)
        )
        static let warningText = EditorColorToken.hex(
            light: (0xA8, 0x5B, 0x00),
            dark: (0xFF, 0xB8, 0x4D)
        )
        static let warningFill = EditorColorToken.hex(
            light: (0xFF, 0xF8, 0xEA),
            dark: (0x33, 0x25, 0x13)
        )
        static let warningStroke = EditorColorToken.hex(
            light: (0xF0, 0xC2, 0x70),
            dark: (0x7A, 0x58, 0x22)
        )
        static let successText = EditorColorToken.hex(
            light: (0x1F, 0x7A, 0x3B),
            dark: (0x7F, 0xDA, 0x8A)
        )
        static let successFill = EditorColorToken.hex(
            light: (0xEA, 0xF7, 0xEE),
            dark: (0x14, 0x28, 0x1A)
        )
        static let danger = EditorColorToken.hex(
            light: (0xC7, 0x1F, 0x29),
            dark: (0xFF, 0x7A, 0x83)
        )
        static let dangerFill = EditorColorToken.hex(
            light: (0xFE, 0xEC, 0xEE),
            dark: (0x32, 0x18, 0x1C)
        )
    }

    enum Typography {
        static let documentTitleSize: Double = 28
        static let bodySize: Double = 14
        static let bodyLineHeightMultiple: Double = 1.34
    }

    enum Layout {
        static let editorMaxWidth: Double = 560
        static let editorExpandedMaxWidth: Double = 560
        static let sidebarMinWidth: Double = 240
        static let sidebarIdealWidth: Double = 288
        static let sidebarMaxWidth: Double = 360
        static let documentListMinWidth: Double = 300
        static let documentListIdealWidth: Double = 360
        static let documentListMaxWidth: Double = 460
        static let documentListRowMinHeight: Double = 72
        static let documentListSelectedAccentWidth: Double = 3
        static let rowCornerRadius: Double = 8
        static let specialBlockCornerRadius: Double = 12
        static let pageLinkCornerRadius: Double = 13
        static let slashMenuWidth: Double = 380
        static let slashMenuRowHeight: Double = 48
        static let slashMenuCornerRadius: Double = 14
        static let auxiliaryRailWidth: Double = 285
        static let popoverCornerRadius: Double = 16
    }

    enum Shadows {
        static let popoverLarge = EditorShadowToken(
            color: Colors.shadow,
            opacity: 0.10,
            radius: 48,
            x: 0,
            y: 16
        )
        static let popoverSmall = EditorShadowToken(
            color: Colors.shadow,
            opacity: 0.06,
            radius: 8,
            x: 0,
            y: 2
        )
    }
}

enum EditorCanvasChromeLayout {
    static let compactHorizontalPadding: Double = 14

    static var horizontalPadding: Double {
#if os(iOS)
        compactHorizontalPadding
#else
        34
#endif
    }

    static var verticalPadding: Double {
#if os(iOS)
        18
#else
        36
#endif
    }

    static var pageTitleLeadingPadding: Double {
#if os(iOS) || os(macOS)
        EditorBlockChrome.actionColumnWidth + EditorBlockChrome.actionColumnSpacing + 4
#else
        0
#endif
    }

    static var blockRowTitleAlignmentCompensation: Double {
        0
    }
}

enum MobileNavigationTitleVisibilityResolver {
    static func isNavigationTitleVisible(titleFrame: CGRect, topMaskHeight: CGFloat) -> Bool {
        guard !titleFrame.isEmpty else {
            return false
        }
        return titleFrame.maxY <= topMaskHeight
    }
}

enum MobileNavigationTitleScrollVisibilityResolver {
    static let fallbackScrollOffsetThreshold: CGFloat = 24

    static func isNavigationTitleVisible(
        baselineMaxY: CGFloat?,
        scrollOffsetY: CGFloat,
        topMaskHeight: CGFloat
    ) -> Bool {
        let scrollOffsetY = max(0, scrollOffsetY)
        guard scrollOffsetY >= fallbackScrollOffsetThreshold else {
            return false
        }
        guard let baselineMaxY else {
            return true
        }
        let currentTitleFrame = CGRect(
            x: 0,
            y: baselineMaxY - scrollOffsetY - 1,
            width: 1,
            height: 1
        )
        return MobileNavigationTitleVisibilityResolver.isNavigationTitleVisible(
            titleFrame: currentTitleFrame,
            topMaskHeight: topMaskHeight
        )
    }
}

struct MobileNavigationTitleVisibilityState: Equatable, Sendable {
    private(set) var isVisible = false
    private(set) var baselineMaxY: CGFloat?
    private(set) var scrollOffsetY: CGFloat = 0
    private(set) var initialScrollOffsetY: CGFloat?

    func updated(
        titleFrame: CGRect? = nil,
        scrollOffsetY nextScrollOffsetY: CGFloat? = nil,
        topMaskHeight: CGFloat
    ) -> Self {
        var next = self
        if let nextScrollOffsetY {
            let normalizedOffsetY = max(0, nextScrollOffsetY)
            if next.initialScrollOffsetY == nil {
                next.initialScrollOffsetY = normalizedOffsetY
            }
            next.scrollOffsetY = max(0, normalizedOffsetY - (next.initialScrollOffsetY ?? 0))
        }

        if let titleFrame, !titleFrame.isEmpty {
            let reportedBaselineMaxY = titleFrame.maxY + next.scrollOffsetY
            if next.baselineMaxY == nil || next.scrollOffsetY == 0 {
                next.baselineMaxY = reportedBaselineMaxY
            }
        }

        next.isVisible = MobileNavigationTitleScrollVisibilityResolver
            .isNavigationTitleVisible(
                baselineMaxY: next.baselineMaxY,
                scrollOffsetY: next.scrollOffsetY,
                topMaskHeight: topMaskHeight
            )
        return next
    }
}

enum EditorCanvasWidthPolicy {
    static func maxWidth(hasVisibleAuxiliaryRail: Bool) -> Double {
        EditorDesignTokens.Layout.editorExpandedMaxWidth
    }

    static func editorColumnWidth(
        containerWidth: CGFloat,
        horizontalPadding: CGFloat,
        editorMaxWidth: CGFloat
    ) -> CGFloat {
        max(0, min(editorMaxWidth, containerWidth - horizontalPadding * 2))
    }

    static func centeredContentFrameWidth(
        containerWidth: CGFloat,
        horizontalPadding: CGFloat,
        editorMaxWidth: CGFloat
    ) -> CGFloat {
        editorColumnWidth(
            containerWidth: containerWidth,
            horizontalPadding: horizontalPadding,
            editorMaxWidth: editorMaxWidth
        ) + horizontalPadding * 2
    }

    static func centeredSideInset(
        containerWidth: CGFloat,
        contentFrameWidth: CGFloat
    ) -> CGFloat {
        max(0, (containerWidth - contentFrameWidth) / 2)
    }
}

#if os(macOS)
enum DesktopInlineOutlineUserPreference: String, Equatable, Sendable {
    static let appStorageKey = "editor.desktopInlineOutline.userPreference"

    case automatic
    case expanded
    case collapsed
}

enum DesktopInlineOutlinePresentation: Equatable, Sendable {
    case hidden
    case expanded
    case collapsed
}

enum DesktopInlineOutlineToggleAction: Equatable, Sendable {
    case persist(DesktopInlineOutlineUserPreference)
    case togglePopover
}

enum DesktopInlineOutlinePlacementPolicy {
    static let expandedWidth: CGFloat = 244
    static let collapsedWidth: CGFloat = 34
    static let contentSpacing: CGFloat = 24
    static let minimumWindowEdgeInset: CGFloat = 12
    static let minimumReadableLeftGap: CGFloat = 280
    static let preferredTopOffset: CGFloat = 86

    static func leadingGap(
        containerWidth: CGFloat,
        horizontalPadding: CGFloat,
        editorMaxWidth: CGFloat
    ) -> CGFloat {
        let frameWidth = EditorCanvasWidthPolicy.centeredContentFrameWidth(
            containerWidth: containerWidth,
            horizontalPadding: horizontalPadding,
            editorMaxWidth: editorMaxWidth
        )
        return EditorCanvasWidthPolicy.centeredSideInset(
            containerWidth: containerWidth,
            contentFrameWidth: frameWidth
        )
    }

    static func presentation(
        outlineItemCount: Int,
        leadingGap: CGFloat,
        userPreference: DesktopInlineOutlineUserPreference
    ) -> DesktopInlineOutlinePresentation {
        guard outlineItemCount > 0 else {
            return .hidden
        }

        guard canExpand(leadingGap: leadingGap) else {
            return .collapsed
        }

        switch userPreference {
        case .automatic, .expanded:
            return .expanded
        case .collapsed:
            return .collapsed
        }
    }

    static func canExpand(leadingGap: CGFloat) -> Bool {
        leadingGap >= expandedWidth + contentSpacing + minimumWindowEdgeInset
            && leadingGap >= minimumReadableLeftGap
    }

    static func xOffset(
        leadingGap: CGFloat,
        presentation: DesktopInlineOutlinePresentation
    ) -> CGFloat {
        switch presentation {
        case .hidden:
            return minimumWindowEdgeInset
        case .expanded:
            return max(minimumWindowEdgeInset, leadingGap - expandedWidth - contentSpacing)
        case .collapsed:
            return max(minimumWindowEdgeInset, leadingGap - collapsedWidth - contentSpacing)
        }
    }

    static func popoverXOffset(leadingGap: CGFloat) -> CGFloat {
        max(minimumWindowEdgeInset, leadingGap - expandedWidth - contentSpacing)
    }

    static func topOffset(containerHeight: CGFloat) -> CGFloat {
        min(preferredTopOffset, max(64, containerHeight * 0.09))
    }
}

enum DesktopInlineOutlineTogglePolicy {
    static func triggerAction(leadingGap: CGFloat) -> DesktopInlineOutlineToggleAction {
        if DesktopInlineOutlinePlacementPolicy.canExpand(leadingGap: leadingGap) {
            return .persist(.expanded)
        }
        return .togglePopover
    }
}
#endif

enum DesktopInlineOutlineActiveHeadingResolver {
    static let activationY: CGFloat = 160

    static func activeBlockID(
        outlineItems: [PageOutlineItem],
        visibleBlockFrames: [String: CGRect],
        blockIDsInDocumentOrder: [String],
        selectedBlockID: String? = nil,
        focusedBlockID: String?,
        activationY: CGFloat = Self.activationY
    ) -> String? {
        guard !outlineItems.isEmpty else {
            return nil
        }

        let outlineBlockIDs = Set(outlineItems.map(\.blockID))
        if let selectedBlockID, outlineBlockIDs.contains(selectedBlockID) {
            return selectedBlockID
        }

        let visibleHeadingsAboveActivationLine = visibleBlockFrames
            .filter { outlineBlockIDs.contains($0.key) && $0.value.minY <= activationY }
            .sorted { $0.value.minY < $1.value.minY }

        if let activeVisibleHeading = visibleHeadingsAboveActivationLine.last?.key {
            return activeVisibleHeading
        }

        let documentIndexesByID = Dictionary(
            uniqueKeysWithValues: blockIDsInDocumentOrder.enumerated().map { ($0.element, $0.offset) }
        )
        let firstVisibleBlockIndex = visibleBlockFrames
            .compactMap { documentIndexesByID[$0.key] }
            .min()

        if let firstVisibleBlockIndex,
           let precedingHeading = outlineItems.last(where: { item in
               guard let headingIndex = documentIndexesByID[item.blockID] else {
                   return false
               }
               return headingIndex <= firstVisibleBlockIndex
           }) {
            return precedingHeading.blockID
        }

        if let focusedBlockID, outlineBlockIDs.contains(focusedBlockID) {
            return focusedBlockID
        }

        return outlineItems.first?.blockID
    }
}

enum EditorDisplayMode: Equatable, Sendable {
    case standard
    case writing
    case focus

    var showsSidebar: Bool {
        self != .focus
    }

    var showsDocumentList: Bool {
        self == .standard
    }

    var showsAuxiliaryRail: Bool {
        false
    }

    var splitVisibility: NavigationSplitViewVisibility {
        switch self {
        case .standard:
            return .all
        case .writing:
            return .all
        case .focus:
            return .detailOnly
        }
    }
}

struct EditorInsertMarkdownLinkActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct EditorPromoteDiarySelectionActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct EditorOpenParentPageActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct EditorCreateNewDocumentActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct EditorOpenTodayActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct EditorNavigateBackActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct EditorNavigateForwardActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct EditorShowAllDocumentsActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct EditorShowFavoritesActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct EditorToggleFocusModeActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct EditorQuickOpenActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var insertMarkdownLinkAction: (() -> Void)? {
        get { self[EditorInsertMarkdownLinkActionKey.self] }
        set { self[EditorInsertMarkdownLinkActionKey.self] = newValue }
    }

    var promoteDiarySelectionAction: (() -> Void)? {
        get { self[EditorPromoteDiarySelectionActionKey.self] }
        set { self[EditorPromoteDiarySelectionActionKey.self] = newValue }
    }

    var openParentPageAction: (() -> Void)? {
        get { self[EditorOpenParentPageActionKey.self] }
        set { self[EditorOpenParentPageActionKey.self] = newValue }
    }

    var createNewDocumentAction: (() -> Void)? {
        get { self[EditorCreateNewDocumentActionKey.self] }
        set { self[EditorCreateNewDocumentActionKey.self] = newValue }
    }

    var openTodayAction: (() -> Void)? {
        get { self[EditorOpenTodayActionKey.self] }
        set { self[EditorOpenTodayActionKey.self] = newValue }
    }

    var navigateBackAction: (() -> Void)? {
        get { self[EditorNavigateBackActionKey.self] }
        set { self[EditorNavigateBackActionKey.self] = newValue }
    }

    var navigateForwardAction: (() -> Void)? {
        get { self[EditorNavigateForwardActionKey.self] }
        set { self[EditorNavigateForwardActionKey.self] = newValue }
    }

    var showAllDocumentsAction: (() -> Void)? {
        get { self[EditorShowAllDocumentsActionKey.self] }
        set { self[EditorShowAllDocumentsActionKey.self] = newValue }
    }

    var showFavoritesAction: (() -> Void)? {
        get { self[EditorShowFavoritesActionKey.self] }
        set { self[EditorShowFavoritesActionKey.self] = newValue }
    }

    var toggleFocusModeAction: (() -> Void)? {
        get { self[EditorToggleFocusModeActionKey.self] }
        set { self[EditorToggleFocusModeActionKey.self] = newValue }
    }

    var quickOpenAction: (() -> Void)? {
        get { self[EditorQuickOpenActionKey.self] }
        set { self[EditorQuickOpenActionKey.self] = newValue }
    }
}

struct ForegroundSyncActivationPolicy {
    static let foregroundPollingIntervalNanoseconds: UInt64 = 30_000_000_000

    func shouldSync(for phase: ScenePhase) -> Bool {
        phase == .active
    }
}

struct EditorShellView: View {
    @StateObject private var viewModel: WorkspaceViewModel
    @ObservedObject private var homeScreenQuickActionCenter: EditorHomeScreenQuickActionCenter
    @Environment(\.scenePhase) private var scenePhase
    @State private var foregroundSyncActivationPolicy = ForegroundSyncActivationPolicy()

    init(
        viewModel: WorkspaceViewModel,
        homeScreenQuickActionCenter: EditorHomeScreenQuickActionCenter = .shared
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.homeScreenQuickActionCenter = homeScreenQuickActionCenter
    }

    var body: some View {
        AdaptiveEditorShell(viewModel: viewModel)
#if os(macOS)
            .background(EditorDesignTokens.Colors.appBackground.color.ignoresSafeArea())
            .containerBackground(EditorDesignTokens.Colors.appBackground.color, for: .window)
#endif
            .onAppear {
                viewModel.syncAfterActivation()
                handleHomeScreenQuickActionIfNeeded(homeScreenQuickActionCenter.latestRequest)
            }
            .onChange(of: scenePhase) { _, phase in
                if foregroundSyncActivationPolicy.shouldSync(for: phase) {
                    viewModel.syncAfterActivation()
                }
            }
            .onChange(of: homeScreenQuickActionCenter.latestRequest) { _, request in
                handleHomeScreenQuickActionIfNeeded(request)
            }
            .task(id: scenePhase) {
                await runForegroundSyncPollingLoop(for: scenePhase)
            }
    }

    private func handleHomeScreenQuickActionIfNeeded(_ request: EditorHomeScreenQuickActionRequest?) {
        guard let request else {
            return
        }
        _ = viewModel.performHomeScreenQuickAction(request.action)
        homeScreenQuickActionCenter.consume(request)
    }

    private func runForegroundSyncPollingLoop(for phase: ScenePhase) async {
        guard foregroundSyncActivationPolicy.shouldSync(for: phase) else {
            return
        }

        while !Task.isCancelled {
            do {
                try await Task.sleep(
                    nanoseconds: ForegroundSyncActivationPolicy.foregroundPollingIntervalNanoseconds
                )
            } catch {
                return
            }
            guard foregroundSyncActivationPolicy.shouldSync(for: phase) else {
                return
            }
            viewModel.lockExpiredEncryptedPagesForUI()
            viewModel.syncAfterForegroundInterval()
        }
    }
}

private struct AdaptiveEditorShell: View {
    @ObservedObject var viewModel: WorkspaceViewModel

#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif

    var body: some View {
#if os(iOS)
        if horizontalSizeClass == .compact {
            CompactEditorShell(viewModel: viewModel)
        } else {
            ThreeColumnEditorShell(viewModel: viewModel)
        }
#else
        ThreeColumnEditorShell(viewModel: viewModel)
#endif
    }
}

private struct ThreeColumnEditorShell: View {
    @ObservedObject var viewModel: WorkspaceViewModel
    @State private var displayMode: EditorDisplayMode = .standard
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var activePageDragIDs: Set<String> = []
#if os(macOS)
    @State private var desktopSidebarWidth = CGFloat(EditorDesignTokens.Layout.sidebarIdealWidth)
    @State private var desktopDocumentListWidth = CGFloat(EditorDesignTokens.Layout.documentListIdealWidth)
#endif

    var body: some View {
        Group {
#if os(macOS)
            desktopLayout
#else
        NavigationSplitView(columnVisibility: $columnVisibility) {
            if displayMode.showsSidebar {
                WorkspaceSidebar(viewModel: viewModel, activePageDragIDs: $activePageDragIDs)
            } else {
                Color.clear
                    .frame(width: 0)
                    .navigationSplitViewColumnWidth(min: 0, ideal: 0, max: 0)
            }
        } content: {
            if displayMode.showsDocumentList {
                PageListView(viewModel: viewModel, activePageDragIDs: $activePageDragIDs)
            } else {
                Color.clear
                    .frame(width: 0)
                    .navigationSplitViewColumnWidth(min: 0, ideal: 0, max: 0)
            }
        } detail: {
            if viewModel.selectedPage != nil {
                EditorCanvasView(
                    page: viewModel.selectedPage,
                    pages: viewModel.snapshot.pages,
                    blocks: viewModel.editorVisibleBlocks,
                    allBlocks: viewModel.snapshot.blocks,
                    attachments: viewModel.snapshot.attachments,
                    attachmentPreviewGenerationStatuses: viewModel.attachmentPreviewGenerationStatuses,
                    markdownImportStatusText: viewModel.markdownImportStatusText,
                    backlinks: viewModel.selectedPageBacklinks,
                    externalLinks: viewModel.selectedPageExternalLinks,
                    conflicts: viewModel.selectedPageConflicts,
                    outlineItems: viewModel.selectedPageOutline,
                    parentPageLink: viewModel.selectedPageParentLink,
                    pageTagNames: viewModel.selectedPageTagNames,
                    availableTags: viewModel.snapshot.tags,
                    selectedPageTagIDs: viewModel.selectedPageTagIDs,
                    pendingFocusBlockID: viewModel.pendingFocusBlockID,
                    pendingSearchHighlight: viewModel.pendingSearchHighlight,
                    pendingFocusRequestID: viewModel.pendingFocusRequestID,
                    pendingPageTitleFocusPageID: viewModel.pendingPageTitleFocusPageID,
                    canUndoTextEdit: viewModel.canUndoTextEdit,
                    canRedoTextEdit: viewModel.canRedoTextEdit,
                    displayMode: displayMode,
                    isEncryptedContentLocked: viewModel.selectedPage.map { viewModel.isEncryptedPageLocked($0.id) } ?? false,
                    isAuthenticatingEncryptedContent: viewModel.selectedPageID.map { viewModel.authenticatingEncryptedPageID == $0 } ?? false,
                    onDisplayModeChange: { mode in
                        displayMode = mode
                    },
                    onUnlockEncryptedContent: {
                        Task {
                            await viewModel.unlockSelectedEncryptedPageForUI()
                        }
                    },
                    onAddParagraphBlock: {
                        viewModel.addParagraphBlockToCurrentPage()
                    },
                    onAddPageReference: { targetPageID in
                        viewModel.appendPageReferenceToCurrentPageForUI(targetPageID: targetPageID)
                    },
                    onAddBlockReference: { targetBlockID in
                        viewModel.appendBlockReferenceToCurrentPageForUI(targetBlockID: targetBlockID)
                    },
                    onInsertMarkdownLink: { blockID, label, url in
                        viewModel.insertMarkdownLinkForUI(blockID: blockID, label: label, url: url)
                    },
                    onInsertMarkdownLinkAtSelection: { blockID, label, url, selection in
                        viewModel.insertMarkdownLinkForUI(
                            blockID: blockID,
                            label: label,
                            url: url,
                            selection: selection
                        )
                    },
                    onRemoveMarkdownLinkAtSelection: { blockID, selection in
                        viewModel.removeMarkdownLinkForUI(blockID: blockID, selection: selection)
                    },
                    onApplyMarkdownInlineFormat: { blockID, format, selection in
                        viewModel.applyMarkdownInlineFormatForUI(
                            blockID: blockID,
                            format: format,
                            selection: selection
                        )
                    },
                    onUndoTextEdit: {
                        viewModel.undoLastTextEditForUI()
                    },
                    onRedoTextEdit: {
                        viewModel.redoLastTextEditForUI()
                    },
                    onFocusCanvas: {
                        viewModel.focusEditorCanvasForUI()
                    },
                    onMoveBlock: { blockID, targetIndex in
                        viewModel.moveBlockInCurrentPage(blockID: blockID, toIndex: targetIndex)
                    },
                    onMoveBlocks: { blockIDs, targetIndex in
                        viewModel.moveBlocksInCurrentPage(blockIDs: blockIDs, toIndex: targetIndex)
                    },
                    onUpdateBlockParent: { blockID, parentBlockID in
                        viewModel.updateBlockParentForUI(blockID: blockID, parentBlockID: parentBlockID)
                    },
                    onMoveBlockByKeyboard: { blockID, direction in
                        viewModel.moveBlockByKeyboardForUI(blockID: blockID, direction: direction)
                    },
                    onInsertBlockAfter: { blockID in
                        viewModel.insertParagraphBlockAfterForUI(blockID: blockID)
                    },
                    onSplitTextBlockAtSelection: { blockID, selection in
                        viewModel.splitTextBlockAtSelectionForUI(blockID: blockID, selection: selection)
                    },
                    onReplaceTextAtSelection: { selection, replacementText in
                        viewModel.replaceTextAtSelectionForUI(selection: selection, replacementText: replacementText)
                    },
                    onPasteTextAtSelection: { selection, pasteText in
                        viewModel.pasteTextAtSelectionForUI(selection: selection, pasteText: pasteText)
                    },
                    onMergeTextBlockWithPrevious: { blockID, selection in
                        viewModel.mergeTextBlockWithPreviousAtSelectionForUI(blockID: blockID, selection: selection)
                    },
                    onMergeTextBlockWithNext: { blockID, selection in
                        viewModel.mergeTextBlockWithNextAtSelectionForUI(blockID: blockID, selection: selection)
                    },
                    onIndentBlock: { blockID in
                        viewModel.indentBlockForUI(blockID: blockID)
                    },
                    onOutdentBlock: { blockID in
                        viewModel.outdentBlockForUI(blockID: blockID)
                    },
                    onDeleteBlock: { blockID in
                        viewModel.deleteBlockFromCurrentPage(blockID: blockID)
                    },
                    onDeleteBlocks: { blockIDs in
                        viewModel.deleteBlocksFromCurrentPage(blockIDs: blockIDs)
                    },
                    onSelectBacklink: { backlink in
                        viewModel.selectBacklink(backlink)
                    },
                    onSelectOutlineItem: { item in
                        viewModel.selectOutlineItem(item)
                    },
                    onOpenPageReference: { targetPageID in
                        viewModel.openPageReference(targetPageID: targetPageID)
                    },
                    onOpenParentPage: {
                        viewModel.openParentPageForCurrentPageForUI()
                    },
                    onOpenBlockReference: { targetPageID, targetBlockID in
                        viewModel.openBlockReference(targetPageID: targetPageID, targetBlockID: targetBlockID)
                    },
                    onAcceptConflict: { conflict in
                        viewModel.acceptRemoteConflictForUI(id: conflict.id)
                    },
                    onAcceptAllConflicts: {
                        viewModel.acceptAllRemoteConflictsForSelectedPageForUI()
                    },
                    onAcceptLocalConflict: { conflict in
                        viewModel.acceptLocalConflictForUI(id: conflict.id)
                    },
                    onAcceptAllLocalConflicts: {
                        viewModel.acceptAllLocalConflictsForSelectedPageForUI()
                    },
                    onResolveConflictManually: { conflict, text in
                        viewModel.resolveConflictManuallyForUI(id: conflict.id, text: text)
                    },
                    onResolveAllConflictsManually: { mergedTextsByConflictID in
                        viewModel.resolveAllManualConflictsForSelectedPageForUI(
                            mergedTextsByConflictID: mergedTextsByConflictID
                        )
                    },
                    onPageTitleChange: { title in
                        viewModel.editSelectedPageTitle(title)
                    },
                    onImportMarkdown: { sourceURL in
                        viewModel.importMarkdownFileForCurrentPage(sourceURL: sourceURL)
                    },
                    onImportObsidianVault: { sourceURL in
                        viewModel.importObsidianVaultForCurrentWorkspace(sourceURL: sourceURL)
                    },
                    onExportMarkdown: {
                        viewModel.exportCurrentPageMarkdown()
                    },
                    onExportMarkdownPackage: { destinationURL in
                        viewModel.exportCurrentPageMarkdownPackageForUI(to: destinationURL)
                    },
                    onBlockTextChange: { blockID, text in
                        viewModel.editBlockText(blockID: blockID, text: text)
                    },
                    onTableRowsChange: { blockID, rows in
                        viewModel.updateTableRowsForUI(blockID: blockID, rows: rows)
                    },
                    onBlockTypeChange: { blockID, type in
                        viewModel.changeBlockTypeForUI(blockID: blockID, type: type)
                    },
                    onConvertBlockToPage: { blockID in
                        viewModel.convertTextBlockToPageForUI(blockID: blockID)
                    },
                    onTaskItemCompletionChange: { blockID, isCompleted in
                        viewModel.updateTaskItemCompletionForUI(
                            blockID: blockID,
                            isCompleted: isCompleted
                        )
                    },
                    onCodeBlockLineWrappingChange: { blockID, isWrapped in
                        viewModel.updateCodeBlockLineWrapping(blockID: blockID, isWrapped: isWrapped)
                    },
                    onToggleBlockExpansion: { blockID in
                        viewModel.toggleBlockExpansion(blockID: blockID)
                    },
                    isToggleBlockExpanded: { blockID in
                        viewModel.isToggleBlockExpanded(blockID: blockID)
                    },
                    onImportAttachment: { sourceURL in
                        viewModel.importAttachmentForCurrentPage(sourceURL: sourceURL)
                    },
                    onImportAttachmentsAfterBlock: { sourceURLs, blockID in
                        viewModel.importAttachmentsForCurrentPage(
                            sourceURLs: sourceURLs,
                            afterBlockID: blockID
                        )
                    },
                    onRetryAttachmentPreview: { attachmentID in
                        viewModel.retryAttachmentPreviewGeneration(attachmentID: attachmentID)
                    },
                    onRenameAttachmentImage: { blockID, name in
                        viewModel.renameAttachmentImageForUI(blockID: blockID, name: name)
                    },
                    onAttachmentImageDisplayWidthChange: { blockID, displayWidth in
                        viewModel.updateAttachmentImageDisplayWidthForUI(
                            blockID: blockID,
                            displayWidth: displayWidth
                        )
                    },
                    onDrawingBlockDataChange: { blockID, data in
                        viewModel.updateDrawingBlockForUI(blockID: blockID, data: data)
                    },
                    onMobileRevealPageList: nil,
                    onPendingBlockFocusHandled: {
                        _ = viewModel.consumePendingFocusBlockID()
                    },
                    onPendingPageTitleFocusHandled: {
                        _ = viewModel.consumePendingPageTitleFocusPageID()
                    },
                    onRemoveTagFromSelectedPage: { tagID in
                        viewModel.removeTagFromSelectedPageForUI(tagID: tagID)
                    },
                    onCreateAndAssignTagToSelectedPage: { name in
                        viewModel.createAndAssignTagToSelectedPageForUI(name: name)
                    }
                )
            } else {
                EditorDesignTokens.Colors.editorBackground.color
                    .navigationTitle("编辑器")
            }
        }
#endif
        }
        .onAppear {
            columnVisibility = displayMode.splitVisibility
        }
        .onChange(of: displayMode) { _, mode in
            columnVisibility = mode.splitVisibility
        }
        .focusedValue(\.createNewDocumentAction, {
            _ = viewModel.createNewDocumentForUI()
        })
        .focusedValue(\.openTodayAction, {
            _ = viewModel.openTodayForUI()
        })
        .focusedValue(\.navigateBackAction, {
            _ = viewModel.navigateBackForUI()
        })
        .focusedValue(\.navigateForwardAction, {
            _ = viewModel.navigateForwardForUI()
        })
        .focusedValue(\.showAllDocumentsAction, {
            viewModel.selectCollection(.allDocuments)
        })
        .focusedValue(\.showFavoritesAction, {
            viewModel.selectCollection(.favorites)
        })
        .focusedValue(\.toggleFocusModeAction, {
            toggleFocusMode()
        })
        .focusedValue(\.quickOpenAction, {
            _ = viewModel.openQuickSearchForUI()
        })
#if os(macOS)
        .background(
            EditorGlobalShortcutBridge { command in
                handleGlobalShortcut(command)
            }
            .frame(width: 0, height: 0)
        )
#endif
    }

    private func toggleFocusMode() {
        displayMode = displayMode == .focus ? .standard : .focus
    }

#if os(macOS)
    private func handleGlobalShortcut(_ command: EditorShortcutCommand) -> Bool {
        switch command {
        case .newDocument:
            return viewModel.createNewDocumentForUI()
        case .openToday:
            return viewModel.openTodayForUI()
        case .navigateBack:
            return viewModel.navigateBackForUI()
        case .navigateForward:
            return viewModel.navigateForwardForUI()
        case .quickOpen:
            viewModel.selectCollection(.search)
            return true
        case .showAllDocuments:
            viewModel.selectCollection(.allDocuments)
            return true
        case .showFavorites:
            viewModel.selectCollection(.favorites)
            return true
        case .toggleFocusMode:
            toggleFocusMode()
            return true
        case .insertMarkdownLink, .convertBlockToPage:
            return false
        }
    }

    private var desktopLayout: some View {
        HStack(alignment: .top, spacing: 0) {
            if displayMode.showsSidebar {
                WorkspaceSidebar(viewModel: viewModel, activePageDragIDs: $activePageDragIDs)
                    .frame(width: desktopSidebarWidth)
                    .overlay(alignment: .trailing) {
                        DesktopColumnDivider(
                            width: desktopSidebarWidth,
                            minWidth: EditorDesignTokens.Layout.sidebarMinWidth,
                            maxWidth: EditorDesignTokens.Layout.sidebarMaxWidth
                        ) { width in
                            desktopSidebarWidth = width
                        }
                    }
            }

            if displayMode.showsDocumentList {
                PageListView(viewModel: viewModel, activePageDragIDs: $activePageDragIDs)
                    .frame(width: desktopDocumentListWidth)
                    .overlay(alignment: .trailing) {
                        DesktopColumnDivider(
                            width: desktopDocumentListWidth,
                            minWidth: EditorDesignTokens.Layout.documentListMinWidth,
                            maxWidth: EditorDesignTokens.Layout.documentListMaxWidth
                        ) { width in
                            desktopDocumentListWidth = width
                        }
                    }
            }

            editorDetailColumn
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(EditorDesignTokens.Colors.editorBackground.color.ignoresSafeArea(edges: .top))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(EditorDesignTokens.Colors.appBackground.color)
        .ignoresSafeArea(edges: .top)
    }

#endif

    @ViewBuilder
    private var editorDetailColumn: some View {
        if viewModel.selectedPage != nil {
            EditorCanvasView(
                page: viewModel.selectedPage,
                pages: viewModel.snapshot.pages,
                blocks: viewModel.editorVisibleBlocks,
                allBlocks: viewModel.snapshot.blocks,
                attachments: viewModel.snapshot.attachments,
                attachmentPreviewGenerationStatuses: viewModel.attachmentPreviewGenerationStatuses,
                markdownImportStatusText: viewModel.markdownImportStatusText,
                backlinks: viewModel.selectedPageBacklinks,
                externalLinks: viewModel.selectedPageExternalLinks,
                conflicts: viewModel.selectedPageConflicts,
                outlineItems: viewModel.selectedPageOutline,
                parentPageLink: viewModel.selectedPageParentLink,
                pageTagNames: viewModel.selectedPageTagNames,
                availableTags: viewModel.snapshot.tags,
                selectedPageTagIDs: viewModel.selectedPageTagIDs,
                pendingFocusBlockID: viewModel.pendingFocusBlockID,
                pendingSearchHighlight: viewModel.pendingSearchHighlight,
                pendingFocusRequestID: viewModel.pendingFocusRequestID,
                pendingPageTitleFocusPageID: viewModel.pendingPageTitleFocusPageID,
                canUndoTextEdit: viewModel.canUndoTextEdit,
                canRedoTextEdit: viewModel.canRedoTextEdit,
                displayMode: displayMode,
                isEncryptedContentLocked: viewModel.selectedPage.map { viewModel.isEncryptedPageLocked($0.id) } ?? false,
                isAuthenticatingEncryptedContent: viewModel.selectedPageID.map { viewModel.authenticatingEncryptedPageID == $0 } ?? false,
                onDisplayModeChange: { mode in
                    displayMode = mode
                },
                onUnlockEncryptedContent: {
                    Task {
                        await viewModel.unlockSelectedEncryptedPageForUI()
                    }
                },
                onAddParagraphBlock: {
                    viewModel.addParagraphBlockToCurrentPage()
                },
                onAddPageReference: { targetPageID in
                    viewModel.appendPageReferenceToCurrentPageForUI(targetPageID: targetPageID)
                },
                onAddBlockReference: { targetBlockID in
                    viewModel.appendBlockReferenceToCurrentPageForUI(targetBlockID: targetBlockID)
                },
                onInsertMarkdownLink: { blockID, label, url in
                    viewModel.insertMarkdownLinkForUI(blockID: blockID, label: label, url: url)
                },
                onInsertMarkdownLinkAtSelection: { blockID, label, url, selection in
                    viewModel.insertMarkdownLinkForUI(
                        blockID: blockID,
                        label: label,
                        url: url,
                        selection: selection
                    )
                },
                onRemoveMarkdownLinkAtSelection: { blockID, selection in
                    viewModel.removeMarkdownLinkForUI(blockID: blockID, selection: selection)
                },
                onApplyMarkdownInlineFormat: { blockID, format, selection in
                    viewModel.applyMarkdownInlineFormatForUI(
                        blockID: blockID,
                        format: format,
                        selection: selection
                    )
                },
                onUndoTextEdit: {
                    viewModel.undoLastTextEditForUI()
                },
                onRedoTextEdit: {
                    viewModel.redoLastTextEditForUI()
                },
                onFocusCanvas: {
                    viewModel.focusEditorCanvasForUI()
                },
                onMoveBlock: { blockID, targetIndex in
                    viewModel.moveBlockInCurrentPage(blockID: blockID, toIndex: targetIndex)
                },
                onMoveBlocks: { blockIDs, targetIndex in
                    viewModel.moveBlocksInCurrentPage(blockIDs: blockIDs, toIndex: targetIndex)
                },
                onUpdateBlockParent: { blockID, parentBlockID in
                    viewModel.updateBlockParentForUI(blockID: blockID, parentBlockID: parentBlockID)
                },
                onMoveBlockByKeyboard: { blockID, direction in
                    viewModel.moveBlockByKeyboardForUI(blockID: blockID, direction: direction)
                },
                onInsertBlockAfter: { blockID in
                    viewModel.insertParagraphBlockAfterForUI(blockID: blockID)
                },
                onSplitTextBlockAtSelection: { blockID, selection in
                    viewModel.splitTextBlockAtSelectionForUI(blockID: blockID, selection: selection)
                },
                onReplaceTextAtSelection: { selection, replacementText in
                    viewModel.replaceTextAtSelectionForUI(selection: selection, replacementText: replacementText)
                },
                onPasteTextAtSelection: { selection, pasteText in
                    viewModel.pasteTextAtSelectionForUI(selection: selection, pasteText: pasteText)
                },
                onMergeTextBlockWithPrevious: { blockID, selection in
                    viewModel.mergeTextBlockWithPreviousAtSelectionForUI(blockID: blockID, selection: selection)
                },
                onMergeTextBlockWithNext: { blockID, selection in
                    viewModel.mergeTextBlockWithNextAtSelectionForUI(blockID: blockID, selection: selection)
                },
                onIndentBlock: { blockID in
                    viewModel.indentBlockForUI(blockID: blockID)
                },
                onOutdentBlock: { blockID in
                    viewModel.outdentBlockForUI(blockID: blockID)
                },
                onDeleteBlock: { blockID in
                    viewModel.deleteBlockFromCurrentPage(blockID: blockID)
                },
                onDeleteBlocks: { blockIDs in
                    viewModel.deleteBlocksFromCurrentPage(blockIDs: blockIDs)
                },
                onSelectBacklink: { backlink in
                    viewModel.selectBacklink(backlink)
                },
                onSelectOutlineItem: { item in
                    viewModel.selectOutlineItem(item)
                },
                onOpenPageReference: { targetPageID in
                    viewModel.openPageReference(targetPageID: targetPageID)
                },
                onOpenParentPage: {
                    viewModel.openParentPageForCurrentPageForUI()
                },
                onOpenBlockReference: { targetPageID, targetBlockID in
                    viewModel.openBlockReference(targetPageID: targetPageID, targetBlockID: targetBlockID)
                },
                onAcceptConflict: { conflict in
                    viewModel.acceptRemoteConflictForUI(id: conflict.id)
                },
                onAcceptAllConflicts: {
                    viewModel.acceptAllRemoteConflictsForSelectedPageForUI()
                },
                onAcceptLocalConflict: { conflict in
                    viewModel.acceptLocalConflictForUI(id: conflict.id)
                },
                onAcceptAllLocalConflicts: {
                    viewModel.acceptAllLocalConflictsForSelectedPageForUI()
                },
                onResolveConflictManually: { conflict, text in
                    viewModel.resolveConflictManuallyForUI(id: conflict.id, text: text)
                },
                onResolveAllConflictsManually: { mergedTextsByConflictID in
                    viewModel.resolveAllManualConflictsForSelectedPageForUI(
                        mergedTextsByConflictID: mergedTextsByConflictID
                    )
                },
                onPageTitleChange: { title in
                    viewModel.editSelectedPageTitle(title)
                },
                onImportMarkdown: { sourceURL in
                    viewModel.importMarkdownFileForCurrentPage(sourceURL: sourceURL)
                },
                onImportObsidianVault: { sourceURL in
                    viewModel.importObsidianVaultForCurrentWorkspace(sourceURL: sourceURL)
                },
                onExportMarkdown: {
                    viewModel.exportCurrentPageMarkdown()
                },
                onExportMarkdownPackage: { destinationURL in
                    viewModel.exportCurrentPageMarkdownPackageForUI(to: destinationURL)
                },
                onBlockTextChange: { blockID, text in
                    viewModel.editBlockText(blockID: blockID, text: text)
                },
                onTableRowsChange: { blockID, rows in
                    viewModel.updateTableRowsForUI(blockID: blockID, rows: rows)
                },
                onBlockTypeChange: { blockID, type in
                    viewModel.changeBlockTypeForUI(blockID: blockID, type: type)
                },
                onConvertBlockToPage: { blockID in
                    viewModel.convertTextBlockToPageForUI(blockID: blockID)
                },
                onTaskItemCompletionChange: { blockID, isCompleted in
                    viewModel.updateTaskItemCompletionForUI(
                        blockID: blockID,
                        isCompleted: isCompleted
                    )
                },
                onCodeBlockLineWrappingChange: { blockID, isWrapped in
                    viewModel.updateCodeBlockLineWrapping(blockID: blockID, isWrapped: isWrapped)
                },
                onToggleBlockExpansion: { blockID in
                    viewModel.toggleBlockExpansion(blockID: blockID)
                },
                isToggleBlockExpanded: { blockID in
                    viewModel.isToggleBlockExpanded(blockID: blockID)
                },
                onImportAttachment: { sourceURL in
                    viewModel.importAttachmentForCurrentPage(sourceURL: sourceURL)
                },
                onImportAttachmentsAfterBlock: { sourceURLs, blockID in
                    viewModel.importAttachmentsForCurrentPage(
                        sourceURLs: sourceURLs,
                        afterBlockID: blockID
                    )
                },
                onRetryAttachmentPreview: { attachmentID in
                    viewModel.retryAttachmentPreviewGeneration(attachmentID: attachmentID)
                },
                onRenameAttachmentImage: { blockID, name in
                    viewModel.renameAttachmentImageForUI(blockID: blockID, name: name)
                },
                onAttachmentImageDisplayWidthChange: { blockID, displayWidth in
                    viewModel.updateAttachmentImageDisplayWidthForUI(
                        blockID: blockID,
                        displayWidth: displayWidth
                    )
                },
                onDrawingBlockDataChange: { blockID, data in
                    viewModel.updateDrawingBlockForUI(blockID: blockID, data: data)
                },
                onMobileRevealPageList: nil,
                onPendingBlockFocusHandled: {
                    _ = viewModel.consumePendingFocusBlockID()
                },
                onPendingPageTitleFocusHandled: {
                    _ = viewModel.consumePendingPageTitleFocusPageID()
                },
                onRemoveTagFromSelectedPage: { tagID in
                    viewModel.removeTagFromSelectedPageForUI(tagID: tagID)
                },
                onCreateAndAssignTagToSelectedPage: { name in
                    viewModel.createAndAssignTagToSelectedPageForUI(name: name)
                }
            )
        } else {
            EditorDesignTokens.Colors.editorBackground.color
                .navigationTitle("编辑器")
        }
    }
}

enum DesktopColumnDividerChrome {
    static let hitWidth: Double = 9
    static let lineWidth: Double = 1
    static let idleOpacity: Double = 0.24
    static let hoverOpacity: Double = 0.40
    static let draggingOpacity: Double = 0.58
}

enum CompactPagePushAnimationPolicy {
    static let disablesProgrammaticPushAnimation = true
}

enum DesktopColumnResizeDragResolver {
    static func width(startWidth: CGFloat, translation: CGFloat, min: Double, max: Double) -> CGFloat {
        Swift.min(Swift.max(startWidth + translation, CGFloat(min)), CGFloat(max))
    }
}

enum DesktopAuxiliaryRailButtonPolicy {
    static func isOffered(
        showsAuxiliaryRail: Bool,
        displayMode: EditorDisplayMode
    ) -> Bool {
        showsAuxiliaryRail && displayMode.showsAuxiliaryRail
    }
}

private struct DesktopColumnDivider: View {
    let width: CGFloat
    let minWidth: Double
    let maxWidth: Double
    let onWidthChange: (CGFloat) -> Void
    @State private var dragStartWidth: CGFloat?
    @State private var isHovering = false
    @State private var isDragging = false
#if os(macOS)
    @State private var didPushResizeCursor = false
#endif

    var body: some View {
        ZStack(alignment: .trailing) {
            Rectangle()
                .fill(EditorDesignTokens.Colors.border.color.opacity(dividerOpacity))
                .frame(width: CGFloat(DesktopColumnDividerChrome.lineWidth))
                .animation(.easeOut(duration: 0.12), value: dividerOpacity)

            Rectangle()
                .fill(Color.clear)
                .frame(width: CGFloat(DesktopColumnDividerChrome.hitWidth))
                .contentShape(Rectangle())
        }
        .frame(width: CGFloat(DesktopColumnDividerChrome.hitWidth), alignment: .trailing)
        .frame(maxHeight: .infinity)
        .onHover { hovering in
            isHovering = hovering
            updateResizeCursor(isActive: hovering || isDragging)
        }
        .gesture(
            DragGesture(minimumDistance: 2, coordinateSpace: .global)
                .onChanged { value in
                    isDragging = true
                    updateResizeCursor(isActive: true)
                    let startWidth = dragStartWidth ?? width
                    dragStartWidth = startWidth
                    onWidthChange(
                        DesktopColumnResizeDragResolver.width(
                            startWidth: startWidth,
                            translation: value.translation.width,
                            min: minWidth,
                            max: maxWidth
                        )
                    )
                }
                .onEnded { _ in
                    dragStartWidth = nil
                    isDragging = false
                    updateResizeCursor(isActive: isHovering)
                }
        )
        .onDisappear {
            updateResizeCursor(isActive: false)
        }
        .ignoresSafeArea(edges: .vertical)
    }

    private var dividerOpacity: Double {
        if isDragging {
            return DesktopColumnDividerChrome.draggingOpacity
        }
        if isHovering {
            return DesktopColumnDividerChrome.hoverOpacity
        }
        return DesktopColumnDividerChrome.idleOpacity
    }

    private func updateResizeCursor(isActive: Bool) {
#if os(macOS)
        if isActive, !didPushResizeCursor {
            NSCursor.resizeLeftRight.push()
            didPushResizeCursor = true
        } else if !isActive, didPushResizeCursor {
            NSCursor.pop()
            didPushResizeCursor = false
        }
#endif
    }
}

private struct CompactEditorShell: View {
    @ObservedObject var viewModel: WorkspaceViewModel
    @State private var path: [CompactRoute]
    @State private var didPushInitialPage: Bool

    init(viewModel: WorkspaceViewModel) {
        self.viewModel = viewModel
        let initialPath = CompactShellRoutePlanner.initialPath(
            snapshot: viewModel.snapshot,
            selectedPageID: viewModel.selectedPageID,
            selectedCollection: viewModel.selectedCollection
        )
        _path = State(initialValue: initialPath)
        _didPushInitialPage = State(initialValue: !initialPath.isEmpty)
    }

    var body: some View {
        NavigationStack(path: $path) {
            CompactHomeView(
                viewModel: viewModel,
                onRevealNextScreen: {
                    revealNextScreen()
                }
            )
            .navigationDestination(for: CompactRoute.self) { route in
                switch route {
                case .pages:
                    CompactPageListView(
                        viewModel: viewModel,
                        onRevealMainMenu: {
                            path = []
                        }
                    )
                case .collection(let collection):
                    CompactCollectionDestination(
                        viewModel: viewModel,
                        collection: collection,
                        onRevealMainMenu: {
                            revealPreviousScreen()
                        },
                        onRevealNextScreen: {
                            revealNextScreen()
                        }
                    )
                case .page(let pageID):
                    CompactPageDestination(
                        viewModel: viewModel,
                        pageID: pageID,
                        onRevealPageList: {
                            revealPreviousScreen()
                        }
                    )
                }
            }
            .onAppear {
                pushOnAppearNavigationIfNeeded()
            }
            .onChange(of: viewModel.selectedPageID) { _, _ in
                pushInitialPageIfNeeded()
            }
            .onChange(of: viewModel.snapshot.pages.map(\.id)) { _, _ in
                pushInitialPageIfNeeded()
            }
            .onChange(of: viewModel.pendingCompactPageNavigationID) { _, pageID in
                guard let pageID = viewModel.consumePendingCompactPageNavigationID() ?? pageID else {
                    return
                }
                pushPageIfNeeded(pageID)
            }
            .onChange(of: viewModel.pendingCompactCollectionNavigation) { _, _ in
                _ = pushPendingCollectionIfNeeded()
            }
        }
    }

    private func pushOnAppearNavigationIfNeeded() {
        let plannedPath = CompactShellPendingNavigationPlanner.onAppearPath(
            snapshot: viewModel.snapshot,
            selectedPageID: viewModel.selectedPageID,
            selectedCollection: viewModel.selectedCollection,
            pendingCollection: viewModel.pendingCompactCollectionNavigation,
            pendingPageID: viewModel.pendingCompactPageNavigationID,
            didPushInitialPage: didPushInitialPage
        )

        guard !plannedPath.isEmpty else {
            return
        }

        if viewModel.pendingCompactCollectionNavigation != nil {
            _ = viewModel.consumePendingCompactCollectionNavigation()
            _ = viewModel.consumePendingCompactPageNavigationID()
        } else if viewModel.pendingCompactPageNavigationID != nil {
            _ = viewModel.consumePendingCompactPageNavigationID()
        }
        path = plannedPath
        didPushInitialPage = true
    }

    @discardableResult
    private func pushPendingCollectionIfNeeded() -> Bool {
        guard let collection = viewModel.consumePendingCompactCollectionNavigation() else {
            return false
        }
        _ = viewModel.consumePendingCompactPageNavigationID()
        path = [CompactShellRoutePlanner.documentListRoute(selectedCollection: collection)]
        didPushInitialPage = true
        return true
    }

    private func pushInitialPageIfNeeded() {
        guard !didPushInitialPage else {
            return
        }

        guard let pageID = CompactInitialNavigationResolver.initialPageID(
            selectedPageID: viewModel.selectedPageID,
            availablePageIDs: viewModel.snapshot.pages.map(\.id)
        ) else {
            return
        }
        pushPageIfNeeded(pageID)
        didPushInitialPage = true
    }

    private func pushPageIfNeeded(_ pageID: String) {
        guard viewModel.snapshot.pages.contains(where: { $0.id == pageID }) else {
            return
        }

        let nextPath = CompactShellRoutePlanner.pathForPage(
            pageID,
            snapshot: viewModel.snapshot,
            selectedCollection: viewModel.selectedCollection
        )
        guard nextPath != path else {
            return
        }

        guard CompactPagePushAnimationPolicy.disablesProgrammaticPushAnimation else {
            path = nextPath
            return
        }

        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            path = nextPath
        }
    }

    private func revealPreviousScreen() {
        let previousPath = CompactShellRoutePlanner.previousScreenPath(currentPath: path)
        if previousPath.isEmpty, path.count > 1 {
            path = [CompactShellRoutePlanner.documentListRoute(selectedCollection: viewModel.selectedCollection)]
        } else {
            path = previousPath
        }
    }

    private func revealNextScreen() {
        path = CompactShellRoutePlanner.nextScreenPath(
            currentPath: path,
            snapshot: viewModel.snapshot,
            selectedCollection: viewModel.selectedCollection
        )
    }
}

private struct CompactHomeView: View {
    @ObservedObject var viewModel: WorkspaceViewModel
    let onRevealNextScreen: () -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                header
                librarySection
                tagSection
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
        }
        .accessibilityIdentifier("editor.compact-library")
        .navigationTitle("资料库")
        .background(CompactLibraryChrome.backgroundColor)
        .overlay(alignment: .bottomTrailing) {
            quickCreateButton
                .padding(.trailing, 18)
                .padding(.bottom, 18)
        }
#if os(iOS)
        .highPriorityGesture(compactForwardSwipeGesture)
        .toolbarBackground(CompactLibraryChrome.backgroundColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
#endif
    }

#if os(iOS)
    private var compactForwardSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 56, coordinateSpace: .local)
            .onEnded { value in
                guard value.translation.width < -56,
                      abs(value.translation.width) > abs(value.translation.height) * 1.25 else {
                    return
                }
                onRevealNextScreen()
            }
    }
#endif

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "sidebar.left")
                .font(.title3.weight(.semibold))
                .foregroundStyle(CompactLibraryChrome.mutedForegroundColor)

            Text("资料库")
                .font(.title2.weight(.bold))
                .foregroundStyle(CompactLibraryChrome.primaryForegroundColor)

            Spacer()

            Button {
                _ = viewModel.createNewDocumentForCompactUI()
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(CompactLibraryChrome.primaryForegroundColor)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("新建文档")
            .accessibilityIdentifier("editor.compact.new-document")
        }
    }

    private var librarySection: some View {
        VStack(spacing: 6) {
            ForEach(CompactLibraryNavigationModel.items(snapshot: viewModel.snapshot)) { item in
                compactNavigationRow(item: item)
            }
        }
    }

    private var tagSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("标签")
                .font(.headline.weight(.semibold))
                .foregroundStyle(CompactLibraryChrome.mutedForegroundColor)
                .padding(.horizontal, 4)

            ForEach(viewModel.snapshot.tags.prefix(8)) { tag in
                HStack(spacing: 10) {
                    Image(systemName: "tag")
                        .foregroundStyle(CompactLibraryChrome.mutedForegroundColor)
                        .frame(width: 22)
                    Text(tag.path)
                        .lineLimit(1)
                    Spacer()
                    Text("\(tagCount(tag.id))")
                        .foregroundStyle(CompactLibraryChrome.mutedForegroundColor)
                }
                .font(.body.weight(.medium))
                .foregroundStyle(CompactLibraryChrome.primaryForegroundColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: CGFloat(CompactLibraryChrome.rowCornerRadius), style: .continuous)
                        .fill(CompactLibraryChrome.unselectedRowColor)
                )
            }
        }
    }

    private func compactNavigationRow(item: CompactLibraryNavigationItem) -> some View {
        let isSelected = viewModel.selectedCollection == item.collection
        return NavigationLink(value: item.route) {
            HStack(spacing: 10) {
                Image(systemName: item.systemImage)
                    .frame(width: 22)
                    .foregroundStyle(isSelected ? CompactLibraryChrome.primaryForegroundColor : CompactLibraryChrome.mutedForegroundColor)
                Text(item.title)
                    .font(.body.weight(.semibold))
                Spacer()
                if item.showsCount {
                    Text("\(item.count)")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(CompactLibraryChrome.mutedForegroundColor)
                }
            }
            .foregroundStyle(isSelected ? CompactLibraryChrome.primaryForegroundColor : CompactLibraryChrome.mutedForegroundColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: CGFloat(CompactLibraryChrome.rowCornerRadius), style: .continuous)
                    .fill(isSelected ? CompactLibraryChrome.selectedRowColor : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(item.identifier)
    }

    private var quickCreateButton: some View {
        MobileQuickCreateButton(
            onCreateNewDocument: {
                _ = viewModel.createNewDocumentForCompactUI()
            },
            onCreateDailyDiary: {
                _ = viewModel.createDailyDiaryForCompactUI()
            }
        )
    }

    private func tagCount(_ tagID: String) -> Int {
        viewModel.snapshot.pageTags.filter { $0.tagID == tagID }.count
    }
}

private struct MobileQuickCreateButton: View {
    let onCreateNewDocument: () -> Void
    let onCreateDailyDiary: () -> Void

    var body: some View {
        Button(action: onCreateNewDocument) {
            Image(systemName: MobileQuickCreateButtonChrome.iconSystemName)
                .font(.system(size: MobileQuickCreateButtonChrome.iconSize, weight: .medium))
                .foregroundStyle(Color.white)
                .frame(
                    width: MobileQuickCreateButtonChrome.diameter,
                    height: MobileQuickCreateButtonChrome.diameter
                )
                .background(
                    Circle()
                        .fill(MobileActionChrome.accentColor)
                        .shadow(
                            color: EditorDesignTokens.Colors.shadow.color.opacity(MobileQuickCreateButtonChrome.shadowOpacity),
                            radius: MobileQuickCreateButtonChrome.shadowRadius,
                            x: 0,
                            y: MobileQuickCreateButtonChrome.shadowYOffset
                        )
                )
        }
        .buttonStyle(.plain)
	        .contextMenu {
            ForEach(MobileQuickCreateMenuModel.longPressActions, id: \.self) { action in
                Button {
                    perform(action)
                } label: {
                    Label(title(for: action), systemImage: systemImage(for: action))
                }
            }
        }
        .accessibilityLabel("快速创建")
        .accessibilityValue("点击新建笔记，长按选择日记或笔记")
        .accessibilityIdentifier("editor.mobile.quick-create")
    }

    private func perform(_ action: MobileQuickCreateAction) {
        switch action {
        case .dailyDiary:
            onCreateDailyDiary()
        case .newDocument:
            onCreateNewDocument()
        }
    }

    private func title(for action: MobileQuickCreateAction) -> String {
        switch action {
        case .dailyDiary:
            return "创建日记"
        case .newDocument:
            return "新建笔记"
        }
    }

    private func systemImage(for action: MobileQuickCreateAction) -> String {
        switch action {
        case .dailyDiary:
            return "square.and.pencil"
        case .newDocument:
            return "doc.badge.plus"
        }
    }
}

enum MobileQuickCreateButtonChrome {
    static let iconSystemName = "pencil"
    static let diameter: CGFloat = 54
    static let iconSize: CGFloat = 23
    static let shadowOpacity: Double = 0.16
    static let shadowRadius: CGFloat = 14
    static let shadowYOffset: CGFloat = 8
}

private struct CompactRecentPageCard: View {
    let page: PageSummary
    let tagNames: [String]
    let preview: PageListPreview

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(page.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(EditorDesignTokens.Colors.primaryText.color)
                    .lineLimit(1)
                PageRowStatusBadges(page: page, font: .caption.weight(.semibold))
                Spacer()
            }

            Text(page.isEncrypted ? "加密内容" : preview.excerpt?.isEmpty == false ? preview.excerpt ?? "" : "空白文档")
                .font(.callout)
                .foregroundStyle(EditorDesignTokens.Colors.secondaryText.color)
                .lineLimit(2)

            if !tagNames.isEmpty {
                HStack(spacing: 6) {
                    ForEach(tagNames.prefix(3), id: \.self) { tagName in
                        Text("#\(tagName)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(EditorDesignTokens.Colors.secondaryText.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(EditorDesignTokens.Colors.border.color.opacity(0.42))
                            )
                    }
                }
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, minHeight: CompactDocumentListChrome.rowMinHeight, alignment: .leading)
        .background(PageListChrome.backgroundColor)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PageListChrome.dividerColor)
                .frame(height: 1)
        }
    }
}

enum PageRowLeadingGlyphPolicy {
    static let showsDocumentIcon = false
}

enum PageRowStatusBadgeKind: Hashable, Sendable {
    case pinned
    case favorite
    case encrypted
}

struct PageRowStatusBadge: Equatable, Sendable {
    let kind: PageRowStatusBadgeKind
    let systemImage: String
    let accessibilityLabel: String
}

enum PageRowStatusBadgeModel {
    static func badges(for page: PageSummary) -> [PageRowStatusBadge] {
        var badges: [PageRowStatusBadge] = []
        if page.isPinned {
            badges.append(
                PageRowStatusBadge(
                    kind: .pinned,
                    systemImage: "pin.fill",
                    accessibilityLabel: "已置顶"
                )
            )
        }
        if page.isFavorite {
            badges.append(
                PageRowStatusBadge(
                    kind: .favorite,
                    systemImage: "star.fill",
                    accessibilityLabel: "已收藏"
                )
            )
        }
        if page.isEncrypted {
            badges.append(
                PageRowStatusBadge(
                    kind: .encrypted,
                    systemImage: "lock.fill",
                    accessibilityLabel: "已加密"
                )
            )
        }
        return badges
    }
}

enum PageRowSwipeActionKind: Hashable, Sendable {
    case archive
    case favorite
    case pin

    var accessibilityIdentifier: String {
        switch self {
        case .archive:
            return "archive"
        case .favorite:
            return "favorite"
        case .pin:
            return "pin"
        }
    }
}

struct PageRowSwipeAction: Identifiable, Equatable, Sendable {
    let kind: PageRowSwipeActionKind
    let title: String
    let systemImage: String

    var id: PageRowSwipeActionKind {
        kind
    }
}

enum PageRowSwipeActionModel {
    static func actions(for page: PageSummary) -> [PageRowSwipeAction] {
        [
            PageRowSwipeAction(
                kind: .archive,
                title: "归档",
                systemImage: "archivebox"
            ),
            PageRowSwipeAction(
                kind: .favorite,
                title: page.isFavorite ? "取消收藏" : "收藏",
                systemImage: page.isFavorite ? "star.slash" : "star"
            ),
            PageRowSwipeAction(
                kind: .pin,
                title: page.isPinned ? "取消置顶" : "置顶",
                systemImage: page.isPinned ? "pin.slash" : "pin"
            )
        ]
    }
}

enum CompactPageSwipeActionChrome {
    static let actionWidth: CGFloat = 62
    static let actionHeight: CGFloat = CompactDocumentListChrome.rowMinHeight
    static let cornerRadius: CGFloat = 14
    static let iconSize: CGFloat = 21
    static let iconWeight: Font.Weight = .medium
    static let releaseSpringResponse: Double = 0.28
    static let releaseSpringDampingFraction: Double = 0.72
    static let releaseSpringBlendDuration: Double = 0.08

    static var releaseAnimation: Animation {
        .interactiveSpring(
            response: releaseSpringResponse,
            dampingFraction: releaseSpringDampingFraction,
            blendDuration: releaseSpringBlendDuration
        )
    }

    static func colorToken(for action: PageRowSwipeActionKind) -> EditorColorToken {
        switch action {
        case .archive:
            return EditorColorToken.hex(0xEF, 0x6F, 0x63)
        case .favorite:
            return EditorColorToken.hex(0xF1, 0xC9, 0x55)
        case .pin:
            return EditorColorToken.hex(0x7D, 0x97, 0xE8)
        }
    }

    static func color(for action: PageRowSwipeActionKind) -> Color {
        colorToken(for: action).color
    }
}

enum CompactPageSwipeRevealPolicy {
    static let openThresholdRatio: CGFloat = 0.42
    static let closeThresholdRatio: CGFloat = 0.58
    static let minimumActionWidthScale: CGFloat = 0.62
    static let fadeSlideDistance: CGFloat = 18

    static func visibleWidth(horizontalOffset: CGFloat, maximumRevealWidth: CGFloat) -> CGFloat {
        min(max(-horizontalOffset, 0), maximumRevealWidth)
    }

    static func revealProgress(visibleWidth: CGFloat, maximumRevealWidth: CGFloat) -> CGFloat {
        guard maximumRevealWidth > 0 else {
            return 0
        }
        return min(max(visibleWidth / maximumRevealWidth, 0), 1)
    }

    static func actionWidthScale(visibleWidth: CGFloat, maximumRevealWidth: CGFloat) -> CGFloat {
        max(
            minimumActionWidthScale,
            revealProgress(visibleWidth: visibleWidth, maximumRevealWidth: maximumRevealWidth)
        )
    }

    static func actionGroupWidth(visibleWidth: CGFloat, maximumRevealWidth: CGFloat) -> CGFloat {
        maximumRevealWidth * actionWidthScale(
            visibleWidth: visibleWidth,
            maximumRevealWidth: maximumRevealWidth
        )
    }

    static func actionHeight(visibleWidth: CGFloat) -> CGFloat {
        CompactPageSwipeActionChrome.actionHeight
    }

    static func cornerRadius(visibleWidth: CGFloat) -> CGFloat {
        CompactPageSwipeActionChrome.cornerRadius
    }

    static func iconScale(visibleWidth: CGFloat, maximumRevealWidth: CGFloat) -> CGFloat {
        actionWidthScale(visibleWidth: visibleWidth, maximumRevealWidth: maximumRevealWidth)
    }

    static func opacity(visibleWidth: CGFloat, maximumRevealWidth: CGFloat) -> Double {
        let progress = revealProgress(visibleWidth: visibleWidth, maximumRevealWidth: maximumRevealWidth)
        return Double(min(progress / minimumActionWidthScale, 1))
    }

    static func trailingOffset(visibleWidth: CGFloat, maximumRevealWidth: CGFloat) -> CGFloat {
        let progress = revealProgress(visibleWidth: visibleWidth, maximumRevealWidth: maximumRevealWidth)
        return (1 - min(progress / minimumActionWidthScale, 1)) * fadeSlideDistance
    }

    static func shouldStayOpen(
        startOffset: CGFloat,
        translationWidth: CGFloat,
        projectedOffset: CGFloat,
        maximumRevealWidth: CGFloat
    ) -> Bool {
        let projectedVisibleWidth = visibleWidth(
            horizontalOffset: projectedOffset,
            maximumRevealWidth: maximumRevealWidth
        )
        let thresholdRatio = startOffset < 0 && translationWidth > 0
            ? closeThresholdRatio
            : openThresholdRatio
        return projectedVisibleWidth >= maximumRevealWidth * thresholdRatio
    }
}

private struct PageRowStatusBadges: View {
    let page: PageSummary
    let font: Font

    var body: some View {
        HStack(spacing: 4) {
            ForEach(PageRowStatusBadgeModel.badges(for: page), id: \.kind) { badge in
                Image(systemName: badge.systemImage)
                    .font(font)
                    .foregroundStyle(color(for: badge.kind))
                    .accessibilityLabel(badge.accessibilityLabel)
            }
        }
        .accessibilityHidden(true)
    }

    private func color(for kind: PageRowStatusBadgeKind) -> Color {
        switch kind {
        case .pinned:
            return EditorDesignTokens.Colors.accent.color
        case .favorite:
            return .yellow
        case .encrypted:
            return EditorDesignTokens.Colors.tertiaryText.color
        }
    }
}

enum EditorBlockChrome {
    static let blockSpacing: Double = 0
    static let rowVerticalPadding: Double = 0
    static let listVerticalPadding: Double = 0
    static let listHorizontalPadding: Double = 0
    static let listBackgroundOpacity: Double = 0
    static let listMarkerWidth: Double = 18
    static let listTextSpacing: Double = 4
    static let listMarkerTopPadding: Double = 3
    static let listMarkerLineHeight: Double = 18
    static let canvasTrailingFocusHitHeight: Double = 760
    static let listNestingIndentWidth: Double = 24
    static let actionColumnWidth: Double = 18
    static let actionColumnSpacing: Double = 5
    static let dragHandleWidth: Double = 18
    static let inactiveHandleOpacity: Double = 0
    static let inlineControlTopPadding: Double = 1
    static let taskControlIconSize: Double = 16
    static let specialBlockCornerRadius: Double = 5
    static let dropTargetHeight: Double = 32
    static let dropSlotHeight: Double = 4
    static let dropIndicatorAfterOffset: Double = 0
    static let trailingInsertHitHeight: Double = 64
}

enum BlockDragHandleVisibilityPolicy {
    static func opacity(isHovered: Bool) -> Double {
        isHovered ? 1 : EditorBlockChrome.inactiveHandleOpacity
    }
}

enum MobileBlockDragHandleVisibilityPolicy {
    static func opacity(isSelectionModeActive: Bool) -> Double {
        0
    }
}

enum MobileBlockDragActivationPolicy {
    static let usesVisibleDragHandle = false
    static let usesLongPressDraggableRow = true
    static let usesWholeRowDropTarget = true
    static let usesNativeTextViewDragInteraction = true
}

enum MobileBlockContextMenuPolicy {
    static func enablesRowContextMenu(usesNativeTextEditor: Bool) -> Bool {
        !usesNativeTextEditor
    }
}

enum MobileBlockDropTargetPolicy {
    static let estimatedRowDropSize = CGSize(width: 1, height: 44)

    static func resolution(
        location: CGPoint,
        destinationLevel: Int
    ) -> BlockDropPlacementResolution {
        BlockDropPlacementResolver.resolution(
            location: location,
            rowSize: estimatedRowDropSize,
            destinationLevel: destinationLevel
        )
    }

    static func placement(
        location: CGPoint,
        destinationLevel: Int
    ) -> BlockDropPlacement {
        resolution(location: location, destinationLevel: destinationLevel).placement
    }
}

enum MobileQuickCreateAction: Equatable, Hashable, Sendable {
    case dailyDiary
    case newDocument
}

enum MobileQuickCreateMenuModel {
    static let longPressActions: [MobileQuickCreateAction] = [
        .dailyDiary,
        .newDocument
    ]
}

enum AttachmentImageCaptionVisibilityPolicy {
    static func isVisible(blockText: String, originalFilename: String?) -> Bool {
        let displayName = blockText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !displayName.isEmpty else {
            return false
        }

        guard let originalFilename else {
            return true
        }

        return displayName != originalFilename
    }
}

enum AttachmentImageDisplayWidthPolicy {
    static let defaultWidth: CGFloat = 460
    static let minimumWidth: CGFloat = 160
    static let maximumWidth: CGFloat = 680
    static let resizeHandleSize: CGFloat = 18

    static func resolvedWidth(storedWidth: Double?, availableWidth: CGFloat) -> CGFloat {
        let available = max(1, availableWidth)
        let preferred = CGFloat(storedWidth ?? Double(defaultWidth))
        return min(max(preferred, minimumWidth), min(maximumWidth, available))
    }

    static func widthAfterDrag(
        startWidth: CGFloat,
        translation: CGSize,
        availableWidth: CGFloat
    ) -> CGFloat {
        resolvedWidth(
            storedWidth: Double(startWidth + translation.width),
            availableWidth: availableWidth
        )
    }

    static func storedWidth(_ width: CGFloat) -> Double {
        Double(width.rounded())
    }
}

enum AttachmentImageCandidatePathState: Equatable, Sendable {
    case missing
    case undecodable
    case loadable
}

enum AttachmentImagePreviewDiagnosticReason: String, Equatable, Sendable {
    case missingAttachment
    case waitingForSync
    case fileMissing
    case decodeFailed
    case generationFailed

    var showsWarningIcon: Bool {
        self != .waitingForSync
    }
}

struct AttachmentImagePreviewDiagnosticMessage: Equatable, Sendable {
    let title: String
    let detail: String
}

enum AttachmentImagePreviewDiagnosticResolver {
    static func reason(
        attachmentAvailable: Bool,
        candidatePathStates: [AttachmentImageCandidatePathState],
        isPending: Bool,
        isGenerationFailed: Bool
    ) -> AttachmentImagePreviewDiagnosticReason? {
        guard attachmentAvailable else {
            return .missingAttachment
        }

        if isGenerationFailed {
            return .generationFailed
        }

        if candidatePathStates.contains(.loadable) {
            return nil
        }

        if isPending || candidatePathStates.isEmpty {
            return .waitingForSync
        }

        if candidatePathStates.allSatisfy({ $0 == .missing }) {
            return .fileMissing
        }

        return .decodeFailed
    }

    static func message(
        for reason: AttachmentImagePreviewDiagnosticReason
    ) -> AttachmentImagePreviewDiagnosticMessage {
        switch reason {
        case .missingAttachment:
            return AttachmentImagePreviewDiagnosticMessage(
                title: "图片附件缺失",
                detail: "当前块找不到对应的附件记录，可能是同步未完成或附件元数据丢失。"
            )
        case .waitingForSync:
            return AttachmentImagePreviewDiagnosticMessage(
                title: "等待图片同步",
                detail: "图片记录已存在，但本机还没有可读取的图片文件或缩略图。"
            )
        case .fileMissing:
            return AttachmentImagePreviewDiagnosticMessage(
                title: "图片文件缺失",
                detail: "附件路径已记录，但本机找不到对应文件。"
            )
        case .decodeFailed:
            return AttachmentImagePreviewDiagnosticMessage(
                title: "图片无法读取",
                detail: "文件存在，但系统图片解码失败，可能是文件损坏或格式不支持。"
            )
        case .generationFailed:
            return AttachmentImagePreviewDiagnosticMessage(
                title: "预览生成失败",
                detail: "缩略图生成失败，可以点右侧按钮重试。"
            )
        }
    }
}

enum AttachmentImagePreviewZoomPolicy {
    static let minimumScale: CGFloat = 1
    static let maximumScale: CGFloat = 5

    static func clampedScale(_ scale: CGFloat) -> CGFloat {
        min(max(scale, minimumScale), maximumScale)
    }

    static func persistedOffset(currentOffset: CGSize, scale: CGFloat) -> CGSize {
        scale > minimumScale ? currentOffset : .zero
    }
}

enum AttachmentImageResizeGestureCoordinateSpace: Equatable, Sendable {
    case stableGlobal
}

enum AttachmentImageResizeGesturePolicy {
    static let minimumDistance: CGFloat = 2
    static let coordinateSpace: AttachmentImageResizeGestureCoordinateSpace = .stableGlobal

    static var swiftUICoordinateSpace: CoordinateSpace {
        switch coordinateSpace {
        case .stableGlobal:
            return .global
        }
    }
}

enum AttachmentImageSelectionChrome {
    static func rowBackgroundOpacity(isSelected: Bool) -> Double {
        0
    }

    static func rowBorderOpacity(isSelected: Bool) -> Double {
        0
    }

    static func imageBorderOpacity(isSelected: Bool) -> Double {
        isSelected ? 0.85 : 0.06
    }

    static let imageBorderRed = EditorDesignTokens.Colors.border.red
    static let imageBorderGreen = EditorDesignTokens.Colors.border.green
    static let imageBorderBlue = EditorDesignTokens.Colors.border.blue

    static func imageBorderColor(isSelected: Bool) -> Color {
        EditorDesignTokens.Colors.border.color.opacity(imageBorderOpacity(isSelected: isSelected))
    }
}

enum ListMarkerHorizontalAlignment: Equatable, Sendable {
    case leading

    var frameAlignment: Alignment {
        switch self {
        case .leading:
            return .leading
        }
    }
}

struct ListMarkerGlyphFrameDescriptor: Equatable, Sendable {
    let width: Double
    let height: Double
    let horizontalAlignment: ListMarkerHorizontalAlignment

    init(
        width: Double = EditorBlockChrome.listMarkerWidth,
        height: Double = EditorBlockChrome.listMarkerLineHeight,
        horizontalAlignment: ListMarkerHorizontalAlignment = .leading
    ) {
        self.width = width
        self.height = height
        self.horizontalAlignment = horizontalAlignment
    }
}

struct ListMarkerBulletGlyphDescriptor: Equatable, Sendable {
    let diameter: Double
    let strokeLineWidth: Double
    let visibleLeadingOffset: Double
    let visibleTopOffset: Double

    init(
        diameter: Double = 6,
        strokeLineWidth: Double = 1.4,
        visibleLeadingOffset: Double = 0,
        visibleTopOffset: Double = 0
    ) {
        self.diameter = diameter
        self.strokeLineWidth = strokeLineWidth
        self.visibleLeadingOffset = visibleLeadingOffset
        self.visibleTopOffset = visibleTopOffset
    }
}

struct InlineLeadingControlFrameDescriptor: Equatable, Sendable {
    let width: Double
    let height: Double
    let topPadding: Double
    let textSpacing: Double
    let textVerticalOffset: Double

    init(
        width: Double = EditorBlockChrome.listMarkerWidth,
        height: Double = EditorBlockChrome.listMarkerLineHeight,
        topPadding: Double = EditorBlockChrome.listMarkerTopPadding,
        textSpacing: Double = EditorBlockChrome.listTextSpacing,
        textVerticalOffset: Double = -4
    ) {
        self.width = width
        self.height = height
        self.topPadding = topPadding
        self.textSpacing = textSpacing
        self.textVerticalOffset = textVerticalOffset
    }
}

enum ListMarkerBulletStyleResolver {
    static func isHollow(nestingLevel: Int) -> Bool {
        max(0, nestingLevel).isMultiple(of: 2) == false
    }
}

enum BlockRowNestingIndentResolver {
    static func leadingPadding(nestingLevel: Int, blockType: BlockType) -> Double {
        let level = max(0, nestingLevel)
        let width: Double
        switch blockType {
        case .unorderedListItem, .orderedListItem, .taskItem:
            width = EditorBlockChrome.listNestingIndentWidth
        default:
            width = BlockDropPlacementResolver.levelIndentWidth
        }
        return Double(level) * width
    }
}

enum BlockRowBackgroundPolicy {
    static func opacity(
        blockType: BlockType,
        isSelected: Bool,
        isFocused: Bool,
        isSlashCommandMenuVisible: Bool,
        suppressesSelectionChrome: Bool = false
    ) -> Double {
        if blockType == .table || blockType == .divider || isSlashCommandMenuVisible {
            return 0
        }
        if blockType == .attachmentImage {
            return AttachmentImageSelectionChrome.rowBackgroundOpacity(isSelected: isSelected)
        }
        if isSelected && !suppressesSelectionChrome {
            return 0.08
        }
        if isFocused {
            return 0.32
        }
        return 0
    }
}

enum BlockRowSelectionBorderPolicy {
    static func opacity(
        blockType: BlockType,
        isSelected: Bool,
        suppressesSelectionChrome: Bool = false
    ) -> Double {
        if blockType == .attachmentImage {
            return AttachmentImageSelectionChrome.rowBorderOpacity(isSelected: isSelected)
        }
        guard isSelected, !suppressesSelectionChrome, blockType != .divider else {
            return 0
        }
        return 0.28
    }
}

enum NonEditableBlockSelectionPolicy {
    static func selectsBlockOnFocusRequest(blockType: BlockType) -> Bool {
        blockType != .divider
    }
}

enum TextEditableBlockChromePolicy {
    static func backgroundOpacity(blockType: BlockType) -> Double {
        switch blockType {
        case .taskItem, .toggle:
            return 0
        default:
            return EditorBlockChrome.listBackgroundOpacity
        }
    }
}

enum SpecialBlockSurfaceChrome {
    static let codeBackgroundToken = EditorDesignTokens.Colors.codeBlockBackground
    static let calloutBackgroundToken = EditorDesignTokens.Colors.calloutBackground
    static let quoteBackgroundToken = EditorDesignTokens.Colors.quoteBackground
    static let attachmentBackgroundToken = EditorDesignTokens.Colors.attachmentBackground
    static let drawingCanvasBackgroundToken = EditorDesignTokens.Colors.drawingCanvasBackground
}

enum StatusChrome {
    static let warningTextToken = EditorDesignTokens.Colors.warningText
    static let warningFillToken = EditorDesignTokens.Colors.warningFill
    static let warningStrokeToken = EditorDesignTokens.Colors.warningStroke
}

enum ConflictDiffChrome {
    static let unchangedTextToken = EditorDesignTokens.Colors.secondaryText
    static let unchangedFillToken = EditorDesignTokens.Colors.controlBackgroundSubtle
    static let removedTextToken = EditorDesignTokens.Colors.danger
    static let removedFillToken = EditorDesignTokens.Colors.dangerFill
    static let addedTextToken = EditorDesignTokens.Colors.successText
    static let addedFillToken = EditorDesignTokens.Colors.successFill
}

enum ListMarkerColumnAlignmentResolver {
    static func leadingOffset(markerWidth: Double, columnWidth: Double) -> Double {
        0
    }
}

struct DragPreviewLayoutDescriptor: Equatable, Sendable {
    let pointerHorizontalOffset: Double
    let pointerVerticalOffset: Double
    let visibleCardWidth: Double
    let visibleCardMaxHeight: Double
    let trailingInset: Double
    let bottomInset: Double
    let invisibleSpacerOpacity: Double

    init(
        pointerHorizontalOffset: Double = 320,
        pointerVerticalOffset: Double = 96,
        visibleCardWidth: Double = 284,
        visibleCardMaxHeight: Double = 64,
        trailingInset: Double = 8,
        bottomInset: Double = 8,
        invisibleSpacerOpacity: Double = 0.001
    ) {
        self.pointerHorizontalOffset = pointerHorizontalOffset
        self.pointerVerticalOffset = pointerVerticalOffset
        self.visibleCardWidth = visibleCardWidth
        self.visibleCardMaxHeight = visibleCardMaxHeight
        self.trailingInset = trailingInset
        self.bottomInset = bottomInset
        self.invisibleSpacerOpacity = invisibleSpacerOpacity
    }

    var previewWidth: Double {
        pointerHorizontalOffset + visibleCardWidth + trailingInset
    }

    var previewHeight: Double {
        pointerVerticalOffset + visibleCardMaxHeight + bottomInset
    }

    var visibleCardLeadingFromCenteredPointer: Double {
        pointerHorizontalOffset - previewWidth / 2
    }

    var visibleCardTopFromCenteredPointer: Double {
        pointerVerticalOffset - previewHeight / 2
    }
}

enum BlockDropIndicatorChrome {
    static let lineHeight: Double = 1.5
    static let standardOpacity: Double = 0.58
    static let emphasizedOpacity: Double = 0.72
}

enum MobileActionChrome {
    static let accentToken = EditorDesignTokens.Colors.accent
    static let selectedFillOpacity: Double = 0.12
    static let selectedButtonFillOpacity: Double = 0.13
    static let selectionBorderOpacity: Double = 0.24

    static var accentColor: Color {
        accentToken.color
    }
}

enum MobileKeyboardToolbarChrome {
    static let height: CGFloat = 44
    static let buttonSize: CGFloat = 34
    static let iconSize: CGFloat = 19
    static let chevronSize: CGFloat = 11
    static let primaryIconWeight: Font.Weight = .regular
    static let secondaryIconWeight: Font.Weight = .medium
}

enum MobileKeyboardToolbarFormatAction: Equatable, Sendable {
    case unorderedList
    case orderedList
    case heading
}

enum MobileKeyboardToolbarFormatActionResolver {
    static let visibleActions: [MobileKeyboardToolbarFormatAction] = [
        .unorderedList,
        .orderedList,
        .heading
    ]
}

enum MobileKeyboardToolbarUtilityAction: Equatable, Sendable {
    case copy
    case paste
    case undo
    case dismissKeyboard
}

enum MobileKeyboardToolbarUtilityActionResolver {
    static let leadingActions: [MobileKeyboardToolbarUtilityAction] = [
        .paste,
        .undo
    ]

    static let visibleActions: [MobileKeyboardToolbarUtilityAction] = [
        .paste,
        .undo
    ]
}

enum MobileKeyboardToolbarTrailingAction: Equatable, Sendable {
    case outline
    case moreFormat
    case dismissKeyboard
}

enum MobileKeyboardToolbarTrailingActionResolver {
    static let visibleActions: [MobileKeyboardToolbarTrailingAction] = [
        .outline,
        .moreFormat,
        .dismissKeyboard
    ]
}

enum MobileFormatPaletteTab: Equatable, Sendable {
    case heading
    case more

    var title: String {
        switch self {
        case .heading:
            return "标题"
        case .more:
            return "更多"
        }
    }
}

enum MobileFormatPaletteTabResolver {
    static let visibleTabs: [MobileFormatPaletteTab] = []
}

enum MobileFormatPaletteChrome {
    static let columnCount = 6
    static let gridSpacing: CGFloat = 10
    static let buttonHeight: CGFloat = 62
    static let horizontalPadding: CGFloat = 16
    static let verticalPadding: CGFloat = 14
    static let cardCornerRadius: CGFloat = 22
    static let height: CGFloat = 328
}

enum MobileFormatPaletteAction: Equatable, Sendable {
    case collapsePanel
    case dismissKeyboard
    case outdent
    case indent
    case paragraph
    case heading1
    case heading2
    case heading3
    case heading4
    case heading5
    case heading6
    case unorderedList
    case orderedList
    case task
    case toggle
    case quote
    case codeBlock
    case table
    case divider
    case callout
    case bold
    case italic
    case strikethrough
    case inlineCode
    case insertLink

    var blockType: BlockType? {
        switch self {
        case .paragraph:
            return .paragraph
        case .heading1:
            return .heading1
        case .heading2:
            return .heading2
        case .heading3:
            return .heading3
        case .heading4:
            return .heading4
        case .heading5:
            return .heading5
        case .heading6:
            return .heading6
        case .unorderedList:
            return .unorderedListItem
        case .orderedList:
            return .orderedListItem
        case .task:
            return .taskItem
        case .toggle:
            return .toggle
        case .quote:
            return .quote
        case .codeBlock:
            return .codeBlock
        case .table:
            return .table
        case .divider:
            return .divider
        case .callout:
            return .callout
        case .collapsePanel,
             .dismissKeyboard,
             .outdent,
             .indent,
             .bold,
             .italic,
             .strikethrough,
             .inlineCode,
             .insertLink:
            return nil
        }
    }

    var inlineFormat: MarkdownInlineFormat? {
        switch self {
        case .bold:
            return .bold
        case .italic:
            return .italic
        case .strikethrough:
            return .strikethrough
        case .inlineCode:
            return .code
        case .collapsePanel,
             .dismissKeyboard,
             .outdent,
             .indent,
             .paragraph,
             .heading1,
             .heading2,
             .heading3,
             .heading4,
             .heading5,
             .heading6,
             .unorderedList,
             .orderedList,
             .task,
             .toggle,
             .quote,
             .codeBlock,
             .table,
             .divider,
             .callout,
             .insertLink:
            return nil
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .collapsePanel:
            return "返回键盘"
        case .dismissKeyboard:
            return "关闭键盘"
        case .outdent:
            return "减少缩进"
        case .indent:
            return "增加缩进"
        case .paragraph:
            return "正文"
        case .heading1:
            return "H1"
        case .heading2:
            return "H2"
        case .heading3:
            return "H3"
        case .heading4:
            return "H4"
        case .heading5:
            return "H5"
        case .heading6:
            return "H6"
        case .unorderedList:
            return "无序列表"
        case .orderedList:
            return "有序列表"
        case .task:
            return "任务"
        case .toggle:
            return "折叠"
        case .quote:
            return "引用"
        case .codeBlock:
            return "代码块"
        case .table:
            return "表格"
        case .divider:
            return "分割线"
        case .callout:
            return "提示"
        case .bold:
            return "加粗"
        case .italic:
            return "斜体"
        case .strikethrough:
            return "删除线"
        case .inlineCode:
            return "代码"
        case .insertLink:
            return "链接"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .collapsePanel:
            return "editor.mobile-format.collapse"
        case .dismissKeyboard:
            return "editor.mobile-format.dismiss-keyboard"
        default:
            return "editor.mobile-format.\(accessibilityLabel)"
        }
    }

    var systemImage: String? {
        switch self {
        case .collapsePanel:
            return "chevron.down"
        case .dismissKeyboard:
            return "keyboard.chevron.compact.down"
        case .outdent:
            return "decrease.indent"
        case .indent:
            return "increase.indent"
        case .paragraph:
            return "text.alignleft"
        case .heading1,
             .heading2,
             .heading3,
             .heading4,
             .heading5,
             .heading6:
            return nil
        case .unorderedList:
            return "list.bullet"
        case .orderedList:
            return "list.number"
        case .task:
            return "checklist"
        case .toggle:
            return "chevron.right.square"
        case .quote:
            return "quote.opening"
        case .codeBlock:
            return "chevron.left.forwardslash.chevron.right"
        case .table:
            return "tablecells"
        case .divider:
            return "minus"
        case .callout:
            return "text.bubble"
        case .bold:
            return "bold"
        case .italic:
            return "italic"
        case .strikethrough:
            return "strikethrough"
        case .inlineCode:
            return "curlybraces"
        case .insertLink:
            return "link"
        }
    }
}

enum MobileFormatPaletteActionResolver {
    static let visibleActions: [MobileFormatPaletteAction] = [
        .collapsePanel,
        .paragraph,
        .table,
        .quote,
        .codeBlock,
        .callout,
        .dismissKeyboard,
        .heading1,
        .bold,
        .italic,
        .strikethrough,
        .inlineCode,
        .outdent,
        .unorderedList,
        .orderedList,
        .task,
        .toggle,
        .insertLink,
        .indent,
        .divider,
        .heading2,
        .heading3,
        .heading4,
        .heading5,
        .heading6
    ]
}

enum CompactChrome {
    static let backgroundToken = PageListChrome.backgroundToken
    static let backgroundRed: Double = backgroundToken.red
    static let backgroundGreen: Double = backgroundToken.green
    static let backgroundBlue: Double = backgroundToken.blue

    static var backgroundYellowBias: Double {
        max(0, ((backgroundRed + backgroundGreen) / 2) - backgroundBlue)
    }

    static var backgroundColor: Color {
        backgroundToken.color
    }
}

enum CompactDocumentListChrome {
    static let horizontalPadding: CGFloat = 24
    static let verticalPadding: CGFloat = 10
    static let rowMinHeight: CGFloat = 86
    static let prefersInlineNavigationTitle = true
}

enum PageListChrome {
    static let backgroundToken = EditorDesignTokens.Colors.documentListBackground
    static let backgroundRed: Double = backgroundToken.red
    static let backgroundGreen: Double = backgroundToken.green
    static let backgroundBlue: Double = backgroundToken.blue
    static let rowDividerOpacity: Double = 0.82
    static let selectedFillOpacity: Double = 0.055
    static let batchFillOpacity: Double = 0.10
    static let batchBorderOpacity: Double = 0.28

    static var backgroundColor: Color {
        backgroundToken.color
    }

    static var dividerColor: Color {
        EditorDesignTokens.Colors.border.color.opacity(rowDividerOpacity)
    }

    static var selectedFillColor: Color {
        EditorDesignTokens.Colors.primaryText.color.opacity(selectedFillOpacity)
    }

    static var batchFillColor: Color {
        EditorDesignTokens.Colors.accent.color.opacity(batchFillOpacity)
    }

    static var batchBorderColor: Color {
        EditorDesignTokens.Colors.accent.color.opacity(batchBorderOpacity)
    }
}

enum CompactLibraryChrome {
    static let backgroundToken = EditorDesignTokens.Colors.appBackground
    static let primaryForegroundToken = EditorDesignTokens.Colors.primaryText
    static let mutedForegroundToken = EditorDesignTokens.Colors.secondaryText
    static let rowCornerRadius: Double = 13
    static let selectedRowOpacity: Double = 0.08
    static let unselectedRowOpacity: Double = 0.035

    static var backgroundColor: Color {
        backgroundToken.color
    }

    static var primaryForegroundColor: Color {
        primaryForegroundToken.color
    }

    static var mutedForegroundColor: Color {
        mutedForegroundToken.color
    }

    static var selectedRowColor: Color {
        primaryForegroundToken.color.opacity(selectedRowOpacity)
    }

    static var unselectedRowColor: Color {
        primaryForegroundToken.color.opacity(unselectedRowOpacity)
    }
}

enum TableBlockChrome {
    static let cellWidth: Double = 168
    static let cellHeight: Double = 44
    static let maxViewportWidth: Double = 520
    static let cornerRadius: Double = 8
    static let gridLineOpacity: Double = 0.070
    static let outerBorderOpacity: Double = 0.120
    static let primaryControlDiameter: Double = 18
    static let insertControlVisibleDiameter: Double = 4
    static let insertControlExpandedDiameter: Double = 10
    static let insertControlIconFontSize: Double = 6
    static let insertControlEdgeOffset: Double = 0
    static let insertControlIdleOpacity: Double = 0.28
    static let insertControlHoverOpacity: Double = 0.9
    static let selectorWidth: Double = 8
    static let selectorHeight: Double = 8
    static let selectorIndicatorOpacity: Double = 0
    static let selectorHitOpacity: Double = 0.0001
    static let selectorSelectedIndicatorOpacity: Double = 0.38
    static let selectorSelectedIndicatorThickness: Double = 1.5
    static let selectorSelectedIndicatorInset: Double = 10
    static let headerBackgroundToken = EditorDesignTokens.Colors.tableHeaderBackground
}

enum TableBlockDefaultGridResolver {
    static let emptyGridRows = MarkdownTableDocument.defaultEmptyGridRows

    static func editableRows(text: String, rows: [[String]]) -> [[String]] {
        if !rows.isEmpty {
            return rows
        }

        let markdownRows = MarkdownTableDocument(markdown: text).rows
        if !markdownRows.isEmpty {
            return markdownRows
        }

        return MarkdownTableDocument.defaultGridRows(firstCellText: text)
    }
}

enum PastedAttachmentAnchorResolver {
    static func anchorBlockID(
        textSelection: EditorTextSelection?,
        focusedBlockID: String?,
        selectedBlockIDs: Set<String>,
        visibleBlockIDs: [String]
    ) -> String? {
        if let blockID = textSelection?.blockID,
           visibleBlockIDs.contains(blockID) {
            return blockID
        }

        if let focusedBlockID,
           visibleBlockIDs.contains(focusedBlockID) {
            return focusedBlockID
        }

        return visibleBlockIDs.last { selectedBlockIDs.contains($0) }
    }
}

enum IOSEditorKeyboardShortcutAction: Equatable, Sendable {
    case pasteAttachments
    case moveFocus(BlockKeyboardFocusDirection)
}

enum IOSEditorKeyboardShortcutActionResolver {
    static let upArrowInput = "\u{F700}"
    static let downArrowInput = "\u{F701}"

    static func action(
        input: String?,
        modifiers: Set<BlockKeyboardShortcutModifier>
    ) -> IOSEditorKeyboardShortcutAction? {
        if CommandVPasteShortcutResolver.requestsAttachmentPaste(
            input: input,
            modifiers: modifiers
        ) {
            return .pasteAttachments
        }

        guard modifiers.isEmpty else {
            return nil
        }

        switch input {
        case upArrowInput:
            return .moveFocus(.previous)
        case downArrowInput:
            return .moveFocus(.next)
        default:
            return nil
        }
    }
}

enum IOSTableBlockKeyboardActionResolver {
    static let deleteBackwardInput = "\u{8}"
    static let deleteForwardInput = "\u{7F}"
    static let escapeInput = "\u{1B}"

    static func action(
        input: String?,
        modifiers: Set<BlockKeyboardShortcutModifier>,
        hasSelection: Bool
    ) -> TableBlockKeyboardAction? {
        guard hasSelection, modifiers.isEmpty else {
            return nil
        }

        switch input {
        case deleteBackwardInput, deleteForwardInput:
            return .deleteSelection
        case escapeInput:
            return .cancelSelection
        case IOSEditorKeyboardShortcutActionResolver.upArrowInput:
            return .moveFocus(.previous)
        case IOSEditorKeyboardShortcutActionResolver.downArrowInput:
            return .moveFocus(.next)
        default:
            return nil
        }
    }
}

enum IOSEditorKeyboardShortcutBridgeActivationResolver {
    static func capturesPaste(
        hasFocusedTextBlock: Bool,
        hasCurrentPage: Bool,
        hasFocusedPageTitle: Bool = false
    ) -> Bool {
        !hasFocusedTextBlock && hasCurrentPage && !hasFocusedPageTitle
    }

    static func capturesFocusMove(hasBlockSelection: Bool) -> Bool {
        hasBlockSelection
    }
}

enum BlockSelectionKeyboardAnchorResolver {
    static func anchorBlockID(
        selectedBlockIDs: Set<String>,
        visibleBlockIDs: [String]
    ) -> String? {
        visibleBlockIDs.last { selectedBlockIDs.contains($0) }
    }
}

enum SelectedBlockMarkdownCopyResolver {
    static func markdown(
        selectedBlockIDs: Set<String>,
        visibleBlocks: [BlockSnapshot],
        attachments: [AttachmentSnapshot]
    ) -> String {
        let selectedBlocks = visibleBlocks.filter { selectedBlockIDs.contains($0.id) }
        return MarkdownTransformer.export(blocks: selectedBlocks, attachments: attachments)
    }
}

enum PageDragPayloadResolver {
    private static let prefix = "editor-page-ids:"

    static func pageIDsForDrag(
        pageID: String,
        selectedPageIDs: Set<String>,
        visiblePageIDs: [String]
    ) -> [String] {
        guard selectedPageIDs.contains(pageID) else {
            return [pageID]
        }

        let orderedSelection = visiblePageIDs.filter { selectedPageIDs.contains($0) }
        return orderedSelection.isEmpty ? [pageID] : orderedSelection
    }

    static func payloadText(pageIDs: [String]) -> String {
        "\(prefix)\(pageIDs.joined(separator: ","))"
    }

    static func pageIDs(from payloads: [String]) -> [String] {
        var pageIDs: [String] = []
        for payload in payloads where payload.hasPrefix(prefix) {
            let rawIDs = payload.dropFirst(prefix.count)
                .split(separator: ",")
                .map(String.init)
            for pageID in rawIDs where !pageID.isEmpty && !pageIDs.contains(pageID) {
                pageIDs.append(pageID)
            }
        }
        return pageIDs
    }
}

enum PageListRowActionTargetResolver {
    static func pageIDs(
        rowPageID: String,
        selectedPageIDs: Set<String>,
        visiblePageIDs: [String]
    ) -> [String] {
        PageDragPayloadResolver.pageIDsForDrag(
            pageID: rowPageID,
            selectedPageIDs: selectedPageIDs,
            visiblePageIDs: visiblePageIDs
        )
    }
}

enum PageListSelectionRangeResolver {
    static func selection(
        anchorPageID: String,
        targetPageID: String,
        visiblePageIDs: [String]
    ) -> [String] {
        guard let anchorIndex = visiblePageIDs.firstIndex(of: anchorPageID),
              let targetIndex = visiblePageIDs.firstIndex(of: targetPageID) else {
            return []
        }

        let lowerBound = min(anchorIndex, targetIndex)
        let upperBound = max(anchorIndex, targetIndex)
        return Array(visiblePageIDs[lowerBound...upperBound])
    }
}

enum PageListSelectAllResolver {
    static func selection(visiblePageIDs: [String]) -> [String] {
        visiblePageIDs
    }
}

enum PageListMarqueeSelectionResolver {
    static func selectedPageIDs(
        selectionRect: CGRect,
        pageFrames: [String: CGRect],
        visiblePageIDs: [String]
    ) -> [String] {
        guard BlockSelectionMarqueeRectResolver.isVisible(selectionRect) else {
            return []
        }

        return visiblePageIDs.filter { pageID in
            guard let frame = pageFrames[pageID] else {
                return false
            }
            return selectionRect.intersects(frame)
        }
    }
}

enum PageListMarqueeStartPolicy {
    static func isAllowed(location: CGPoint, pageFrames: [String: CGRect]) -> Bool {
        !pageFrames.contains { _, frame in
            frame.contains(location)
        }
    }
}

enum PageListKeyboardShortcutAction: Equatable, Sendable {
    case selectAllVisiblePages
    case selectRangeToSelectedPage
    case archiveSelectedPages
}

enum PageListKeyboardShortcutActionResolver {
    static let deleteBackwardKeyCode: UInt16 = 51
    static let deleteForwardKeyCode: UInt16 = 117

    static func action(
        keyCode: UInt16,
        input: String?,
        modifiers: Set<BlockKeyboardShortcutModifier>,
        hasVisiblePages: Bool,
        hasArchiveTargets: Bool,
        isTextEditing: Bool
    ) -> PageListKeyboardShortcutAction? {
        guard hasVisiblePages, !isTextEditing else {
            return nil
        }

        if input?.lowercased() == "a",
           modifiers == [.command] {
            return .selectAllVisiblePages
        }

        if keyCode == BlockKeyboardShortcutResolver.returnKeyCode,
           modifiers == [.shift] {
            return .selectRangeToSelectedPage
        }

        if modifiers.isEmpty,
           hasArchiveTargets,
           keyCode == deleteBackwardKeyCode || keyCode == deleteForwardKeyCode {
            return .archiveSelectedPages
        }

        return nil
    }
}

enum EditorPendingBlockFocusScheduleReason: Equatable, Sendable {
    case pendingValueChanged
    case pageChanged
    case retry
}

enum EditorPendingBlockFocusSchedulePolicy {
    static func shouldSchedule(
        blockID: String?,
        existingRequestBlockID: String?,
        requestID: UUID?,
        reason: EditorPendingBlockFocusScheduleReason
    ) -> Bool {
        guard blockID != nil else {
            return false
        }
        if reason == .pageChanged || reason == .retry {
            return true
        }
        if existingRequestBlockID == blockID,
           requestID == nil {
            return false
        }
        return true
    }
}

enum ArchiveUndoVisibilityPolicy {
    static func isVisible(
        canUndoPageArchive: Bool,
        selectedCollection: WorkspaceCollection
    ) -> Bool {
        guard canUndoPageArchive else {
            return false
        }

        switch selectedCollection {
        case .search, .archive:
            return false
        case .recent, .diary, .allDocuments, .favorites, .encrypted, .tag:
            return true
        }
    }
}

#if os(macOS)
enum PageListModifierKeyState {
    static var isRangeSelectionActive: Bool {
        NSEvent.modifierFlags.contains(.shift)
    }

    static var isToggleSelectionActive: Bool {
        NSEvent.modifierFlags.contains(.command)
    }
}
#endif

enum PageRowIconResolver {
    static func systemName(isEncrypted: Bool) -> String {
        isEncrypted ? "lock.doc" : "doc.text"
    }
}

enum BlockSelectionRangeResolver {
    static func selection(
        anchorBlockID: String,
        targetBlockID: String,
        visibleBlockIDs: [String]
    ) -> [String] {
        guard let anchorIndex = visibleBlockIDs.firstIndex(of: anchorBlockID),
              let targetIndex = visibleBlockIDs.firstIndex(of: targetBlockID) else {
            return []
        }

        let lowerBound = min(anchorIndex, targetIndex)
        let upperBound = max(anchorIndex, targetIndex)
        return Array(visibleBlockIDs[lowerBound...upperBound])
    }

    static func selectionAfterExtending(
        from blockID: String,
        direction: BlockKeyboardFocusDirection,
        currentSelection: Set<String>,
        visibleBlockIDs: [String]
    ) -> [String] {
        let orderedSelection = visibleBlockIDs.filter { currentSelection.contains($0) }
        guard !orderedSelection.isEmpty else {
            guard let currentIndex = visibleBlockIDs.firstIndex(of: blockID) else {
                return []
            }

            let targetIndex: Int
            switch direction {
            case .previous:
                targetIndex = currentIndex - 1
            case .next:
                targetIndex = currentIndex + 1
            }
            guard visibleBlockIDs.indices.contains(targetIndex) else {
                return []
            }
            return selection(
                anchorBlockID: blockID,
                targetBlockID: visibleBlockIDs[targetIndex],
                visibleBlockIDs: visibleBlockIDs
            )
        }

        guard let lowerIndex = visibleBlockIDs.firstIndex(of: orderedSelection[0]),
              let upperIndex = visibleBlockIDs.firstIndex(of: orderedSelection[orderedSelection.count - 1]) else {
            return orderedSelection
        }

        switch direction {
        case .previous:
            let nextLowerIndex = lowerIndex - 1
            guard visibleBlockIDs.indices.contains(nextLowerIndex) else {
                return orderedSelection
            }
            return Array(visibleBlockIDs[nextLowerIndex...upperIndex])
        case .next:
            let nextUpperIndex = upperIndex + 1
            guard visibleBlockIDs.indices.contains(nextUpperIndex) else {
                return orderedSelection
            }
            return Array(visibleBlockIDs[lowerIndex...nextUpperIndex])
        }
    }
}

enum BlockSelectionMarqueeChrome {
    static let fillOpacity: Double = 0.10
    static let strokeOpacity: Double = 0.42
    static let strokeWidth: Double = 1
    static let cornerRadius: Double = 4
    static let minimumVisibleDimension: Double = 2
}

enum BlockSelectionMarqueeRectResolver {
    static func rect(start: CGPoint, current: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
    }

    static func isVisible(_ rect: CGRect) -> Bool {
        rect.width >= BlockSelectionMarqueeChrome.minimumVisibleDimension
            && rect.height >= BlockSelectionMarqueeChrome.minimumVisibleDimension
    }
}

enum BlockSelectionMarqueeSelectionResolver {
    static func selectedBlockIDs(
        selectionRect: CGRect,
        blockFrames: [String: CGRect],
        visibleBlockIDs: [String]
    ) -> [String] {
        guard BlockSelectionMarqueeRectResolver.isVisible(selectionRect) else {
            return []
        }

        return visibleBlockIDs.filter { blockID in
            guard let frame = blockFrames[blockID] else {
                return false
            }
            return selectionRect.intersects(frame)
        }
    }
}

enum BlockSelectionMarqueeStartPolicy {
    static func isAllowed(
        location: CGPoint,
        blockFrames: [String: CGRect],
        blockedInteractionFrames: [CGRect],
        actionColumnWidth: CGFloat = CGFloat(EditorBlockChrome.actionColumnWidth)
    ) -> Bool {
        guard !blockedInteractionFrames.contains(where: { $0.contains(location) }) else {
            return false
        }

        return !blockFrames.contains { _, frame in
            let handleFrame = CGRect(
                x: frame.minX,
                y: frame.minY,
                width: actionColumnWidth,
                height: frame.height
            )
            return handleFrame.contains(location)
        }
    }
}

enum BlockSelectionMarqueeInteractionFrameResolver {
    static func blockedFrames(
        blocks: [BlockSnapshot],
        blockFrames: [String: CGRect]
    ) -> [CGRect] {
        blocks.compactMap { block in
            guard block.type == .attachmentImage || block.type == .attachmentVideo else {
                return nil
            }
            return blockFrames[block.id]
        }
    }
}

enum MobileBlockSwipeAction: Equatable, Sendable {
    case indent
    case outdent
    case selectBlock
    case closeOutline
}

enum MobileBlockSwipeActionResolver {
    static let horizontalThreshold: CGFloat = 56
    static let horizontalDominanceRatio: CGFloat = 1.25

    static func action(
        translation: CGSize,
        isEditingBlock: Bool,
        nestingLevel: Int,
        isOutlinePresented: Bool = false
    ) -> MobileBlockSwipeAction? {
        let horizontalDistance = abs(translation.width)
        let verticalDistance = abs(translation.height)
        guard horizontalDistance >= horizontalThreshold,
              horizontalDistance > verticalDistance * horizontalDominanceRatio else {
            return nil
        }

        if isOutlinePresented, translation.width > 0 {
            return .closeOutline
        }

        if isEditingBlock {
            if translation.width > 0 {
                return .indent
            }

            return nestingLevel > 0 ? .outdent : nil
        }

        return .selectBlock
    }
}

enum MobileBlockRowSwipeGestureAttachment: Equatable, Sendable {
    case nativeTextEditorOnly
    case rowHighPriority
}

enum MobileBlockRowSwipeGestureAttachmentResolver {
    static func attachment(usesNativeTextEditor: Bool) -> MobileBlockRowSwipeGestureAttachment {
        usesNativeTextEditor ? .nativeTextEditorOnly : .rowHighPriority
    }
}

enum MobileBlockSelectionReducer {
    static func selectionAfterSelecting(
        blockID: String,
        current: Set<String>
    ) -> Set<String> {
        var nextSelection = current
        if nextSelection.contains(blockID) {
            nextSelection.remove(blockID)
        } else {
            nextSelection.insert(blockID)
        }
        return nextSelection
    }
}

enum MobileBlockTapAction: Equatable, Sendable {
    case focusCursor
    case toggleBlockSelection
}

enum MobileBlockTapActionResolver {
    static func action(isSelectionModeActive: Bool) -> MobileBlockTapAction {
        isSelectionModeActive ? .toggleBlockSelection : .focusCursor
    }
}

enum MobileBlockSelectionDragPolicy {
    static func isEnabled(isSelectionModeActive: Bool) -> Bool {
        isSelectionModeActive
    }
}

enum MobileBlockSelectionBatchResolver {
    static func orderedBlockIDs(
        selectedBlockIDs: Set<String>,
        visibleBlockIDs: [String]
    ) -> [String] {
        visibleBlockIDs.filter { selectedBlockIDs.contains($0) }
    }
}

enum MobileBlockSelectionChromeResolver {
    static func isSelectionControlVisible(isSelectionModeActive: Bool) -> Bool {
        isSelectionModeActive
    }

    static func symbolName(isSelected: Bool) -> String {
        isSelected ? "checkmark.circle.fill" : "circle"
    }
}

#if os(iOS)
private struct MobileKeyboardInputBar: View {
    let isOutlinePresented: Bool
    let selectedBlockType: BlockType
    let canUndo: Bool
    let onPaste: () -> Void
    let onUndo: () -> Void
    let onDismissKeyboard: () -> Void
    let onApplyUnorderedList: () -> Void
    let onApplyOrderedList: () -> Void
    let onShowHeadingPanel: () -> Void
    let onToggleOutline: () -> Void
    let onShowMoreFormatPanel: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(MobileKeyboardToolbarUtilityActionResolver.leadingActions, id: \.self) { action in
                utilityToolbarButton(action)
            }

            ForEach(MobileKeyboardToolbarFormatActionResolver.visibleActions, id: \.self) { action in
                formatToolbarButton(action)
            }

            Spacer(minLength: 0)

            ForEach(MobileKeyboardToolbarTrailingActionResolver.visibleActions, id: \.self) { action in
                trailingToolbarButton(action)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.primary.opacity(0.82))
        .frame(maxWidth: .infinity)
        .frame(height: NativeTextEditorLayout.keyboardToolbarHeight)
        .padding(.horizontal, 18)
        .background(.regularMaterial)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("editor.mobile-keyboard-toolbar")
    }

    @ViewBuilder
    private func trailingToolbarButton(_ action: MobileKeyboardToolbarTrailingAction) -> some View {
        switch action {
        case .outline:
            Button {
                onToggleOutline()
            } label: {
                Image(systemName: "sidebar.right")
                    .font(.system(
                        size: MobileKeyboardToolbarChrome.iconSize,
                        weight: MobileKeyboardToolbarChrome.primaryIconWeight
                    ))
                    .frame(
                        width: MobileKeyboardToolbarChrome.buttonSize,
                        height: MobileKeyboardToolbarChrome.buttonSize
                    )
            }
            .accessibilityLabel(isOutlinePresented ? "关闭右侧栏" : "右侧栏")
            .accessibilityIdentifier("editor.mobile-keyboard.outline")
        case .moreFormat:
            Button {
                onShowMoreFormatPanel()
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "ellipsis")
                    Image(systemName: "chevron.down")
                        .font(.system(
                            size: MobileKeyboardToolbarChrome.chevronSize,
                            weight: MobileKeyboardToolbarChrome.secondaryIconWeight
                        ))
                }
                .font(.system(
                    size: MobileKeyboardToolbarChrome.iconSize,
                    weight: MobileKeyboardToolbarChrome.primaryIconWeight
                ))
                .frame(
                    width: MobileKeyboardToolbarChrome.buttonSize + 8,
                    height: MobileKeyboardToolbarChrome.buttonSize
                )
            }
            .accessibilityLabel("更多格式")
            .accessibilityIdentifier("editor.mobile-keyboard.more-format")
        case .dismissKeyboard:
            toolbarButton(
                systemImage: "keyboard.chevron.compact.down",
                accessibilityLabel: "关闭键盘",
                identifier: "editor.mobile-keyboard.dismiss",
                action: onDismissKeyboard
            )
        }
    }

    private func toolbarButton(
        systemImage: String,
        accessibilityLabel: String,
        identifier: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(
                    size: MobileKeyboardToolbarChrome.iconSize,
                    weight: MobileKeyboardToolbarChrome.primaryIconWeight
                ))
                .frame(
                    width: MobileKeyboardToolbarChrome.buttonSize,
                    height: MobileKeyboardToolbarChrome.buttonSize
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.34)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(identifier)
    }

    @ViewBuilder
    private func utilityToolbarButton(_ action: MobileKeyboardToolbarUtilityAction) -> some View {
        switch action {
        case .copy:
            EmptyView()
        case .paste:
            toolbarButton(
                systemImage: "clipboard",
                accessibilityLabel: "粘贴",
                identifier: "editor.mobile-keyboard.paste",
                action: onPaste
            )
        case .undo:
            toolbarButton(
                systemImage: "arrow.uturn.backward",
                accessibilityLabel: "撤销",
                identifier: "editor.mobile-keyboard.undo",
                isEnabled: canUndo,
                action: onUndo
            )
        case .dismissKeyboard:
            toolbarButton(
                systemImage: "keyboard.chevron.compact.down",
                accessibilityLabel: "关闭键盘",
                identifier: "editor.mobile-keyboard.dismiss",
                action: onDismissKeyboard
            )
        }
    }

    @ViewBuilder
    private func formatToolbarButton(_ action: MobileKeyboardToolbarFormatAction) -> some View {
        switch action {
        case .unorderedList:
            toolbarButton(
                systemImage: "list.bullet",
                accessibilityLabel: "无序列表",
                identifier: "editor.mobile-keyboard.unordered-list",
                isSelected: selectedBlockType == .unorderedListItem,
                action: onApplyUnorderedList
            )
        case .orderedList:
            toolbarButton(
                systemImage: "list.number",
                accessibilityLabel: "有序列表",
                identifier: "editor.mobile-keyboard.ordered-list",
                isSelected: selectedBlockType == .orderedListItem,
                action: onApplyOrderedList
            )
        case .heading:
            textToolbarButton(
                title: "H",
                accessibilityLabel: "标题",
                identifier: "editor.mobile-keyboard.heading",
                isSelected: selectedBlockType.isHeading,
                action: onShowHeadingPanel
            )
        }
    }

    private func toolbarButton(
        systemImage: String,
        accessibilityLabel: String,
        identifier: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        toolbarButton(
            systemImage: systemImage,
            accessibilityLabel: accessibilityLabel,
            identifier: identifier,
            action: action
        )
        .background(toolbarSelectionBackground(isSelected: isSelected))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func textToolbarButton(
        title: String,
        accessibilityLabel: String,
        identifier: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .frame(
                    width: MobileKeyboardToolbarChrome.buttonSize,
                    height: MobileKeyboardToolbarChrome.buttonSize
                )
        }
        .buttonStyle(.plain)
        .background(toolbarSelectionBackground(isSelected: isSelected))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(identifier)
    }

    private func toolbarSelectionBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(isSelected ? MobileActionChrome.accentColor.opacity(MobileActionChrome.selectedButtonFillOpacity) : Color.clear)
    }
}

private struct MobileFormatPalette: View {
    let selectedBlockType: BlockType
    let canIndent: Bool
    let canOutdent: Bool
    let canApplyInlineFormat: Bool
    let onChangeType: (BlockType) -> Void
    let onIndent: () -> Void
    let onOutdent: () -> Void
    let onApplyInlineFormat: (MarkdownInlineFormat) -> Void
    let onInsertLink: () -> Void
    let onReturnToKeyboard: () -> Void
    let onDismissKeyboard: () -> Void
    @GestureState private var pullDownOffset: CGFloat = 0

    var body: some View {
        let settledOffset = min(pullDownOffset, 82)

        VStack(spacing: 0) {
            controls

            Spacer(minLength: 0)
        }
        .padding(.horizontal, MobileFormatPaletteChrome.horizontalPadding)
        .padding(.vertical, MobileFormatPaletteChrome.verticalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.regularMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: MobileFormatPaletteChrome.cardCornerRadius, style: .continuous)
                .stroke(EditorDesignTokens.Colors.border.color.opacity(0.74), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: MobileFormatPaletteChrome.cardCornerRadius, style: .continuous))
        .shadow(color: EditorDesignTokens.Colors.shadow.color.opacity(0.14), radius: 22, x: 0, y: 8)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .offset(y: settledOffset)
        .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.92), value: pullDownOffset)
        .gesture(pullDownCollapseGesture)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("editor.mobile-format-palette")
    }

    @ViewBuilder
    private var controls: some View {
        LazyVGrid(columns: formatGridColumns, spacing: MobileFormatPaletteChrome.gridSpacing) {
            ForEach(MobileFormatPaletteActionResolver.visibleActions, id: \.self) { action in
                paletteGridButton(action)
            }
        }
    }

    private var formatGridColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: 44), spacing: MobileFormatPaletteChrome.gridSpacing),
            count: MobileFormatPaletteChrome.columnCount
        )
    }

    private var pullDownCollapseGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .updating($pullDownOffset) { value, state, _ in
                guard value.translation.height > abs(value.translation.width) else {
                    return
                }
                state = max(0, value.translation.height)
            }
            .onEnded { value in
                let shouldCollapse = value.translation.height > 46 ||
                    value.predictedEndTranslation.height > 96
                if shouldCollapse {
                    onReturnToKeyboard()
                }
            }
    }

    private func paletteGridButton(_ action: MobileFormatPaletteAction) -> some View {
        let isEnabled = isActionEnabled(action)
        let isSelected = isActionSelected(action)
        return Button {
            performAction(action)
        } label: {
            Group {
                if let systemImage = action.systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 22, weight: .medium))
                } else {
                    Text(action.accessibilityLabel)
                        .font(.system(size: 20, weight: .semibold))
                }
            }
            .foregroundStyle(isSelected ? MobileActionChrome.accentColor : EditorDesignTokens.Colors.primaryText.color.opacity(isEnabled ? 0.94 : 0.26))
            .frame(maxWidth: .infinity)
            .frame(height: MobileFormatPaletteChrome.buttonHeight)
            .background(paletteButtonBackground(isEnabled: isEnabled, isSelected: isSelected))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(EditorDesignTokens.Colors.border.color.opacity(isEnabled ? 0.52 : 0.20), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(action.accessibilityLabel)
        .accessibilityIdentifier(action.accessibilityIdentifier)
    }

    private func paletteButtonBackground(isEnabled: Bool, isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(
                isSelected
                    ? MobileActionChrome.accentColor.opacity(MobileActionChrome.selectedButtonFillOpacity)
                    : EditorDesignTokens.Colors.elevatedSurface.color.opacity(isEnabled ? 0.78 : 0.34)
            )
    }

    private func isActionSelected(_ action: MobileFormatPaletteAction) -> Bool {
        action.blockType == selectedBlockType
    }

    private func isActionEnabled(_ action: MobileFormatPaletteAction) -> Bool {
        switch action {
        case .outdent:
            return canOutdent
        case .indent:
            return canIndent
        case .bold,
             .italic,
             .strikethrough,
             .inlineCode,
             .insertLink:
            return canApplyInlineFormat
        case .collapsePanel,
             .dismissKeyboard,
             .paragraph,
             .heading1,
             .heading2,
             .heading3,
             .heading4,
             .heading5,
             .heading6,
             .unorderedList,
             .orderedList,
             .task,
             .toggle,
             .quote,
             .codeBlock,
             .table,
             .divider,
             .callout:
            return true
        }
    }

    private func performAction(_ action: MobileFormatPaletteAction) {
        switch action {
        case .collapsePanel:
            onReturnToKeyboard()
        case .dismissKeyboard:
            onDismissKeyboard()
        case .outdent:
            onOutdent()
        case .indent:
            onIndent()
        case .insertLink:
            onInsertLink()
        case .bold,
             .italic,
             .strikethrough,
             .inlineCode:
            guard let inlineFormat = action.inlineFormat else {
                return
            }
            onApplyInlineFormat(inlineFormat)
        case .paragraph,
             .heading1,
             .heading2,
             .heading3,
             .heading4,
             .heading5,
             .heading6,
             .unorderedList,
             .orderedList,
             .task,
             .toggle,
             .quote,
             .codeBlock,
             .table,
             .divider,
             .callout:
            guard let blockType = action.blockType else {
                return
            }
            onChangeType(blockType)
        }
    }

}

private struct MobileBlockSelectionToolbar: View {
    let selectedCount: Int
    let onClear: () -> Void
    let onOutdent: () -> Void
    let onIndent: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("已选择 \(selectedCount) 个")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            Button("取消", action: onClear)
                .font(.subheadline.weight(.medium))
                .buttonStyle(.borderless)
                .foregroundStyle(MobileActionChrome.accentColor)
                .accessibilityIdentifier("editor.mobile-selection-clear")

            Button(action: onOutdent) {
                Image(systemName: "decrease.indent")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(MobileActionChrome.accentColor)
            .accessibilityLabel("减少缩进")
            .accessibilityIdentifier("editor.mobile-selection-outdent")

            Button(action: onIndent) {
                Image(systemName: "increase.indent")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(MobileActionChrome.accentColor)
            .accessibilityLabel("增加缩进")
            .accessibilityIdentifier("editor.mobile-selection-indent")

            Button(role: .destructive, action: onDelete) {
                Label("删除", systemImage: "trash")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("editor.mobile-selection-delete")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .tint(MobileActionChrome.accentColor)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(EditorDesignTokens.Colors.border.color.opacity(0.72))
                .frame(height: 0.5)
        }
        .accessibilityIdentifier("editor.mobile-selection-toolbar")
    }
}
#endif

struct TableSelection: Equatable, Sendable {
    var rows: Set<Int>
    var columns: Set<Int>

    init(rows: Set<Int> = [], columns: Set<Int> = []) {
        self.rows = rows
        self.columns = columns
    }

    static let empty = TableSelection()

    var isEmpty: Bool {
        rows.isEmpty && columns.isEmpty
    }
}

enum TableSelectionReducer {
    static func selectionAfterExternalInteraction(_ selection: TableSelection) -> TableSelection {
        selection.isEmpty ? selection : .empty
    }

    static func selectionAfterSelectingRow(
        _ row: Int,
        current: TableSelection,
        extend: Bool
    ) -> TableSelection {
        var selectedRows = extend ? current.rows : []
        if extend, selectedRows.contains(row) {
            selectedRows.remove(row)
        } else {
            selectedRows.insert(row)
        }
        return TableSelection(rows: selectedRows, columns: [])
    }

    static func selectionAfterSelectingColumn(
        _ column: Int,
        current: TableSelection,
        extend: Bool
    ) -> TableSelection {
        var selectedColumns = extend ? current.columns : []
        if extend, selectedColumns.contains(column) {
            selectedColumns.remove(column)
        } else {
            selectedColumns.insert(column)
        }
        return TableSelection(rows: [], columns: selectedColumns)
    }

    static func rowsAfterDeletingSelection(
        _ selection: TableSelection,
        from rows: [[String]]
    ) -> [[String]] {
        let normalizedRows = normalized(rows)
        let rowsAfterRowDeletion: [[String]]
        if selection.rows.isEmpty {
            rowsAfterRowDeletion = normalizedRows
        } else {
            rowsAfterRowDeletion = normalizedRows.enumerated()
                .filter { index, _ in !selection.rows.contains(index) }
                .map(\.element)
        }

        let survivingRows = rowsAfterRowDeletion.isEmpty ? [[""]] : rowsAfterRowDeletion

        guard !selection.columns.isEmpty else {
            return survivingRows
        }

        let deletedColumns = selection.columns
        let rowsAfterColumnDeletion = survivingRows.map { row in
            let keptCells = row.enumerated()
                .filter { index, _ in !deletedColumns.contains(index) }
                .map(\.element)
            return keptCells.isEmpty ? [""] : keptCells
        }

        return rowsAfterColumnDeletion.isEmpty ? [[""]] : rowsAfterColumnDeletion
    }

    private static func normalized(_ rows: [[String]]) -> [[String]] {
        let sourceRows = rows.isEmpty ? [[""]] : rows
        let columnCount = max(sourceRows.map(\.count).max() ?? 1, 1)
        return sourceRows.map { row in
            if row.count >= columnCount {
                return row
            }
            return row + Array(repeating: "", count: columnCount - row.count)
        }
    }
}

enum BlockDropPlacement: Equatable, Sendable {
    case before
    case after
    case childAfter
    case outdentAfter
}

struct BlockDropTarget: Equatable, Sendable {
    let blockID: String
    let placement: BlockDropPlacement
    let targetLevel: Int?

    init(blockID: String, placement: BlockDropPlacement, targetLevel: Int? = nil) {
        self.blockID = blockID
        self.placement = placement
        self.targetLevel = targetLevel
    }
}

enum BlockDropTargetLifecycleReducer {
    static func targetAfterEditorInteraction(current: BlockDropTarget?) -> BlockDropTarget? {
        nil
    }

    static func targetAfterDragEnded(current: BlockDropTarget?) -> BlockDropTarget? {
        nil
    }
}

struct TransientSelectionResetRequest: Equatable, Sendable {
    let id: UUID
    let excludingBlockID: String?

    static let none = TransientSelectionResetRequest(id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!, excludingBlockID: nil)

    init(id: UUID = UUID(), excludingBlockID: String? = nil) {
        self.id = id
        self.excludingBlockID = excludingBlockID
    }
}

enum BlockDropPlacementResolver {
    static let rootLevelAnchorX: CGFloat = 48
    static let levelIndentWidth: CGFloat = 24
    static let childActivationOffset: CGFloat = 36
    static let beforeBandHeight: CGFloat = 10

    static func resolution(
        location: CGPoint,
        rowSize: CGSize,
        destinationLevel: Int = 0
    ) -> BlockDropPlacementResolution {
        let clampedDestinationLevel = max(0, destinationLevel)
        let topBandHeight = min(beforeBandHeight, max(rowSize.height * 0.35, 8))
        if location.y <= topBandHeight {
            return BlockDropPlacementResolution(placement: .before, targetLevel: clampedDestinationLevel)
        }

        return afterResolution(locationX: location.x, destinationLevel: clampedDestinationLevel)
    }

    static func placement(
        location: CGPoint,
        rowSize: CGSize,
        destinationLevel: Int = 0
    ) -> BlockDropPlacement {
        resolution(location: location, rowSize: rowSize, destinationLevel: destinationLevel).placement
    }

    static func afterResolution(
        locationX: CGFloat,
        destinationLevel: Int
    ) -> BlockDropPlacementResolution {
        let clampedDestinationLevel = max(0, destinationLevel)
        let sameLevelAnchor = rootLevelAnchorX + CGFloat(clampedDestinationLevel) * levelIndentWidth

        let targetLevel: Int
        if locationX >= sameLevelAnchor + childActivationOffset {
            targetLevel = clampedDestinationLevel + 1
        } else {
            let rawLevel = Int(round((locationX - rootLevelAnchorX) / levelIndentWidth))
            targetLevel = min(max(rawLevel, 0), clampedDestinationLevel)
        }

        let placement: BlockDropPlacement
        if targetLevel > clampedDestinationLevel {
            placement = .childAfter
        } else if targetLevel < clampedDestinationLevel {
            placement = .outdentAfter
        } else {
            placement = .after
        }
        return BlockDropPlacementResolution(placement: placement, targetLevel: targetLevel)
    }
}

struct BlockDropPlacementResolution: Equatable, Sendable {
    let placement: BlockDropPlacement
    let targetLevel: Int?
}

enum BlockDropParentResolver {
    static func parentBlockIDForEndDrop() -> String? {
        nil
    }

    static func parentBlockID(
        destinationBlockID: String,
        targetLevel: Int,
        blocks: [BlockSnapshot]
    ) -> String? {
        guard targetLevel > 0 else {
            return nil
        }

        let destinationChain = ancestorChainIncludingDestination(
            destinationBlockID: destinationBlockID,
            blocks: blocks
        )
        guard destinationChain.indices.contains(targetLevel - 1) else {
            return destinationBlockID
        }
        return destinationChain[targetLevel - 1].id
    }

    private static func ancestorChainIncludingDestination(
        destinationBlockID: String,
        blocks: [BlockSnapshot]
    ) -> [BlockSnapshot] {
        let blocksByID = Dictionary(uniqueKeysWithValues: blocks.map { ($0.id, $0) })
        guard var block = blocksByID[destinationBlockID] else {
            return []
        }

        var chain: [BlockSnapshot] = [block]
        var visitedBlockIDs: Set<String> = [block.id]
        while let parentBlockID = block.parentBlockID,
              !visitedBlockIDs.contains(parentBlockID),
              let parent = blocksByID[parentBlockID] {
            chain.insert(parent, at: 0)
            visitedBlockIDs.insert(parentBlockID)
            block = parent
        }
        return chain
    }
}

enum SlashCommandSelectionSource: Equatable, Sendable {
    case keyboard
    case hover
}

enum SlashCommandMenuScrollPolicy {
    static func shouldScrollSelectionIntoView(source: SlashCommandSelectionSource) -> Bool {
        source == .keyboard
    }
}

struct PageListPreview: Equatable, Sendable {
    let excerpt: String?
    let imageAttachment: AttachmentSnapshot?
    let fileAttachment: AttachmentSnapshot?
}

enum PageListPreviewResolver {
    static func preview(
        pageID: String,
        blocks: [BlockSnapshot],
        attachments: [AttachmentSnapshot],
        isEncrypted: Bool = false
    ) -> PageListPreview {
        guard !isEncrypted else {
            return PageListPreview(
                excerpt: nil,
                imageAttachment: nil,
                fileAttachment: nil
            )
        }

        let pageBlocks = blocks.filter { $0.pageID == pageID }
        let excerpt = pageBlocks.first { block in
            block.type == .paragraph
                && !block.textPlain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }?.textPlain.trimmingCharacters(in: .whitespacesAndNewlines)
        let imageAttachment = attachment(
            in: attachments,
            matching: pageBlocks.first { $0.type == .attachmentImage }
        )
        let fileAttachment = attachment(
            in: attachments,
            matching: pageBlocks.first { $0.type == .attachmentFile }
        )

        return PageListPreview(
            excerpt: excerpt,
            imageAttachment: imageAttachment,
            fileAttachment: imageAttachment == nil ? fileAttachment : nil
        )
    }

    private static func attachment(
        in attachments: [AttachmentSnapshot],
        matching block: BlockSnapshot?
    ) -> AttachmentSnapshot? {
        guard let block else {
            return nil
        }
        return attachments.first { $0.matches(block: block) }
    }
}

enum PageReferencePreviewResolver {
    static func previewText(targetPageID: String?, blocks: [BlockSnapshot]) -> String? {
        guard let targetPageID else {
            return nil
        }

        return blocks.first { block in
            block.pageID == targetPageID
                && block.type.isTextEditable
                && !block.textPlain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }?.textPlain.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct EditorCanvasRenderMetrics: Equatable, Sendable {
    let pageID: String?
    let blockCount: Int
    let attachmentCount: Int
    let backlinkCount: Int
    let conflictCount: Int

    var isLargePage: Bool {
        blockCount >= EditorCanvasRenderPolicy.largePageBlockThreshold
    }
}

enum EditorCanvasRenderPolicy {
    static let usesLazyBlockStack = true
    static let largePageBlockThreshold = 750
}

struct EditorCanvasScrollMetrics: Equatable, Sendable {
    let pageID: String?
    let blockCount: Int
    let visibleBlockCount: Int
    let peakVisibleBlockCount: Int
    let firstVisibleBlockIndex: Int?
    let lastVisibleBlockIndex: Int?
    let peakLastVisibleBlockIndex: Int?
    let peakVisibleBlockIndexSpan: Int
    let scrollLifetimeMilliseconds: Double
    let blockAppearanceCount: Int
    let blockDisappearanceCount: Int

    init(
        pageID: String?,
        blockCount: Int,
        visibleBlockCount: Int,
        peakVisibleBlockCount: Int,
        firstVisibleBlockIndex: Int?,
        lastVisibleBlockIndex: Int?,
        peakLastVisibleBlockIndex: Int? = nil,
        peakVisibleBlockIndexSpan: Int,
        scrollLifetimeMilliseconds: Double = 0,
        blockAppearanceCount: Int = 0,
        blockDisappearanceCount: Int = 0
    ) {
        self.pageID = pageID
        self.blockCount = blockCount
        self.visibleBlockCount = visibleBlockCount
        self.peakVisibleBlockCount = peakVisibleBlockCount
        self.firstVisibleBlockIndex = firstVisibleBlockIndex
        self.lastVisibleBlockIndex = lastVisibleBlockIndex
        self.peakLastVisibleBlockIndex = peakLastVisibleBlockIndex
        self.peakVisibleBlockIndexSpan = peakVisibleBlockIndexSpan
        self.scrollLifetimeMilliseconds = scrollLifetimeMilliseconds
        self.blockAppearanceCount = blockAppearanceCount
        self.blockDisappearanceCount = blockDisappearanceCount
    }

    var isLargePage: Bool {
        blockCount >= EditorCanvasRenderPolicy.largePageBlockThreshold
    }

    var visibleBlockChurnCount: Int {
        blockAppearanceCount + blockDisappearanceCount
    }

    var visibleBlockIndexSpan: Int {
        guard let firstVisibleBlockIndex,
              let lastVisibleBlockIndex else {
            return 0
        }
        return lastVisibleBlockIndex - firstVisibleBlockIndex + 1
    }

    var runtimeSummary: String {
        [
            "page_id=\(pageID ?? "none")",
            "block_count=\(blockCount)",
            "visible_block_count=\(visibleBlockCount)",
            "peak_visible_block_count=\(peakVisibleBlockCount)",
            "first_visible_block_index=\(Self.optionalIndexDescription(firstVisibleBlockIndex))",
            "last_visible_block_index=\(Self.optionalIndexDescription(lastVisibleBlockIndex))",
            "peak_last_visible_block_index=\(Self.optionalIndexDescription(peakLastVisibleBlockIndex))",
            "visible_block_index_span=\(visibleBlockIndexSpan)",
            "peak_visible_block_index_span=\(peakVisibleBlockIndexSpan)",
            "scroll_lifetime_ms=\(Self.millisecondsDescription(scrollLifetimeMilliseconds))",
            "block_appearance_count=\(blockAppearanceCount)",
            "block_disappearance_count=\(blockDisappearanceCount)",
            "visible_block_churn_count=\(visibleBlockChurnCount)",
            "large_page=\(isLargePage)"
        ].joined(separator: " ")
    }

    private static func optionalIndexDescription(_ index: Int?) -> String {
        index.map(String.init) ?? "none"
    }

    private static func millisecondsDescription(_ milliseconds: Double) -> String {
        String(format: "%.3f", milliseconds)
    }
}

struct EditorCanvasScrollMetricsTracker: Equatable, Sendable {
    private var pageID: String?
    private var blockCount: Int
    private var visibleBlockIndexesByID: [String: Int] = [:]
    private var peakVisibleBlockCount = 0
    private var peakLastVisibleBlockIndex: Int?
    private var peakVisibleBlockIndexSpan = 0
    private var startedAtNanoseconds: UInt64
    private var lastEventNanoseconds: UInt64
    private var blockAppearanceCount = 0
    private var blockDisappearanceCount = 0

    init(
        pageID: String?,
        blockCount: Int,
        nowNanoseconds: UInt64 = Self.currentNanoseconds()
    ) {
        self.pageID = pageID
        self.blockCount = blockCount
        self.startedAtNanoseconds = nowNanoseconds
        self.lastEventNanoseconds = nowNanoseconds
    }

    var metrics: EditorCanvasScrollMetrics {
        let firstVisibleBlockIndex = visibleBlockIndexesByID.values.min()
        let lastVisibleBlockIndex = visibleBlockIndexesByID.values.max()
        return EditorCanvasScrollMetrics(
            pageID: pageID,
            blockCount: blockCount,
            visibleBlockCount: visibleBlockIndexesByID.count,
            peakVisibleBlockCount: peakVisibleBlockCount,
            firstVisibleBlockIndex: firstVisibleBlockIndex,
            lastVisibleBlockIndex: lastVisibleBlockIndex,
            peakLastVisibleBlockIndex: peakLastVisibleBlockIndex,
            peakVisibleBlockIndexSpan: peakVisibleBlockIndexSpan,
            scrollLifetimeMilliseconds: Self.durationMilliseconds(
                from: startedAtNanoseconds,
                to: lastEventNanoseconds
            ),
            blockAppearanceCount: blockAppearanceCount,
            blockDisappearanceCount: blockDisappearanceCount
        )
    }

    mutating func reset(
        pageID: String?,
        blockCount: Int,
        nowNanoseconds: UInt64 = Self.currentNanoseconds()
    ) {
        self.pageID = pageID
        self.blockCount = blockCount
        visibleBlockIndexesByID.removeAll()
        peakVisibleBlockCount = 0
        peakLastVisibleBlockIndex = nil
        peakVisibleBlockIndexSpan = 0
        startedAtNanoseconds = nowNanoseconds
        lastEventNanoseconds = nowNanoseconds
        blockAppearanceCount = 0
        blockDisappearanceCount = 0
    }

    mutating func blockAppeared(
        _ blockID: String,
        index: Int,
        nowNanoseconds: UInt64 = Self.currentNanoseconds()
    ) {
        if visibleBlockIndexesByID[blockID] == index {
            return
        }

        let wasVisible = visibleBlockIndexesByID[blockID] != nil
        visibleBlockIndexesByID[blockID] = index
        lastEventNanoseconds = nowNanoseconds
        if !wasVisible {
            blockAppearanceCount += 1
        }
        peakVisibleBlockCount = max(peakVisibleBlockCount, visibleBlockIndexesByID.count)
        peakLastVisibleBlockIndex = max(peakLastVisibleBlockIndex ?? index, index)
        peakVisibleBlockIndexSpan = max(peakVisibleBlockIndexSpan, metrics.visibleBlockIndexSpan)
    }

    mutating func blockDisappeared(
        _ blockID: String,
        nowNanoseconds: UInt64 = Self.currentNanoseconds()
    ) {
        guard visibleBlockIndexesByID.removeValue(forKey: blockID) != nil else {
            return
        }
        lastEventNanoseconds = nowNanoseconds
        blockDisappearanceCount += 1
    }

    private static func currentNanoseconds() -> UInt64 {
        DispatchTime.now().uptimeNanoseconds
    }

    private static func durationMilliseconds(from start: UInt64, to end: UInt64) -> Double {
        Double(end - start) / 1_000_000
    }
}

struct CompactLibraryNavigationItem: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let systemImage: String
    let count: Int
    let showsCount: Bool
    let collection: WorkspaceCollection
    let route: CompactRoute
    let identifier: String
}

enum CompactLibraryNavigationModel {
    static func items(snapshot: WorkspaceSnapshot) -> [CompactLibraryNavigationItem] {
        let diaryPageIDs = snapshot.diaryPageIDs
        let allDocumentCount = snapshot.pages.filter { !diaryPageIDs.contains($0.id) }.count
        let encryptedCount = snapshot.pages.filter { $0.isEncrypted && !snapshot.isEmptyDiaryPage($0.id) }.count

        return [
            CompactLibraryNavigationItem(
                id: "all-documents",
                title: "全部文档",
                systemImage: "doc.text",
                count: allDocumentCount,
                showsCount: true,
                collection: .allDocuments,
                route: .collection(.allDocuments),
                identifier: "editor.compact.all-documents"
            ),
            CompactLibraryNavigationItem(
                id: "diary",
                title: "日记",
                systemImage: "square.and.pencil",
                count: snapshot.visibleDiaryPageIDs.count,
                showsCount: true,
                collection: .diary,
                route: .collection(.diary),
                identifier: "editor.compact.diary"
            ),
            CompactLibraryNavigationItem(
                id: "favorites",
                title: "收藏",
                systemImage: "star",
                count: snapshot.favoritePages.filter { !snapshot.isEmptyDiaryPage($0.id) }.count,
                showsCount: true,
                collection: .favorites,
                route: .collection(.favorites),
                identifier: "editor.compact.favorites"
            ),
            CompactLibraryNavigationItem(
                id: "encrypted",
                title: "加密",
                systemImage: "lock.doc",
                count: encryptedCount,
                showsCount: true,
                collection: .encrypted,
                route: .collection(.encrypted),
                identifier: "editor.compact.encrypted"
            ),
            CompactLibraryNavigationItem(
                id: "archive",
                title: "归档",
                systemImage: "archivebox",
                count: snapshot.archivedPages.count,
                showsCount: true,
                collection: .archive,
                route: .collection(.archive),
                identifier: "editor.compact.archive"
            )
        ]
    }
}

struct CompactCollectionPageListItem: Identifiable, Equatable, Sendable {
    let id: String
    let page: PageSummary
    let tagNames: [String]
    let preview: PageListPreview
}

enum CompactCollectionPageListModel {
    static func pages(snapshot: WorkspaceSnapshot, collection: WorkspaceCollection) -> [PageSummary] {
        let diaryPageIDs = snapshot.diaryPageIDs
        let visibleDiaryPageIDs = snapshot.visibleDiaryPageIDs

        switch collection {
        case .recent:
            return snapshot.pages.filter { !snapshot.isEmptyDiaryPage($0.id) }
        case .diary:
            let diaryDatesByPageID = snapshot.diaryDateByPageID
            return snapshot.pages
                .filter { visibleDiaryPageIDs.contains($0.id) }
                .sorted { first, second in
                    (diaryDatesByPageID[first.id] ?? "") > (diaryDatesByPageID[second.id] ?? "")
                }
        case .allDocuments:
            return snapshot.pages.filter { !diaryPageIDs.contains($0.id) }
        case .favorites:
            return snapshot.favoritePages.filter { !snapshot.isEmptyDiaryPage($0.id) }
        case .encrypted:
            return snapshot.pages.filter { $0.isEncrypted && !snapshot.isEmptyDiaryPage($0.id) }
        case .tag(let tagID):
            guard !tagID.isEmpty else {
                return []
            }
            let pageIDs = Set(
                snapshot.pageTags
                    .filter { $0.tagID == tagID }
                    .map(\.pageID)
            )
            return snapshot.pages.filter { pageIDs.contains($0.id) && !snapshot.isEmptyDiaryPage($0.id) }
        case .search:
            return []
        case .archive:
            return snapshot.archivedPages
        }
    }

    static func items(snapshot: WorkspaceSnapshot, collection: WorkspaceCollection) -> [CompactCollectionPageListItem] {
        pages(snapshot: snapshot, collection: collection).map { page in
            CompactCollectionPageListItem(
                id: page.id,
                page: page,
                tagNames: tagNames(for: page, snapshot: snapshot),
                preview: PageListPreviewResolver.preview(
                    pageID: page.id,
                    blocks: snapshot.blocks,
                    attachments: snapshot.attachments,
                    isEncrypted: page.isEncrypted
                )
            )
        }
    }

    private static func tagNames(for page: PageSummary, snapshot: WorkspaceSnapshot) -> [String] {
        let tagIDs = Set(
            snapshot.pageTags
                .filter { $0.pageID == page.id }
                .map(\.tagID)
        )

        return snapshot.tags
            .filter { tagIDs.contains($0.id) }
            .map(\.path)
    }
}

enum CompactRoute: Hashable {
    case pages
    case collection(WorkspaceCollection)
    case page(String)
}

enum CompactShellScreen: Int, Equatable, Sendable {
    case library = 1
    case documentList = 2
    case editor = 3
}

enum CompactShellPendingNavigationPlanner {
    static func onAppearPath(
        snapshot: WorkspaceSnapshot,
        selectedPageID: String?,
        selectedCollection: WorkspaceCollection,
        pendingCollection: WorkspaceCollection?,
        pendingPageID: String?,
        didPushInitialPage: Bool
    ) -> [CompactRoute] {
        if let pendingCollection {
            return [CompactShellRoutePlanner.documentListRoute(selectedCollection: pendingCollection)]
        }

        if let pendingPageID,
           snapshot.pages.contains(where: { $0.id == pendingPageID }) {
            return CompactShellRoutePlanner.pathForPage(
                pendingPageID,
                snapshot: snapshot,
                selectedCollection: selectedCollection
            )
        }

        guard !didPushInitialPage else {
            return []
        }

        return CompactShellRoutePlanner.initialPath(
            snapshot: snapshot,
            selectedPageID: selectedPageID,
            selectedCollection: selectedCollection
        )
    }
}

enum CompactShellRoutePlanner {
    static let defaultActiveScreen = CompactShellScreen.editor

    static func initialPath(
        snapshot: WorkspaceSnapshot,
        selectedCollection: WorkspaceCollection
    ) -> [CompactRoute] {
        initialPath(
            snapshot: snapshot,
            selectedPageID: snapshot.selectedPageID,
            selectedCollection: selectedCollection
        )
    }

    static func initialPath(
        snapshot: WorkspaceSnapshot,
        selectedPageID: String?,
        selectedCollection: WorkspaceCollection
    ) -> [CompactRoute] {
        guard let pageID = CompactInitialNavigationResolver.initialPageID(
            selectedPageID: selectedPageID,
            availablePageIDs: snapshot.pages.map(\.id)
        ) else {
            return []
        }

        return pathForPage(
            pageID,
            snapshot: snapshot,
            selectedCollection: selectedCollection
        )
    }

    static func pathForPage(
        _ pageID: String,
        snapshot: WorkspaceSnapshot,
        selectedCollection: WorkspaceCollection
    ) -> [CompactRoute] {
        [
            documentListRoute(
                selectedCollection: collectionForPage(
                    pageID,
                    snapshot: snapshot,
                    selectedCollection: selectedCollection
                )
            ),
            .page(pageID)
        ]
    }

    static func documentListRoute(selectedCollection: WorkspaceCollection) -> CompactRoute {
        .collection(documentListCollection(selectedCollection: selectedCollection))
    }

    static func documentListCollection(selectedCollection: WorkspaceCollection) -> WorkspaceCollection {
        switch selectedCollection {
        case .recent, .search:
            return .allDocuments
        default:
            return selectedCollection
        }
    }

    static func previousScreenPath(currentPath: [CompactRoute]) -> [CompactRoute] {
        guard !currentPath.isEmpty else {
            return []
        }
        return Array(currentPath.dropLast())
    }

    static func nextScreenPath(
        currentPath: [CompactRoute],
        snapshot: WorkspaceSnapshot,
        selectedCollection: WorkspaceCollection
    ) -> [CompactRoute] {
        if currentPath.isEmpty {
            return [documentListRoute(selectedCollection: selectedCollection)]
        }

        guard currentPath.count == 1 else {
            return currentPath
        }

        let collection: WorkspaceCollection
        if case .collection(let routeCollection) = currentPath[0] {
            collection = routeCollection
        } else {
            collection = selectedCollection
        }

        let pageID = CompactInitialNavigationResolver.initialPageID(
            selectedPageID: snapshot.selectedPageID,
            availablePageIDs: CompactCollectionPageListModel.pages(
                snapshot: snapshot,
                collection: collection
            ).map(\.id)
        )

        guard let pageID else {
            return currentPath
        }

        return currentPath + [.page(pageID)]
    }

    private static func collectionForPage(
        _ pageID: String,
        snapshot: WorkspaceSnapshot,
        selectedCollection: WorkspaceCollection
    ) -> WorkspaceCollection {
        let selectedCollectionPages = CompactCollectionPageListModel.pages(
            snapshot: snapshot,
            collection: selectedCollection
        )
        if selectedCollection != .recent,
           selectedCollectionPages.contains(where: { $0.id == pageID }) {
            return selectedCollection
        }

        if snapshot.diaryPageIDs.contains(pageID) {
            return .diary
        }

        return .allDocuments
    }
}

enum CompactInitialNavigationResolver {
    static func initialPageID(
        selectedPageID: String?,
        availablePageIDs: [String]
    ) -> String? {
        CompactPageNavigationResolver.initialPageID(
            selectedPageID: selectedPageID,
            availablePageIDs: availablePageIDs
        )
    }
}

private struct CompactPageDestination: View {
    @ObservedObject var viewModel: WorkspaceViewModel
    let pageID: String
    let onRevealPageList: () -> Void
    @State private var didRequestInitialFocus = false

    var body: some View {
        if let page = viewModel.snapshot.pages.first(where: { $0.id == pageID }) {
            EditorCanvasView(
                page: page,
                pages: viewModel.snapshot.pages,
                blocks: viewModel.editorVisibleBlocks(for: page.id),
                allBlocks: viewModel.snapshot.blocks,
                attachments: viewModel.snapshot.attachments,
                attachmentPreviewGenerationStatuses: viewModel.attachmentPreviewGenerationStatuses,
                markdownImportStatusText: viewModel.markdownImportStatusText,
                backlinks: viewModel.selectedPageBacklinks,
                externalLinks: viewModel.selectedPageExternalLinks,
                conflicts: viewModel.selectedPageConflicts,
                outlineItems: viewModel.selectedPageOutline,
                parentPageLink: viewModel.selectedPageParentLink,
                pageTagNames: viewModel.selectedPageTagNames,
                availableTags: viewModel.snapshot.tags,
                selectedPageTagIDs: viewModel.selectedPageTagIDs,
                pendingFocusBlockID: viewModel.pendingFocusBlockID,
                pendingSearchHighlight: viewModel.pendingSearchHighlight,
                pendingFocusRequestID: viewModel.pendingFocusRequestID,
                pendingPageTitleFocusPageID: viewModel.pendingPageTitleFocusPageID,
                canUndoTextEdit: viewModel.canUndoTextEdit,
                canRedoTextEdit: viewModel.canRedoTextEdit,
                showsAuxiliaryRail: false,
                isEncryptedContentLocked: viewModel.isEncryptedPageLocked(page.id),
                isAuthenticatingEncryptedContent: viewModel.authenticatingEncryptedPageID == page.id,
                onUnlockEncryptedContent: {
                    Task {
                        await viewModel.selectPageForUI(id: page.id)
                    }
                },
                onAddParagraphBlock: {
                    viewModel.addParagraphBlockToCurrentPage()
                },
                onAddPageReference: { targetPageID in
                    viewModel.appendPageReferenceToCurrentPageForUI(targetPageID: targetPageID)
                },
                onAddBlockReference: { targetBlockID in
                    viewModel.appendBlockReferenceToCurrentPageForUI(targetBlockID: targetBlockID)
                },
                onInsertMarkdownLink: { blockID, label, url in
                    viewModel.insertMarkdownLinkForUI(blockID: blockID, label: label, url: url)
                },
                onInsertMarkdownLinkAtSelection: { blockID, label, url, selection in
                    viewModel.insertMarkdownLinkForUI(
                        blockID: blockID,
                        label: label,
                        url: url,
                        selection: selection
                    )
                },
                onRemoveMarkdownLinkAtSelection: { blockID, selection in
                    viewModel.removeMarkdownLinkForUI(blockID: blockID, selection: selection)
                },
                onApplyMarkdownInlineFormat: { blockID, format, selection in
                    viewModel.applyMarkdownInlineFormatForUI(
                        blockID: blockID,
                        format: format,
                        selection: selection
                    )
                },
                onUndoTextEdit: {
                    viewModel.undoLastTextEditForUI()
                },
                onRedoTextEdit: {
                    viewModel.redoLastTextEditForUI()
                },
                onFocusCanvas: {
                    viewModel.focusEditorCanvasForUI()
                },
                onMoveBlock: { blockID, targetIndex in
                    viewModel.moveBlockInCurrentPage(blockID: blockID, toIndex: targetIndex)
                },
                onMoveBlocks: { blockIDs, targetIndex in
                    viewModel.moveBlocksInCurrentPage(blockIDs: blockIDs, toIndex: targetIndex)
                },
                onUpdateBlockParent: { blockID, parentBlockID in
                    viewModel.updateBlockParentForUI(blockID: blockID, parentBlockID: parentBlockID)
                },
                onMoveBlockByKeyboard: { blockID, direction in
                    viewModel.moveBlockByKeyboardForUI(blockID: blockID, direction: direction)
                },
                onInsertBlockAfter: { blockID in
                    viewModel.insertParagraphBlockAfterForUI(blockID: blockID)
                },
                onSplitTextBlockAtSelection: { blockID, selection in
                    viewModel.splitTextBlockAtSelectionForUI(blockID: blockID, selection: selection)
                },
                onReplaceTextAtSelection: { selection, replacementText in
                    viewModel.replaceTextAtSelectionForUI(selection: selection, replacementText: replacementText)
                },
                onPasteTextAtSelection: { selection, pasteText in
                    viewModel.pasteTextAtSelectionForUI(selection: selection, pasteText: pasteText)
                },
                onMergeTextBlockWithPrevious: { blockID, selection in
                    viewModel.mergeTextBlockWithPreviousAtSelectionForUI(blockID: blockID, selection: selection)
                },
                onMergeTextBlockWithNext: { blockID, selection in
                    viewModel.mergeTextBlockWithNextAtSelectionForUI(blockID: blockID, selection: selection)
                },
                onIndentBlock: { blockID in
                    viewModel.indentBlockForUI(blockID: blockID)
                },
                onOutdentBlock: { blockID in
                    viewModel.outdentBlockForUI(blockID: blockID)
                },
                onDeleteBlock: { blockID in
                    viewModel.deleteBlockFromCurrentPage(blockID: blockID)
                },
                onDeleteBlocks: { blockIDs in
                    viewModel.deleteBlocksFromCurrentPage(blockIDs: blockIDs)
                },
                onSelectBacklink: { backlink in
                    viewModel.selectBacklink(backlink)
                },
                onSelectOutlineItem: { item in
                    viewModel.selectOutlineItem(item)
                },
                onOpenPageReference: { targetPageID in
                    viewModel.openPageReference(targetPageID: targetPageID)
                },
                onOpenParentPage: {
                    viewModel.openParentPageForCurrentPageForUI()
                },
                onOpenBlockReference: { targetPageID, targetBlockID in
                    viewModel.openBlockReference(targetPageID: targetPageID, targetBlockID: targetBlockID)
                },
                onAcceptConflict: { conflict in
                    viewModel.acceptRemoteConflictForUI(id: conflict.id)
                },
                onAcceptAllConflicts: {
                    viewModel.acceptAllRemoteConflictsForSelectedPageForUI()
                },
                onAcceptLocalConflict: { conflict in
                    viewModel.acceptLocalConflictForUI(id: conflict.id)
                },
                onAcceptAllLocalConflicts: {
                    viewModel.acceptAllLocalConflictsForSelectedPageForUI()
                },
                onResolveConflictManually: { conflict, text in
                    viewModel.resolveConflictManuallyForUI(id: conflict.id, text: text)
                },
                onResolveAllConflictsManually: { mergedTextsByConflictID in
                    viewModel.resolveAllManualConflictsForSelectedPageForUI(
                        mergedTextsByConflictID: mergedTextsByConflictID
                    )
                },
                onPageTitleChange: { title in
                    viewModel.editSelectedPageTitle(title)
                },
                onImportMarkdown: { sourceURL in
                    viewModel.importMarkdownFileForCurrentPage(sourceURL: sourceURL)
                },
                onImportObsidianVault: { sourceURL in
                    viewModel.importObsidianVaultForCurrentWorkspace(sourceURL: sourceURL)
                },
                onExportMarkdown: {
                    viewModel.exportCurrentPageMarkdown()
                },
                onExportMarkdownPackage: { destinationURL in
                    viewModel.exportCurrentPageMarkdownPackageForUI(to: destinationURL)
                },
                onBlockTextChange: { blockID, text in
                    viewModel.editBlockText(blockID: blockID, text: text)
                },
                onTableRowsChange: { blockID, rows in
                    viewModel.updateTableRowsForUI(blockID: blockID, rows: rows)
                },
                onBlockTypeChange: { blockID, type in
                    viewModel.changeBlockTypeForUI(blockID: blockID, type: type)
                },
                onConvertBlockToPage: { blockID in
                    viewModel.convertTextBlockToPageForUI(blockID: blockID)
                },
                onTaskItemCompletionChange: { blockID, isCompleted in
                    viewModel.updateTaskItemCompletionForUI(
                        blockID: blockID,
                        isCompleted: isCompleted
                    )
                },
                onCodeBlockLineWrappingChange: { blockID, isWrapped in
                    viewModel.updateCodeBlockLineWrapping(blockID: blockID, isWrapped: isWrapped)
                },
                onToggleBlockExpansion: { blockID in
                    viewModel.toggleBlockExpansion(blockID: blockID)
                },
                isToggleBlockExpanded: { blockID in
                    viewModel.isToggleBlockExpanded(blockID: blockID)
                },
                onImportAttachment: { sourceURL in
                    viewModel.importAttachmentForCurrentPage(sourceURL: sourceURL)
                },
                onImportAttachmentsAfterBlock: { sourceURLs, blockID in
                    viewModel.importAttachmentsForCurrentPage(
                        sourceURLs: sourceURLs,
                        afterBlockID: blockID
                    )
                },
                onRetryAttachmentPreview: { attachmentID in
                    viewModel.retryAttachmentPreviewGeneration(attachmentID: attachmentID)
                },
                onRenameAttachmentImage: { blockID, name in
                    viewModel.renameAttachmentImageForUI(blockID: blockID, name: name)
                },
                onAttachmentImageDisplayWidthChange: { blockID, displayWidth in
                    viewModel.updateAttachmentImageDisplayWidthForUI(
                        blockID: blockID,
                        displayWidth: displayWidth
                    )
                },
                onDrawingBlockDataChange: { blockID, data in
                    viewModel.updateDrawingBlockForUI(blockID: blockID, data: data)
                },
                onMobileRevealPageList: onRevealPageList,
                onPendingBlockFocusHandled: {
                    _ = viewModel.consumePendingFocusBlockID()
                },
                onPendingPageTitleFocusHandled: {
                    _ = viewModel.consumePendingPageTitleFocusPageID()
                },
                onRemoveTagFromSelectedPage: { tagID in
                    viewModel.removeTagFromSelectedPageForUI(tagID: tagID)
                },
                onCreateAndAssignTagToSelectedPage: { name in
                    viewModel.createAndAssignTagToSelectedPageForUI(name: name)
                }
            )
            .onAppear {
                if viewModel.pendingPageTitleFocusPageID == page.id {
                    didRequestInitialFocus = true
                }
                Task {
                    await viewModel.selectPageForUI(id: page.id)
                    guard viewModel.selectedPageID == page.id,
                          !viewModel.isEncryptedPageLocked(page.id) else {
                        return
                    }
                    requestInitialFocusIfNeeded()
                }
            }
        } else {
            EditorDesignTokens.Colors.editorBackground.color
                .navigationTitle("编辑器")
        }
    }

    private func requestInitialFocusIfNeeded() {
        guard !didRequestInitialFocus else {
            return
        }
        didRequestInitialFocus = true
        _ = viewModel.focusEditorCanvasForUI()
    }
}

struct SidebarNavigationItem: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let systemImage: String
    let count: Int
    let showsCount: Bool
    let collection: WorkspaceCollection
    let identifier: String
    let isSelected: Bool
    let nestingLevel: Int

    init(
        id: String,
        title: String,
        systemImage: String,
        count: Int,
        showsCount: Bool = true,
        collection: WorkspaceCollection,
        identifier: String,
        isSelected: Bool,
        nestingLevel: Int = 0
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.count = count
        self.showsCount = showsCount
        self.collection = collection
        self.identifier = identifier
        self.isSelected = isSelected
        self.nestingLevel = nestingLevel
    }
}

struct SidebarNavigationModel: Equatable, Sendable {
    let primaryItems: [SidebarNavigationItem]
    let tagItems: [SidebarNavigationItem]
    let utilityItems: [SidebarNavigationItem]

    init(snapshot: WorkspaceSnapshot, selectedCollection: WorkspaceCollection) {
        let diaryPageIDs = snapshot.diaryPageIDs
        let allDocumentCount = snapshot.pages.filter { !diaryPageIDs.contains($0.id) }.count
        let encryptedCount = snapshot.pages.filter { $0.isEncrypted && !snapshot.isEmptyDiaryPage($0.id) }.count
        let tagCounts = Dictionary(
            grouping: snapshot.pageTags,
            by: \.tagID
        )
        .mapValues { assignments in
            Set(assignments.map(\.pageID))
        }
        let tagDescendants = Self.descendantTagIDsByTagID(tags: snapshot.tags)

        primaryItems = [
            SidebarNavigationItem(
                id: "all-documents",
                title: "全部文档",
                systemImage: "doc.text",
                count: allDocumentCount,
                collection: .allDocuments,
                identifier: "editor.collection.all-documents",
                isSelected: selectedCollection == .allDocuments
            ),
            SidebarNavigationItem(
                id: "diary",
                title: "日记",
                systemImage: "square.and.pencil",
                count: snapshot.visibleDiaryPageIDs.count,
                collection: .diary,
                identifier: "editor.collection.diary",
                isSelected: selectedCollection == .diary
            ),
            SidebarNavigationItem(
                id: "encrypted",
                title: "加密",
                systemImage: "lock.doc",
                count: encryptedCount,
                collection: .encrypted,
                identifier: "editor.collection.encrypted",
                isSelected: selectedCollection == .encrypted
            )
        ]

        tagItems = Self.hierarchicalTags(snapshot.tags).map { pair in
            let tag = pair.0
            let nestingLevel = pair.1
            let visibleTagIDs = [tag.id] + (tagDescendants[tag.id] ?? [])
            let visiblePageIDs = visibleTagIDs.reduce(into: Set<String>()) { pageIDs, tagID in
                pageIDs.formUnion(tagCounts[tagID] ?? [])
            }.subtracting(snapshot.emptyDiaryPageIDs)
            return SidebarNavigationItem(
                id: "tag-\(tag.id)",
                title: tag.name,
                systemImage: "tag",
                count: visiblePageIDs.count,
                collection: .tag(tag.id),
                identifier: "editor.collection.tag.\(tag.id)",
                isSelected: selectedCollection == .tag(tag.id),
                nestingLevel: nestingLevel
            )
        }

        utilityItems = [
            SidebarNavigationItem(
                id: "archive",
                title: "归档",
                systemImage: "archivebox",
                count: snapshot.archivedPages.count,
                showsCount: snapshot.archivedPages.count > 0,
                collection: .archive,
                identifier: "editor.collection.archive",
                isSelected: selectedCollection == .archive
            )
        ]
    }

    private static func hierarchicalTags(_ tags: [TagSummary]) -> [(TagSummary, Int)] {
        let childrenByParentID = Dictionary(grouping: tags) { tag in
            tag.parentTagID ?? ""
        }

        func sortedChildren(parentTagID: String?) -> [TagSummary] {
            let key = parentTagID ?? ""
            return (childrenByParentID[key] ?? []).sorted { left, right in
                left.path.localizedStandardCompare(right.path) == .orderedAscending
            }
        }

        func appendChildren(parentTagID: String?, level: Int, into result: inout [(TagSummary, Int)]) {
            for tag in sortedChildren(parentTagID: parentTagID) {
                result.append((tag, level))
                appendChildren(parentTagID: tag.id, level: level + 1, into: &result)
            }
        }

        var result: [(TagSummary, Int)] = []
        appendChildren(parentTagID: nil, level: 0, into: &result)
        return result
    }

    private static func descendantTagIDsByTagID(tags: [TagSummary]) -> [String: [String]] {
        let childrenByParentID = Dictionary(grouping: tags) { tag in
            tag.parentTagID ?? ""
        }

        func descendants(of tagID: String) -> [String] {
            let children = childrenByParentID[tagID] ?? []
            return children.flatMap { child in
                [child.id] + descendants(of: child.id)
            }
        }

        return Dictionary(uniqueKeysWithValues: tags.map { tag in
            (tag.id, descendants(of: tag.id))
        })
    }
}

enum SidebarChrome {
    static let horizontalPadding: Double = 8
    static let verticalPadding: Double = 10
    static let macTitlebarTopCompensation: Double = 44
    static let sectionSpacing: Double = 6
    static let rowSpacing: Double = 1
    static let rowCornerRadius: Double = 12
    static let rowVerticalPadding: Double = 6
    static let nestedItemIndent: Double = 12
    static let dividerOpacity: Double = 0.05
    static let selectedFillOpacity: Double = 0.44
    static let selectedStrokeOpacity: Double = 0.025
    static let headerBadgeSize: Double = 30
    static let headerBadgeCornerRadius: Double = 8
    static let backgroundToken = EditorDesignTokens.Colors.sidebarBackground
    static let selectedFillToken = EditorDesignTokens.Colors.border
    static let backgroundRed: Double = backgroundToken.red
    static let backgroundGreen: Double = backgroundToken.green
    static let backgroundBlue: Double = backgroundToken.blue
    static let selectedFillRed: Double = selectedFillToken.red
    static let selectedFillGreen: Double = selectedFillToken.green
    static let selectedFillBlue: Double = selectedFillToken.blue

    static var backgroundYellowBias: Double {
        max(0, ((backgroundRed + backgroundGreen) / 2) - backgroundBlue)
    }

    static var selectedFillYellowBias: Double {
        max(0, ((selectedFillRed + selectedFillGreen) / 2) - selectedFillBlue)
    }

    static var backgroundColor: Color {
        backgroundToken.color
    }

    static var selectedFillColor: Color {
        selectedFillToken.color
    }

    static var selectedForegroundColor: Color {
        EditorDesignTokens.Colors.primaryText.color
    }

    static var foregroundColor: Color {
        EditorDesignTokens.Colors.secondaryText.color
    }

    static var mutedForegroundColor: Color {
        EditorDesignTokens.Colors.tertiaryText.color
    }
}

enum SidebarDropTargetChromePolicy {
    static func fillOpacity(isSelected: Bool, isDropTargeted: Bool) -> Double {
        if isSelected {
            return SidebarChrome.selectedFillOpacity + (isDropTargeted ? 0.16 : 0)
        }
        return isDropTargeted ? 0.34 : 0
    }

    static func strokeOpacity(isSelected: Bool, isDropTargeted: Bool) -> Double {
        if isSelected {
            return SidebarChrome.selectedStrokeOpacity + (isDropTargeted ? 0.16 : 0)
        }
        return isDropTargeted ? 0.22 : 0
    }
}

enum SidebarTagSectionExpansionPolicy {
    static let appStorageKey = "editor.sidebar.tags.expanded.v2"
    static let defaultIsExpanded = false

    static func shouldAutoExpand(selectedPageTagIDs: [String]) -> Bool {
        !selectedPageTagIDs.isEmpty
    }
}

enum SidebarTagHighlightPolicy {
    static func isHighlighted(item: SidebarNavigationItem, selectedPageTagIDs: [String]) -> Bool {
        guard case .tag(let tagID) = item.collection else {
            return false
        }
        return selectedPageTagIDs.contains(tagID)
    }
}

private struct WorkspaceSidebar: View {
    @ObservedObject var viewModel: WorkspaceViewModel
    @Binding var activePageDragIDs: Set<String>
    @AppStorage(SidebarTagSectionExpansionPolicy.appStorageKey) private var isTagsExpanded = SidebarTagSectionExpansionPolicy.defaultIsExpanded

    var body: some View {
        let model = sidebarModel

        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: CGFloat(SidebarChrome.sectionSpacing)) {
                newDocumentButton
                sidebarDivider
                sidebarGroup(items: model.primaryItems)
                tagGroup(model: model)
                sidebarDivider
                sidebarGroup(items: model.utilityItems) { item, pageIDs in
                    defer { activePageDragIDs = [] }
                    guard case .archive = item.collection else {
                        return false
                    }
                    return viewModel.archivePagesForUI(pageIDs: pageIDs)
                }
            }
            .padding(.horizontal, CGFloat(SidebarChrome.horizontalPadding))
            .padding(.vertical, CGFloat(SidebarChrome.verticalPadding))
#if os(macOS)
            .padding(.top, CGFloat(SidebarChrome.macTitlebarTopCompensation))
#endif
        }
#if os(macOS)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(SidebarChrome.backgroundColor.ignoresSafeArea(edges: .top))
#else
        .navigationTitle("编辑器")
        .background(SidebarChrome.backgroundColor)
#endif
        .navigationSplitViewColumnWidth(CGFloat(EditorDesignTokens.Layout.sidebarIdealWidth))
        .onAppear {
            expandTagsForSelectedPageIfNeeded(selectedPageTagIDs: viewModel.selectedPageTagIDs)
        }
        .onChange(of: viewModel.selectedPageTagIDs) { _, selectedPageTagIDs in
            expandTagsForSelectedPageIfNeeded(selectedPageTagIDs: selectedPageTagIDs)
        }
    }

    private var sidebarModel: SidebarNavigationModel {
        SidebarNavigationModel(
            snapshot: viewModel.snapshot,
            selectedCollection: viewModel.selectedCollection
        )
    }

    private var newDocumentButton: some View {
        Button {
            _ = viewModel.createNewDocumentForUI()
        } label: {
            HStack(spacing: 11) {
                Image(systemName: "doc.badge.plus")
                    .font(.body.weight(.medium))
                    .frame(width: 22)
                    .foregroundStyle(SidebarChrome.mutedForegroundColor)
                Text("新建文档")
                    .font(.body.weight(.medium))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, CGFloat(SidebarChrome.rowVerticalPadding))
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(SidebarChrome.foregroundColor)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("editor.sidebar.new-document")
    }

    private func sidebarGroup(
        items: [SidebarNavigationItem],
        onDropPages: ((SidebarNavigationItem, [String]) -> Bool)? = nil
    ) -> some View {
        VStack(spacing: CGFloat(SidebarChrome.rowSpacing)) {
            ForEach(items) { item in
                CollectionRailButton(
                    item: item,
                    onDropPageIDs: onDropPages.map { handler in
                        { pageIDs in handler(item, pageIDs) }
                    }
                ) {
                    viewModel.selectCollection(item.collection)
                }
            }
        }
    }

    private var sidebarDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(SidebarChrome.dividerOpacity))
            .frame(height: 1)
            .padding(.horizontal, 8)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func tagGroup(model: SidebarNavigationModel) -> some View {
        if !model.tagItems.isEmpty {
            VStack(alignment: .leading, spacing: CGFloat(SidebarChrome.rowSpacing)) {
                SidebarDisclosureHeader(
                    title: "标签",
                    count: model.tagItems.count,
                    isExpanded: isTagsExpanded
                ) {
                    isTagsExpanded.toggle()
                }

                if isTagsExpanded {
                    ForEach(model.tagItems) { item in
                        CollectionRailButton(
                            item: item,
                            isRelatedToSelectedPage: SidebarTagHighlightPolicy.isHighlighted(
                                item: item,
                                selectedPageTagIDs: viewModel.selectedPageTagIDs
                            ),
                            onDropPageIDs: { pageIDs in
                                defer { activePageDragIDs = [] }
                                guard case .tag(let tagID) = item.collection else {
                                    return false
                                }
                                return viewModel.assignTagToPagesForUI(pageIDs: pageIDs, tagID: tagID)
                            }
                        ) {
                            viewModel.selectCollection(item.collection)
                        }
                        .contextMenu {
                            if case .tag(let tagID) = item.collection {
                                Button(role: .destructive) {
                                    _ = viewModel.deleteTagForUI(id: tagID)
                                } label: {
                                    Label("删除标签", systemImage: "trash")
                                }
                            }
                        }
                        .padding(
                            .leading,
                            CGFloat(SidebarChrome.nestedItemIndent * Double(item.nestingLevel))
                        )
                    }
                }
            }
        }
    }

    private var isTagsSelected: Bool {
        if case .tag = viewModel.selectedCollection {
            return true
        }
        return false
    }

    private func expandTagsForSelectedPageIfNeeded(selectedPageTagIDs: [String]) {
        if SidebarTagSectionExpansionPolicy.shouldAutoExpand(selectedPageTagIDs: selectedPageTagIDs) {
            isTagsExpanded = true
        }
    }
}

private struct SidebarDisclosureHeader: View {
    let title: String
    let count: Int
    let isExpanded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption.weight(.semibold))
                    .frame(width: 12)
                Text(title)
                    .font(.caption.weight(.semibold))
                Spacer(minLength: 4)
                Text("\(count)")
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
            }
            .foregroundStyle(SidebarChrome.mutedForegroundColor.opacity(0.82))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title)，\(isExpanded ? "已展开" : "已收起")")
    }
}

private struct CollectionRailButton: View {
    let item: SidebarNavigationItem
    var isRelatedToSelectedPage = false
    var onDropPageIDs: (([String]) -> Bool)? = nil
    let action: () -> Void
    @State private var isDropTargeted = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: item.systemImage)
                    .font(.callout.weight(.medium))
                    .frame(width: 20)
                    .foregroundStyle(iconColor)
                Text(item.title)
                    .font(item.isSelected || isRelatedToSelectedPage ? .callout.weight(.semibold) : .callout.weight(.medium))
                    .lineLimit(1)
                Spacer(minLength: 6)
                if item.showsCount {
                    Text("\(item.count)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(countColor)
                        .monospacedDigit()
                }
            }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, CGFloat(SidebarChrome.rowVerticalPadding))
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: CGFloat(SidebarChrome.rowCornerRadius), style: .continuous)
                        .fill(backgroundColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CGFloat(SidebarChrome.rowCornerRadius), style: .continuous)
                        .stroke(
                            EditorDesignTokens.Colors.border.color.opacity(
                                SidebarDropTargetChromePolicy.strokeOpacity(
                                    isSelected: item.isSelected,
                                    isDropTargeted: isDropTargeted
                                )
                            ),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(foregroundColor)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier(item.identifier)
        .accessibilityValue(accessibilityValue)
        .dropDestination(for: String.self) { payloads, _ in
            guard let onDropPageIDs else {
                return false
            }
            let pageIDs = PageDragPayloadResolver.pageIDs(from: payloads)
            guard !pageIDs.isEmpty else {
                return false
            }
            return onDropPageIDs(pageIDs)
        } isTargeted: { isTargeted in
            isDropTargeted = isTargeted && onDropPageIDs != nil
        }
    }

    private var foregroundColor: Color {
        if item.isSelected {
            return SidebarChrome.selectedForegroundColor
        }
        if isRelatedToSelectedPage {
            return EditorDesignTokens.Colors.accent.color
        }
        return SidebarChrome.foregroundColor
    }

    private var iconColor: Color {
        if item.isSelected {
            return SidebarChrome.selectedForegroundColor
        }
        if isRelatedToSelectedPage {
            return EditorDesignTokens.Colors.accent.color.opacity(0.86)
        }
        return SidebarChrome.mutedForegroundColor
    }

    private var countColor: Color {
        if item.isSelected {
            return SidebarChrome.selectedForegroundColor.opacity(0.80)
        }
        if isRelatedToSelectedPage {
            return EditorDesignTokens.Colors.accent.color.opacity(0.72)
        }
        return SidebarChrome.mutedForegroundColor
    }

    private var backgroundColor: Color {
        let selectedOpacity = SidebarDropTargetChromePolicy.fillOpacity(
            isSelected: item.isSelected,
            isDropTargeted: isDropTargeted
        )
        if selectedOpacity > 0 {
            return SidebarChrome.selectedFillColor.opacity(selectedOpacity)
        }
        if isRelatedToSelectedPage {
            return EditorDesignTokens.Colors.accent.color.opacity(0.10)
        }
        return Color.clear
    }

    private var accessibilityValue: String {
        if item.isSelected {
            return "已选中，\(item.count)"
        }
        if isRelatedToSelectedPage {
            return "当前笔记标签，\(item.count)"
        }
        return "未选中，\(item.count)"
    }
}

struct PageListDateSection: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let pages: [PageSummary]
}

enum PageListDateSectionModel {
    static func sections(
        pages: [PageSummary],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [PageListDateSection] {
        var sections: [PageListDateSection] = []

        for page in pages {
            let title = sectionTitle(
                for: parseDate(page.updatedAt),
                now: now,
                calendar: calendar
            )

            if let last = sections.last, last.title == title {
                sections[sections.count - 1] = PageListDateSection(
                    id: last.id,
                    title: last.title,
                    pages: last.pages + [page]
                )
            } else {
                sections.append(
                    PageListDateSection(
                        id: "section-\(sections.count)-\(title)",
                        title: title,
                        pages: [page]
                    )
                )
            }
        }

        return sections
    }

    private static func sectionTitle(
        for date: Date?,
        now: Date,
        calendar: Calendar
    ) -> String {
        guard let date else {
            return "较早"
        }

        if calendar.isDate(date, inSameDayAs: now) {
            return "今天"
        }

        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "昨天"
        }

        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let currentYear = calendar.component(.year, from: now)
        guard let year = components.year,
              let month = components.month,
              let day = components.day else {
            return "较早"
        }

        if year == currentYear {
            return "\(month)月\(day)日"
        }

        return "\(year)年\(month)月\(day)日"
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else {
            return nil
        }

        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: value) {
            return date
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}

private struct PageListView: View {
    @ObservedObject var viewModel: WorkspaceViewModel
    @Binding var activePageDragIDs: Set<String>
    @State private var selectedPageIDs: Set<String> = []
    @State private var selectionAnchorPageID: String?
    @State private var pageRowFrames: [String: CGRect] = [:]
    @State private var pageSelectionMarqueeStart: CGPoint?
    @State private var pageSelectionMarqueeCurrent: CGPoint?
    @State private var keyboardActivationVersion = 0

    var body: some View {
#if os(macOS)
        VStack(spacing: 0) {
            pageListHeader

            pageListScroll
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationSplitViewColumnWidth(CGFloat(EditorDesignTokens.Layout.documentListIdealWidth))
        .background(PageListChrome.backgroundColor.ignoresSafeArea(edges: .top))
        .background(
            DropTargetCleanupEventBridge(isEnabled: !activePageDragIDs.isEmpty) {
                activePageDragIDs = []
            }
            .frame(width: 0, height: 0)
        )
#else
        pageListScroll
            .navigationTitle(navigationTitle)
            .navigationSplitViewColumnWidth(CGFloat(EditorDesignTokens.Layout.documentListIdealWidth))
            .background(PageListChrome.backgroundColor)
#endif
    }

#if os(macOS)
    private var pageListHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text(navigationTitle)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(EditorDesignTokens.Colors.primaryText.color)
                    .lineLimit(1)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if viewModel.isSearchActive {
                            viewModel.clearSearchForUI()
                        }
                    }

                Spacer(minLength: 0)

                Button {
                    _ = viewModel.createNewDocumentForUI()
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.callout.weight(.semibold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .foregroundStyle(EditorDesignTokens.Colors.secondaryText.color)
                .help("新建文档")
                .accessibilityLabel("新建文档")
                .accessibilityIdentifier("editor.page-list.new-document")
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(EditorDesignTokens.Colors.tertiaryText.color)

                TextField("搜索", text: pageListSearchBinding)
                    .textFieldStyle(.plain)
                    .accessibilityIdentifier("editor.page-list.search-field")

                if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.clearSearchForUI()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(EditorDesignTokens.Colors.tertiaryText.color)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("清空搜索")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(EditorDesignTokens.Colors.appBackground.color, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(EditorDesignTokens.Colors.border.color.opacity(0.95), lineWidth: 1)
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PageListChrome.backgroundColor)
    }

    private var pageListSearchBinding: Binding<String> {
        Binding {
            viewModel.searchQuery
        } set: { query in
            viewModel.updateSearchQuery(query)
        }
    }
#endif

    private var pageListScroll: some View {
        let visiblePages = viewModel.visibleDocumentPages
        let visiblePageIDs = visiblePages.map(\.id)
        let tagNamesByPageID = Self.tagNamesByPageID(snapshot: viewModel.snapshot)

        return ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 14) {
                switch viewModel.selectedCollection {
                case .recent:
                    ForEach(PageListDateSectionModel.sections(pages: visiblePages)) { section in
                        pageRowsSection(
                            title: section.title,
                            pages: section.pages,
                            visiblePageIDs: visiblePageIDs,
                            tagNamesByPageID: tagNamesByPageID
                        )
                    }
                case .diary:
                    pageRowsSection(
                        title: "日记",
                        pages: visiblePages,
                        visiblePageIDs: visiblePageIDs,
                        tagNamesByPageID: tagNamesByPageID
                    )
                case .allDocuments:
                    pageRowsSection(
                        title: "全部文档",
                        pages: visiblePages,
                        visiblePageIDs: visiblePageIDs,
                        tagNamesByPageID: tagNamesByPageID
                    )
                case .favorites:
                    pageRowsSection(
                        title: "收藏",
                        pages: visiblePages,
                        visiblePageIDs: visiblePageIDs,
                        tagNamesByPageID: tagNamesByPageID
                    )
                case .encrypted:
                    pageRowsSection(
                        title: "加密",
                        pages: visiblePages,
                        visiblePageIDs: visiblePageIDs,
                        tagNamesByPageID: tagNamesByPageID
                    )
                case .tag(let tagID):
                    tagSection(
                        tagID: tagID,
                        visiblePages: visiblePages,
                        visiblePageIDs: visiblePageIDs,
                        tagNamesByPageID: tagNamesByPageID
                    )
                case .search:
#if os(macOS)
                    SearchSectionView(viewModel: viewModel, showsSearchField: false)
#else
                    SearchSectionView(viewModel: viewModel)
#endif
                case .archive:
                    archiveSection
                }

            }
            .padding(.horizontal, 18)
            .padding(.vertical, 22)
        }
        .background(PageListChrome.backgroundColor)
        .coordinateSpace(name: PageListCoordinateSpace.selection)
        .onPreferenceChange(PageRowFramePreferenceKey.self) { frames in
            pageRowFrames = frames
        }
        .overlay(alignment: .topLeading) {
            if let pageSelectionMarqueeRect {
                BlockSelectionMarqueeOverlay(rect: pageSelectionMarqueeRect)
            }
        }
        .simultaneousGesture(pageSelectionMarqueeGesture())
        .background {
#if os(macOS)
            PageListKeyboardShortcutBridge(
                isEnabled: !visiblePageIDs.isEmpty,
                activationVersion: keyboardActivationVersion,
                hasArchiveTargets: {
                    !archiveKeyboardTargetPageIDs().isEmpty
                },
                onSelectAllVisiblePages: {
                    selectAllVisiblePages()
                },
                onSelectRangeToSelectedPage: {
                    selectPageRangeToSelectedPage()
                },
                onArchiveSelectedPages: {
                    archiveSelectedPagesFromKeyboard()
                }
            )
            .frame(width: 0, height: 0)
#else
            EmptyView()
#endif
        }
        .onChange(of: viewModel.visibleDocumentPages.map(\.id)) { _, visiblePageIDs in
            pruneSelectedPageIDs(visiblePageIDs: visiblePageIDs)
        }
        .onChange(of: viewModel.selectedCollection) { _, _ in
            clearPageBatchSelection()
            activatePageListKeyboardShortcuts()
        }
        .overlay(alignment: .bottom) {
            if ArchiveUndoVisibilityPolicy.isVisible(
                canUndoPageArchive: viewModel.canUndoPageArchive,
                selectedCollection: viewModel.selectedCollection
            ) {
                undoArchiveToast
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)
            }
        }
    }

    @ViewBuilder
    private func pageRowsSection(
        title: String,
        pages: [PageSummary],
        visiblePageIDs: [String],
        tagNamesByPageID: [String: [String]]
    ) -> some View {
        Section {
            ForEach(pages) { page in
                pageRow(
                    page,
                    visiblePageIDs: visiblePageIDs,
                    tagNames: tagNamesByPageID[page.id] ?? []
                )
            }
        } header: {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(EditorDesignTokens.Colors.tertiaryText.color)
                .padding(.horizontal, 10)
                .padding(.bottom, 1)
        }
    }

    @ViewBuilder
    private func tagSection(
        tagID: String,
        visiblePages: [PageSummary],
        visiblePageIDs: [String],
        tagNamesByPageID: [String: [String]]
    ) -> some View {
        if tagID.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("标签")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 2)

                ForEach(tagListItems) { item in
                    Button {
                        viewModel.selectCollection(item.collection)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: item.systemImage)
                            Text(item.title)
                                .lineLimit(1)
                            Spacer(minLength: 6)
                            Text("\(item.count)")
                                .font(.caption.weight(.medium))
                                .monospacedDigit()
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .contextMenu {
                        if case .tag(let tagID) = item.collection {
                            Button(role: .destructive) {
                                _ = viewModel.deleteTagForUI(id: tagID)
                            } label: {
                                Label("删除标签", systemImage: "trash")
                            }
                        }
                    }
                    .padding(.leading, CGFloat(SidebarChrome.nestedItemIndent * Double(item.nestingLevel)))
                    .accessibilityIdentifier(tagRowIdentifier(for: item))
                }
            }
        } else {
            pageRowsSection(
                title: tagName(for: tagID),
                pages: visiblePages,
                visiblePageIDs: visiblePageIDs,
                tagNamesByPageID: tagNamesByPageID
            )
        }
    }

    private var tagListItems: [SidebarNavigationItem] {
        SidebarNavigationModel(
            snapshot: viewModel.snapshot,
            selectedCollection: viewModel.selectedCollection
        ).tagItems
    }

    private func tagRowIdentifier(for item: SidebarNavigationItem) -> String {
        if case .tag(let tagID) = item.collection {
            return "editor.tag-row.\(tagID)"
        }
        return item.identifier
    }

    private var archiveSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("归档")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.bottom, 2)

            ForEach(viewModel.snapshot.archivedPages) { page in
                ArchivedPageRow(
                    page: page,
                    onRestore: {
                        viewModel.restoreArchivedPageForUI(id: page.id)
                    },
                    onDelete: {
                        viewModel.permanentlyDeleteArchivedPageForUI(id: page.id)
                    }
                )
            }
        }
    }

    private var undoArchiveToast: some View {
        HStack(spacing: 10) {
            Label("已归档", systemImage: "archivebox")
                .font(.caption.weight(.medium))
                .foregroundStyle(EditorDesignTokens.Colors.primaryText.color)

            Spacer(minLength: 8)

            Button {
                viewModel.undoLastPageArchiveForUI()
            } label: {
                Text("撤销")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(EditorDesignTokens.Colors.accent.color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(EditorDesignTokens.Colors.border.color, lineWidth: 1)
        )
        .shadow(
            color: EditorDesignTokens.Shadows.popoverSmall.swiftUIColor,
            radius: CGFloat(EditorDesignTokens.Shadows.popoverSmall.radius),
            x: CGFloat(EditorDesignTokens.Shadows.popoverSmall.x),
            y: CGFloat(EditorDesignTokens.Shadows.popoverSmall.y)
        )
        .accessibilityIdentifier("editor.undo-page-archive")
    }

    private func pageRow(_ page: PageSummary, visiblePageIDs: [String], tagNames: [String]) -> some View {
        PageRow(
            page: page,
            isSelected: viewModel.selectedPageID == page.id,
            isMarkedForBatch: selectedPageIDs.contains(page.id),
            tagNames: tagNames,
            preview: PageListPreviewResolver.preview(
                pageID: page.id,
                blocks: viewModel.snapshot.blocks,
                attachments: viewModel.snapshot.attachments,
                isEncrypted: page.isEncrypted
            ),
            usesRichPreview: true,
            onBatchSelectionToggle: showsMiddleColumnRowControls ? {
                togglePageBatchSelection(page.id)
            } : nil,
            onFavoriteToggle: showsMiddleColumnRowControls ? {
                viewModel.updatePageFavoriteForUI(
                    id: page.id,
                    isFavorite: !page.isFavorite
                )
            } : nil,
            isBeingDragged: isPageBeingDragged(page.id)
        )
        .contentShape(Rectangle())
        .background(pageRowFrameReporter(page.id))
        .onTapGesture {
            handlePageTap(page.id)
        }
        .onDrag {
            let pageIDs = dragPageIDs(for: page.id, visiblePageIDs: visiblePageIDs)
            activePageDragIDs = Set(pageIDs)
            return NSItemProvider(object: PageDragPayloadResolver.payloadText(pageIDs: pageIDs) as NSString)
        } preview: {
            PageDragPreview(title: page.title, count: dragPageIDs(for: page.id, visiblePageIDs: visiblePageIDs).count)
        }
        .contextMenu {
            if showsMiddleColumnRowControls {
                Button {
                    viewModel.updatePageFavoriteForUI(
                        id: page.id,
                        isFavorite: !page.isFavorite
                    )
                } label: {
                    Label(
                        page.isFavorite ? "取消收藏" : "加入收藏",
                        systemImage: page.isFavorite ? "star.slash" : "star"
                    )
                }
            }

            Button {
                viewModel.updatePagePinnedForUI(
                    id: page.id,
                    isPinned: !page.isPinned
                )
            } label: {
                Label(
                    page.isPinned ? "取消置顶" : "置顶",
                    systemImage: page.isPinned ? "pin.slash" : "pin"
                )
            }

            Button {
                viewModel.updatePageEncryptionForUI(
                    id: page.id,
                    isEncrypted: !page.isEncrypted
                )
            } label: {
                Label(
                    page.isEncrypted ? "取消加密" : "加密",
                    systemImage: page.isEncrypted ? "lock.open" : "lock"
                )
            }

            Button {
                archiveRowPages(page.id)
            } label: {
                Label("归档", systemImage: "archivebox")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            pageSwipeActionButtons(for: page)
        }
    }

    @ViewBuilder
    private func pageSwipeActionButtons(for page: PageSummary) -> some View {
        ForEach(PageRowSwipeActionModel.actions(for: page)) { action in
            Button(role: action.kind == .archive ? .destructive : nil) {
                performSwipeAction(action.kind, for: page)
            } label: {
                Label(action.title, systemImage: action.systemImage)
            }
            .tint(swipeActionTint(action.kind))
        }
    }

    private func performSwipeAction(_ action: PageRowSwipeActionKind, for page: PageSummary) {
        switch action {
        case .archive:
            archiveRowPages(page.id)
        case .favorite:
            viewModel.updatePageFavoriteForUI(
                id: page.id,
                isFavorite: !page.isFavorite
            )
        case .pin:
            viewModel.updatePagePinnedForUI(
                id: page.id,
                isPinned: !page.isPinned
            )
        }
    }

    private func swipeActionTint(_ action: PageRowSwipeActionKind) -> Color {
        CompactPageSwipeActionChrome.color(for: action)
    }

    private var showsMiddleColumnRowControls: Bool {
#if os(macOS)
        false
#else
        true
#endif
    }

    private func togglePageBatchSelection(_ pageID: String) {
        if selectedPageIDs.contains(pageID) {
            selectedPageIDs.remove(pageID)
        } else {
            selectedPageIDs.insert(pageID)
        }
        selectionAnchorPageID = pageID
        activePageDragIDs = []
        activatePageListKeyboardShortcuts()
    }

    private func dragPageIDs(for pageID: String, visiblePageIDs: [String]) -> [String] {
        rowActionPageIDs(for: pageID, visiblePageIDs: visiblePageIDs)
    }

    private func rowActionPageIDs(for pageID: String, visiblePageIDs: [String]? = nil) -> [String] {
        PageListRowActionTargetResolver.pageIDs(
            rowPageID: pageID,
            selectedPageIDs: selectedPageIDs,
            visiblePageIDs: visiblePageIDs ?? viewModel.visibleDocumentPages.map(\.id)
        )
    }

    private func archiveRowPages(_ pageID: String) {
        let pageIDs = rowActionPageIDs(for: pageID)
        guard viewModel.archivePagesForUI(pageIDs: pageIDs) else {
            return
        }
        selectedPageIDs.subtract(pageIDs)
        activePageDragIDs = []
    }

    private func isPageBeingDragged(_ pageID: String) -> Bool {
        activePageDragIDs.contains(pageID)
    }

    private func handlePageTap(_ pageID: String) {
        activePageDragIDs = []

#if os(macOS)
        if PageListModifierKeyState.isRangeSelectionActive {
            selectPageRange(to: pageID)
            return
        }

        if PageListModifierKeyState.isToggleSelectionActive {
            togglePageBatchSelection(pageID)
            return
        }
#endif

        selectedPageIDs = []
        selectionAnchorPageID = pageID
        activatePageListKeyboardShortcuts()
        Task {
            await viewModel.selectPageForUI(id: pageID)
        }
    }

    private func selectPageRange(to pageID: String) {
        let visiblePageIDs = viewModel.visibleDocumentPages.map(\.id)
        let anchorPageID = selectionAnchorPageID
            ?? viewModel.selectedPageID
            ?? visiblePageIDs.first { selectedPageIDs.contains($0) }
            ?? pageID
        let pageIDs = PageListSelectionRangeResolver.selection(
            anchorPageID: anchorPageID,
            targetPageID: pageID,
            visiblePageIDs: visiblePageIDs
        )
        guard !pageIDs.isEmpty else {
            return
        }

        selectedPageIDs = Set(pageIDs)
        selectionAnchorPageID = anchorPageID
        activatePageListKeyboardShortcuts()
        Task {
            await viewModel.selectPageForUI(id: pageID)
        }
    }

    @discardableResult
    private func selectAllVisiblePages() -> Bool {
        let pageIDs = PageListSelectAllResolver.selection(
            visiblePageIDs: viewModel.visibleDocumentPages.map(\.id)
        )
        guard !pageIDs.isEmpty else {
            return false
        }

        selectedPageIDs = Set(pageIDs)
        selectionAnchorPageID = pageIDs.first
        activePageDragIDs = []
        activatePageListKeyboardShortcuts()
        return true
    }

    @discardableResult
    private func selectPageRangeToSelectedPage() -> Bool {
        guard let selectedPageID = viewModel.selectedPageID else {
            return false
        }

        let previousSelection = selectedPageIDs
        selectPageRange(to: selectedPageID)
        return selectedPageIDs != previousSelection || !selectedPageIDs.isEmpty
    }

    private func archiveKeyboardTargetPageIDs() -> [String] {
        let visiblePageIDs = viewModel.visibleDocumentPages.map(\.id)
        let selectedPageIDsInVisibleOrder = visiblePageIDs.filter { selectedPageIDs.contains($0) }
        if !selectedPageIDsInVisibleOrder.isEmpty {
            return selectedPageIDsInVisibleOrder
        }
        if let selectedPageID = viewModel.selectedPageID,
           visiblePageIDs.contains(selectedPageID) {
            return [selectedPageID]
        }
        return []
    }

    @discardableResult
    private func archiveSelectedPagesFromKeyboard() -> Bool {
        let pageIDs = archiveKeyboardTargetPageIDs()
        guard viewModel.archivePagesForUI(pageIDs: pageIDs) else {
            return false
        }
        selectedPageIDs.subtract(pageIDs)
        activePageDragIDs = []
        return true
    }

    private func clearPageBatchSelection() {
        selectedPageIDs = []
        selectionAnchorPageID = nil
        activePageDragIDs = []
        pageSelectionMarqueeStart = nil
        pageSelectionMarqueeCurrent = nil
    }

    private func activatePageListKeyboardShortcuts() {
        keyboardActivationVersion += 1
    }

    private func pruneSelectedPageIDs(visiblePageIDs: [String]) {
        let visiblePageIDSet = Set(visiblePageIDs)
        selectedPageIDs = selectedPageIDs.intersection(visiblePageIDSet)
        if let selectionAnchorPageID,
           !visiblePageIDSet.contains(selectionAnchorPageID) {
            self.selectionAnchorPageID = selectedPageIDs.first
        }
        activePageDragIDs = activePageDragIDs.intersection(visiblePageIDSet)
    }

    private func pageRowFrameReporter(_ pageID: String) -> some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: PageRowFramePreferenceKey.self,
                value: [pageID: proxy.frame(in: .named(PageListCoordinateSpace.selection))]
            )
        }
    }

    private var pageSelectionMarqueeRect: CGRect? {
        guard let pageSelectionMarqueeStart,
              let pageSelectionMarqueeCurrent else {
            return nil
        }

        let rect = BlockSelectionMarqueeRectResolver.rect(
            start: pageSelectionMarqueeStart,
            current: pageSelectionMarqueeCurrent
        )
        guard BlockSelectionMarqueeRectResolver.isVisible(rect) else {
            return nil
        }
        return rect
    }

    private func pageSelectionMarqueeGesture() -> some Gesture {
        DragGesture(
            minimumDistance: 2,
            coordinateSpace: .named(PageListCoordinateSpace.selection)
        )
        .onChanged { value in
            guard isPageSelectionMarqueeEnabled else {
                return
            }
            guard PageListMarqueeStartPolicy.isAllowed(
                location: value.startLocation,
                pageFrames: pageRowFrames
            ) else {
                return
            }

            if pageSelectionMarqueeStart == nil {
                pageSelectionMarqueeStart = value.startLocation
                activatePageListKeyboardShortcuts()
            }
            pageSelectionMarqueeCurrent = value.location

            let selectionRect = BlockSelectionMarqueeRectResolver.rect(
                start: value.startLocation,
                current: value.location
            )
            let pageIDs = PageListMarqueeSelectionResolver.selectedPageIDs(
                selectionRect: selectionRect,
                pageFrames: pageRowFrames,
                visiblePageIDs: viewModel.visibleDocumentPages.map(\.id)
            )
            selectedPageIDs = Set(pageIDs)
            selectionAnchorPageID = pageIDs.first ?? selectionAnchorPageID
            activePageDragIDs = []
        }
        .onEnded { _ in
            pageSelectionMarqueeStart = nil
            pageSelectionMarqueeCurrent = nil
        }
    }

    private var isPageSelectionMarqueeEnabled: Bool {
#if os(macOS)
        viewModel.selectedCollection != .search
#else
        false
#endif
    }

    private var navigationTitle: String {
        switch viewModel.selectedCollection {
        case .recent:
            return "近期文件"
        case .diary:
            return "日记"
        case .allDocuments:
            return "全部文档"
        case .favorites:
            return "收藏"
        case .encrypted:
            return "加密"
        case .tag(let tagID):
            return tagID.isEmpty ? "标签" : tagName(for: tagID)
        case .search:
            return "搜索"
        case .archive:
            return "归档"
        }
    }

    private func tagName(for tagID: String) -> String {
        viewModel.snapshot.tags.first { $0.id == tagID }?.path ?? "标签"
    }

    private static func tagNamesByPageID(snapshot: WorkspaceSnapshot) -> [String: [String]] {
        let tagPathByID = Dictionary(uniqueKeysWithValues: snapshot.tags.map { ($0.id, $0.path) })
        let tagOrderByID = Dictionary(uniqueKeysWithValues: snapshot.tags.enumerated().map { ($0.element.id, $0.offset) })
        var tagIDsByPageID: [String: [String]] = [:]
        for assignment in snapshot.pageTags {
            tagIDsByPageID[assignment.pageID, default: []].append(assignment.tagID)
        }
        return tagIDsByPageID.mapValues { tagIDs in
            tagIDs
                .sorted { (tagOrderByID[$0] ?? Int.max) < (tagOrderByID[$1] ?? Int.max) }
                .compactMap { tagPathByID[$0] }
        }
    }

    private var selectedPageBinding: Binding<String?> {
        Binding {
            viewModel.selectedPageID
        } set: { newValue in
            guard let newValue,
                  newValue != viewModel.selectedPageID else {
                return
            }
            Task { @MainActor in
                await viewModel.selectPageForUI(id: newValue)
            }
        }
    }
}

private struct CompactPageListView: View {
    @ObservedObject var viewModel: WorkspaceViewModel
    let onRevealMainMenu: () -> Void

    var body: some View {
        List {
            SearchSectionView(viewModel: viewModel)

            ForEach(Array(viewModel.snapshot.notebooks.enumerated()), id: \.element.id) { index, notebook in
                Section {
                    ForEach(pages(in: notebook)) { page in
                        NavigationLink(value: CompactRoute.page(page.id)) {
                            PageRow(page: page, isSelected: viewModel.selectedPageID == page.id)
                        }
                        .accessibilityIdentifier("editor.page.\(page.id)")
                        .contextMenu {
                            Button {
                                viewModel.updatePageFavoriteForUI(
                                    id: page.id,
                                    isFavorite: !page.isFavorite
                                )
                            } label: {
                                Label(
                                    page.isFavorite ? "取消收藏" : "加入收藏",
                                    systemImage: page.isFavorite ? "star.slash" : "star"
                                )
                            }

                            Button {
                                viewModel.updatePagePinnedForUI(
                                    id: page.id,
                                    isPinned: !page.isPinned
                                )
                            } label: {
                                Label(
                                    page.isPinned ? "取消置顶" : "置顶",
                                    systemImage: page.isPinned ? "pin.slash" : "pin"
                                )
                            }

                            Button {
                                viewModel.updatePageEncryptionForUI(
                                    id: page.id,
                                    isEncrypted: !page.isEncrypted
                                )
                            } label: {
                                Label(
                                    page.isEncrypted ? "取消加密" : "加密",
                                    systemImage: page.isEncrypted ? "lock.open" : "lock"
                                )
                            }

                            Button {
                                viewModel.archivePageForUI(id: page.id)
                            } label: {
                                Label("归档", systemImage: "archivebox")
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            pageSwipeActionButtons(for: page)
                        }
                    }
                } header: {
                    NotebookSectionHeader(
                        notebook: notebook,
                        nestingLevel: nestingLevel(for: notebook),
                        canMoveUp: NotebookHierarchy.canMoveUp(
                            notebook: notebook,
                            in: viewModel.snapshot.notebooks
                        ),
                        canMoveDown: NotebookHierarchy.canMoveDown(
                            notebook: notebook,
                            in: viewModel.snapshot.notebooks
                        ),
                        canIndent: index > 0,
                        canOutdent: notebook.parentNotebookID != nil,
                        onRename: { name in
                            viewModel.renameNotebookForUI(id: notebook.id, name: name)
                        },
                        onMoveUp: {
                            if let targetIndex = NotebookHierarchy.siblingTargetIndex(
                                for: notebook,
                                direction: .up,
                                in: viewModel.snapshot.notebooks
                            ) {
                                viewModel.moveNotebookForUI(id: notebook.id, toIndex: targetIndex)
                            }
                        },
                        onMoveDown: {
                            if let targetIndex = NotebookHierarchy.siblingTargetIndex(
                                for: notebook,
                                direction: .down,
                                in: viewModel.snapshot.notebooks
                            ) {
                                viewModel.moveNotebookForUI(id: notebook.id, toIndex: targetIndex)
                            }
                        },
                        onIndent: {
                            _ = viewModel.indentNotebookForUI(id: notebook.id)
                        },
                        onOutdent: {
                            _ = viewModel.outdentNotebookForUI(id: notebook.id)
                        },
                        onAddChildNotebook: {
                            _ = viewModel.addNotebookToSelectedWorkspace(parentNotebookID: notebook.id)
                        },
                        onAddPage: {
                            _ = viewModel.addPageToSelectedWorkspace(notebookID: notebook.id)
                        }
                    )
                }
            }

            Section {
                Button {
                    _ = viewModel.addNotebookToSelectedWorkspace()
                } label: {
                    Label("新建笔记本", systemImage: "folder.badge.plus")
                }
            }

            if ArchiveUndoVisibilityPolicy.isVisible(
                canUndoPageArchive: viewModel.canUndoPageArchive,
                selectedCollection: viewModel.selectedCollection
            ) {
                Section {
                    Button {
                        viewModel.undoLastPageArchiveForUI()
                    } label: {
                        Label("撤销归档", systemImage: "arrow.uturn.backward")
                    }
                    .accessibilityIdentifier("editor.undo-page-archive")
                }
            }

            if !viewModel.snapshot.archivedPages.isEmpty {
                Section("归档") {
                    ForEach(viewModel.snapshot.archivedPages) { page in
                        ArchivedPageRow(
                            page: page,
                            onRestore: {
                                viewModel.restoreArchivedPageForUI(id: page.id)
                            },
                            onDelete: {
                                viewModel.permanentlyDeleteArchivedPageForUI(id: page.id)
                            }
                        )
                    }
                }
            }
        }
        .navigationTitle("页面")
        .scrollContentBackground(.hidden)
        .background(CompactChrome.backgroundColor)
        .overlay(alignment: .bottomTrailing) {
            quickCreateButton
                .padding(.trailing, 18)
                .padding(.bottom, 18)
        }
#if os(iOS)
        .navigationBarTitleDisplayMode(
            CompactDocumentListChrome.prefersInlineNavigationTitle ? .inline : .large
        )
        .toolbarBackground(CompactChrome.backgroundColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .highPriorityGesture(
            DragGesture(minimumDistance: 56, coordinateSpace: .local)
                .onEnded { value in
                    guard value.translation.width > 56,
                          abs(value.translation.width) > abs(value.translation.height) * 1.25 else {
                        return
                    }
                    onRevealMainMenu()
                }
        )
#endif
    }

    private func pages(in notebook: NotebookSummary) -> [PageSummary] {
        viewModel.snapshot.pages.filter { $0.notebookID == notebook.id }
    }

    @ViewBuilder
    private func pageSwipeActionButtons(for page: PageSummary) -> some View {
        ForEach(PageRowSwipeActionModel.actions(for: page)) { action in
            Button(role: action.kind == .archive ? .destructive : nil) {
                performSwipeAction(action.kind, for: page)
            } label: {
                Label(action.title, systemImage: action.systemImage)
            }
            .tint(swipeActionTint(action.kind))
        }
    }

    private func performSwipeAction(_ action: PageRowSwipeActionKind, for page: PageSummary) {
        switch action {
        case .archive:
            viewModel.archivePageForUI(id: page.id)
        case .favorite:
            viewModel.updatePageFavoriteForUI(
                id: page.id,
                isFavorite: !page.isFavorite
            )
        case .pin:
            viewModel.updatePagePinnedForUI(
                id: page.id,
                isPinned: !page.isPinned
            )
        }
    }

    private func swipeActionTint(_ action: PageRowSwipeActionKind) -> Color {
        CompactPageSwipeActionChrome.color(for: action)
    }

    private func nestingLevel(for notebook: NotebookSummary) -> Int {
        NotebookHierarchy.nestingLevel(for: notebook, in: viewModel.snapshot.notebooks)
    }

    private var quickCreateButton: some View {
        MobileQuickCreateButton(
            onCreateNewDocument: {
                _ = viewModel.createNewDocumentForCompactUI()
            },
            onCreateDailyDiary: {
                _ = viewModel.createDailyDiaryForCompactUI()
            }
        )
    }
}

private struct CompactCollectionDestination: View {
    @ObservedObject var viewModel: WorkspaceViewModel
    let collection: WorkspaceCollection
    let onRevealMainMenu: () -> Void
    let onRevealNextScreen: () -> Void
    @State private var didSelectCollection = false

    var body: some View {
        CompactCollectionPageListView(
            viewModel: viewModel,
            collection: collection,
            onRevealMainMenu: onRevealMainMenu,
            onRevealNextScreen: onRevealNextScreen
        )
        .onAppear {
            guard !didSelectCollection else {
                return
            }
            didSelectCollection = true
            viewModel.selectCollection(collection)
        }
    }
}

private struct CompactCollectionPageListView: View {
    @ObservedObject var viewModel: WorkspaceViewModel
    let collection: WorkspaceCollection
    let onRevealMainMenu: () -> Void
    let onRevealNextScreen: () -> Void
    @State private var activeSwipeActionPageID: String?
    @State private var listGestureStartedWithOpenSwipeActions = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 0) {
                compactSearchField
                    .padding(.bottom, 12)

                if viewModel.isSearchActive {
                    SearchSectionView(viewModel: viewModel, showsSearchField: false)
                } else {
                    collectionContent
                }
            }
            .padding(.horizontal, CompactDocumentListChrome.horizontalPadding)
            .padding(.vertical, CompactDocumentListChrome.verticalPadding)
        }
        .navigationTitle(navigationTitle)
        .background(CompactChrome.backgroundColor)
        .accessibilityIdentifier("editor.compact-document-list")
        .overlay(alignment: .bottomTrailing) {
            quickCreateButton
                .padding(.trailing, 18)
                .padding(.bottom, 18)
        }
#if os(iOS)
        .navigationBarTitleDisplayMode(
            CompactDocumentListChrome.prefersInlineNavigationTitle ? .inline : .large
        )
        .toolbarBackground(CompactChrome.backgroundColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .simultaneousGesture(
            DragGesture(minimumDistance: 56, coordinateSpace: .local)
                .onChanged { _ in
                    if !listGestureStartedWithOpenSwipeActions {
                        listGestureStartedWithOpenSwipeActions = activeSwipeActionPageID != nil
                    }
                }
                .onEnded { value in
                    defer {
                        listGestureStartedWithOpenSwipeActions = false
                    }
                    guard !listGestureStartedWithOpenSwipeActions else {
                        return
                    }
                    guard abs(value.translation.width) > abs(value.translation.height) * 1.25 else {
                        return
                    }
                    if value.translation.width > 56 {
                        onRevealMainMenu()
                    }
                }
        )
#endif
    }

    private var compactSearchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.callout.weight(.semibold))
                .foregroundStyle(EditorDesignTokens.Colors.tertiaryText.color)

            TextField("搜索", text: compactSearchBinding)
                .textFieldStyle(.plain)
                .accessibilityIdentifier("editor.compact.search-field")

            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.clearSearchForUI()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(EditorDesignTokens.Colors.tertiaryText.color)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清空搜索")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(EditorDesignTokens.Colors.sidebarBackground.color, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(EditorDesignTokens.Colors.border.color, lineWidth: 1)
        )
    }

    private var compactSearchBinding: Binding<String> {
        Binding {
            viewModel.searchQuery
        } set: { query in
            viewModel.updateSearchQuery(query)
        }
    }

    @ViewBuilder
    private var collectionContent: some View {
        switch collection {
        case .search:
            SearchSectionView(viewModel: viewModel)
        case .archive:
            compactArchiveSection
        default:
            ForEach(items) { item in
                CompactPageSwipeActionsRow(
                    page: item.page,
                    activeSwipeActionPageID: $activeSwipeActionPageID,
                    onAction: { action in
                        performSwipeAction(action, for: item.page)
                    }
                ) {
                    NavigationLink(value: CompactRoute.page(item.page.id)) {
                        CompactRecentPageCard(
                            page: item.page,
                            tagNames: item.tagNames,
                            preview: item.preview
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("editor.page.\(item.page.id)")
                }
                .contextMenu {
                    pageContextMenuButtons(for: item.page)
                }
            }
        }
    }

    private var compactArchiveSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if ArchiveUndoVisibilityPolicy.isVisible(
                canUndoPageArchive: viewModel.canUndoPageArchive,
                selectedCollection: viewModel.selectedCollection
            ) {
                Button {
                    viewModel.undoLastPageArchiveForUI()
                } label: {
                    Label("撤销归档", systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("editor.undo-page-archive")
            }

            if viewModel.snapshot.archivedPages.isEmpty {
                Text("没有归档文档")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
            } else {
                ForEach(viewModel.snapshot.archivedPages) { page in
                    ArchivedPageRow(
                        page: page,
                        onRestore: {
                            viewModel.restoreArchivedPageForUI(id: page.id)
                        },
                        onDelete: {
                            viewModel.permanentlyDeleteArchivedPageForUI(id: page.id)
                        }
                    )
                }
            }
        }
    }

    private var items: [CompactCollectionPageListItem] {
        CompactCollectionPageListModel.items(
            snapshot: viewModel.snapshot,
            collection: collection
        )
    }

    @ViewBuilder
    private func pageContextMenuButtons(for page: PageSummary) -> some View {
        Button {
            viewModel.updatePageFavoriteForUI(
                id: page.id,
                isFavorite: !page.isFavorite
            )
        } label: {
            Label(
                page.isFavorite ? "取消收藏" : "加入收藏",
                systemImage: page.isFavorite ? "star.slash" : "star"
            )
        }

        Button {
            viewModel.updatePagePinnedForUI(
                id: page.id,
                isPinned: !page.isPinned
            )
        } label: {
            Label(
                page.isPinned ? "取消置顶" : "置顶",
                systemImage: page.isPinned ? "pin.slash" : "pin"
            )
        }

        Button {
            viewModel.updatePageEncryptionForUI(
                id: page.id,
                isEncrypted: !page.isEncrypted
            )
        } label: {
            Label(
                page.isEncrypted ? "取消加密" : "加密",
                systemImage: page.isEncrypted ? "lock.open" : "lock"
            )
        }

        Button {
            viewModel.archivePageForUI(id: page.id)
        } label: {
            Label("归档", systemImage: "archivebox")
        }
    }

    @ViewBuilder
    private func pageSwipeActionButtons(for page: PageSummary) -> some View {
        ForEach(PageRowSwipeActionModel.actions(for: page)) { action in
            Button(role: action.kind == .archive ? .destructive : nil) {
                performSwipeAction(action.kind, for: page)
            } label: {
                Label(action.title, systemImage: action.systemImage)
            }
            .tint(swipeActionTint(action.kind))
        }
    }

    private func performSwipeAction(_ action: PageRowSwipeActionKind, for page: PageSummary) {
        switch action {
        case .archive:
            viewModel.archivePageForUI(id: page.id)
        case .favorite:
            viewModel.updatePageFavoriteForUI(
                id: page.id,
                isFavorite: !page.isFavorite
            )
        case .pin:
            viewModel.updatePagePinnedForUI(
                id: page.id,
                isPinned: !page.isPinned
            )
        }
    }

    private func swipeActionTint(_ action: PageRowSwipeActionKind) -> Color {
        CompactPageSwipeActionChrome.color(for: action)
    }

    private var navigationTitle: String {
        switch collection {
        case .allDocuments:
            return "全部文档"
        case .favorites:
            return "收藏"
        case .encrypted:
            return "加密"
        case .recent:
            return "近期文件"
        case .diary:
            return "日记"
        case .tag:
            return "标签"
        case .search:
            return "搜索"
        case .archive:
            return "归档"
        }
    }

    private var quickCreateButton: some View {
        MobileQuickCreateButton(
            onCreateNewDocument: {
                _ = viewModel.createNewDocumentForCompactUI()
            },
            onCreateDailyDiary: {
                _ = viewModel.createDailyDiaryForCompactUI()
            }
        )
    }
}

private struct CompactPageSwipeActionsRow<Content: View>: View {
    let page: PageSummary
    let onAction: (PageRowSwipeActionKind) -> Void
    let content: Content
    @Binding private var activeSwipeActionPageID: String?
    @State private var horizontalOffset: CGFloat = 0
    @State private var dragStartHorizontalOffset: CGFloat?

    init(
        page: PageSummary,
        activeSwipeActionPageID: Binding<String?> = .constant(nil),
        onAction: @escaping (PageRowSwipeActionKind) -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.page = page
        _activeSwipeActionPageID = activeSwipeActionPageID
        self.onAction = onAction
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            if visibleSwipeActionWidth > 0 {
                visibleSwipeActions
            }
            content
                .offset(x: horizontalOffset)
                .contentShape(Rectangle())
                .allowsHitTesting(horizontalOffset == 0)
        }
        .contentShape(Rectangle())
        .highPriorityGesture(swipeGesture)
        .onChange(of: activeSwipeActionPageID) { _, pageID in
            if pageID != page.id, horizontalOffset != 0 {
                updateHorizontalOffset(0, animated: true)
                dragStartHorizontalOffset = nil
            }
        }
        .clipped()
    }

    private var visibleSwipeActions: some View {
        swipeActions
            .frame(width: actionGroupWidth, height: actionHeight, alignment: .trailing)
            .opacity(swipeActionGroupOpacity)
            .offset(x: swipeActionGroupTrailingOffset)
            .frame(width: visibleSwipeActionWidth, alignment: .trailing)
            .clipped()
            .frame(maxWidth: .infinity, alignment: .trailing)
            .contentShape(Rectangle())
            .highPriorityGesture(swipeGesture)
            .allowsHitTesting(isSwipeActionGroupFullyOpen)
            .accessibilityHidden(!isSwipeActionGroupFullyOpen)
    }

    private var swipeActions: some View {
        HStack(spacing: 0) {
            ForEach(PageRowSwipeActionModel.actions(for: page)) { action in
                Button {
                    closeSwipeActions()
                    onAction(action.kind)
                } label: {
                    Label(action.title, systemImage: action.systemImage)
                        .labelStyle(.iconOnly)
                        .font(.system(
                            size: scaledActionIconSize,
                            weight: CompactPageSwipeActionChrome.iconWeight
                        ))
                        .frame(width: scaledActionButtonWidth, height: actionHeight)
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .background(swipeActionColor(action.kind))
                .accessibilityLabel(action.title)
                .accessibilityIdentifier("editor.page.\(page.id).swipe.\(action.kind.accessibilityIdentifier)")
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: actionCornerRadius, style: .continuous))
        .frame(height: actionHeight)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 18, coordinateSpace: .local)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else {
                    return
                }
                if dragStartHorizontalOffset == nil {
                    dragStartHorizontalOffset = horizontalOffset
                }
                let startOffset = dragStartHorizontalOffset ?? horizontalOffset
                updateHorizontalOffset(startOffset + value.translation.width, animated: false)
            }
            .onEnded { value in
                defer {
                    dragStartHorizontalOffset = nil
                }
                guard abs(value.translation.width) > abs(value.translation.height) else {
                    updateHorizontalOffset(0, animated: true)
                    return
                }
                let startOffset = dragStartHorizontalOffset ?? horizontalOffset
                let projectedOffset = min(
                    0,
                    max(startOffset + value.predictedEndTranslation.width, -maximumRevealWidth)
                )
                let shouldStayOpen = CompactPageSwipeRevealPolicy.shouldStayOpen(
                    startOffset: startOffset,
                    translationWidth: value.translation.width,
                    projectedOffset: projectedOffset,
                    maximumRevealWidth: maximumRevealWidth
                )
                updateHorizontalOffset(shouldStayOpen ? -maximumRevealWidth : 0, animated: true)
            }
    }

    private var maximumRevealWidth: CGFloat {
        actionWidth * actionCount
    }

    private var actionWidth: CGFloat {
        CompactPageSwipeActionChrome.actionWidth
    }

    private var actionHeight: CGFloat {
        CompactPageSwipeActionChrome.actionHeight
    }

    private var actionCount: CGFloat {
        CGFloat(PageRowSwipeActionModel.actions(for: page).count)
    }

    private var visibleSwipeActionWidth: CGFloat {
        CompactPageSwipeRevealPolicy.visibleWidth(
            horizontalOffset: horizontalOffset,
            maximumRevealWidth: maximumRevealWidth
        )
    }

    private var actionWidthScale: CGFloat {
        CompactPageSwipeRevealPolicy.actionWidthScale(
            visibleWidth: visibleSwipeActionWidth,
            maximumRevealWidth: maximumRevealWidth
        )
    }

    private var actionGroupWidth: CGFloat {
        CompactPageSwipeRevealPolicy.actionGroupWidth(
            visibleWidth: visibleSwipeActionWidth,
            maximumRevealWidth: maximumRevealWidth
        )
    }

    private var scaledActionButtonWidth: CGFloat {
        actionGroupWidth / actionCount
    }

    private var scaledActionIconSize: CGFloat {
        CompactPageSwipeActionChrome.iconSize
            * CompactPageSwipeRevealPolicy.iconScale(
                visibleWidth: visibleSwipeActionWidth,
                maximumRevealWidth: maximumRevealWidth
            )
    }

    private var actionCornerRadius: CGFloat {
        CompactPageSwipeRevealPolicy.cornerRadius(visibleWidth: visibleSwipeActionWidth)
    }

    private var swipeActionGroupOpacity: Double {
        CompactPageSwipeRevealPolicy.opacity(
            visibleWidth: visibleSwipeActionWidth,
            maximumRevealWidth: maximumRevealWidth
        )
    }

    private var swipeActionGroupTrailingOffset: CGFloat {
        CompactPageSwipeRevealPolicy.trailingOffset(
            visibleWidth: visibleSwipeActionWidth,
            maximumRevealWidth: maximumRevealWidth
        )
    }

    private var isSwipeActionGroupFullyOpen: Bool {
        visibleSwipeActionWidth >= maximumRevealWidth - 1
    }

    private func closeSwipeActions() {
        updateHorizontalOffset(0, animated: true)
    }

    private func updateHorizontalOffset(_ offset: CGFloat, animated: Bool) {
        let clampedOffset = min(0, max(offset, -maximumRevealWidth))
        let applyOffset = {
            horizontalOffset = clampedOffset
            if clampedOffset == 0 {
                if activeSwipeActionPageID == page.id {
                    activeSwipeActionPageID = nil
                }
            } else {
                activeSwipeActionPageID = page.id
            }
        }

        if animated {
            withAnimation(CompactPageSwipeActionChrome.releaseAnimation, applyOffset)
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction, applyOffset)
        }
    }

    private func swipeActionColor(_ action: PageRowSwipeActionKind) -> Color {
        CompactPageSwipeActionChrome.color(for: action)
    }
}

enum NotebookHierarchyMoveDirection {
    case up
    case down
}

enum NotebookHierarchy {
    static func nestingLevel(for notebook: NotebookSummary, in notebooks: [NotebookSummary]) -> Int {
        var level = 0
        var visitedNotebookIDs: Set<String> = [notebook.id]
        var parentNotebookID = notebook.parentNotebookID

        while let currentParentID = parentNotebookID,
              !visitedNotebookIDs.contains(currentParentID),
              let parentNotebook = notebooks.first(where: { $0.id == currentParentID }) {
            level += 1
            visitedNotebookIDs.insert(currentParentID)
            parentNotebookID = parentNotebook.parentNotebookID
        }

        return min(level, 6)
    }

    static func canMoveUp(notebook: NotebookSummary, in notebooks: [NotebookSummary]) -> Bool {
        siblingIndex(for: notebook, in: notebooks).map { $0 > 0 } ?? false
    }

    static func canMoveDown(notebook: NotebookSummary, in notebooks: [NotebookSummary]) -> Bool {
        guard let siblingIndex = siblingIndex(for: notebook, in: notebooks) else {
            return false
        }
        return siblingIndex < siblings(of: notebook, in: notebooks).count - 1
    }

    static func siblingTargetIndex(
        for notebook: NotebookSummary,
        direction: NotebookHierarchyMoveDirection,
        in notebooks: [NotebookSummary]
    ) -> Int? {
        guard let siblingIndex = siblingIndex(for: notebook, in: notebooks) else {
            return nil
        }

        switch direction {
        case .up:
            return siblingIndex > 0 ? siblingIndex - 1 : nil
        case .down:
            let siblingCount = siblings(of: notebook, in: notebooks).count
            return siblingIndex < siblingCount - 1 ? siblingIndex + 1 : nil
        }
    }

    private static func siblingIndex(
        for notebook: NotebookSummary,
        in notebooks: [NotebookSummary]
    ) -> Int? {
        siblings(of: notebook, in: notebooks).firstIndex { $0.id == notebook.id }
    }

    private static func siblings(
        of notebook: NotebookSummary,
        in notebooks: [NotebookSummary]
    ) -> [NotebookSummary] {
        notebooks.filter { $0.parentNotebookID == notebook.parentNotebookID }
    }
}

private struct NotebookSectionHeader: View {
    let notebook: NotebookSummary
    let nestingLevel: Int
    let canMoveUp: Bool
    let canMoveDown: Bool
    let canIndent: Bool
    let canOutdent: Bool
    let onRename: (String) -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onIndent: () -> Void
    let onOutdent: () -> Void
    let onAddChildNotebook: () -> Void
    let onAddPage: () -> Void
    @State private var draftName: String

    init(
        notebook: NotebookSummary,
        nestingLevel: Int = 0,
        canMoveUp: Bool,
        canMoveDown: Bool,
        canIndent: Bool = false,
        canOutdent: Bool = false,
        onRename: @escaping (String) -> Void,
        onMoveUp: @escaping () -> Void,
        onMoveDown: @escaping () -> Void,
        onIndent: @escaping () -> Void = {},
        onOutdent: @escaping () -> Void = {},
        onAddChildNotebook: @escaping () -> Void = {},
        onAddPage: @escaping () -> Void
    ) {
        self.notebook = notebook
        self.nestingLevel = nestingLevel
        self.canMoveUp = canMoveUp
        self.canMoveDown = canMoveDown
        self.canIndent = canIndent
        self.canOutdent = canOutdent
        self.onRename = onRename
        self.onMoveUp = onMoveUp
        self.onMoveDown = onMoveDown
        self.onIndent = onIndent
        self.onOutdent = onOutdent
        self.onAddChildNotebook = onAddChildNotebook
        self.onAddPage = onAddPage
        _draftName = State(initialValue: notebook.name)
    }

    var body: some View {
        HStack(spacing: 8) {
            TextField("笔记本", text: nameBinding)
                .textFieldStyle(.plain)
                .font(.caption.weight(.semibold))
                .accessibilityIdentifier("editor.notebook.\(notebook.id).name")
            Spacer(minLength: 8)

            Button {
                onMoveUp()
            } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.borderless)
            .disabled(!canMoveUp)
            .help("上移")
            .accessibilityLabel("上移笔记本")
            .accessibilityValue(controlAvailabilityValue(canMoveUp))
            .accessibilityIdentifier("editor.notebook.\(notebook.id).move-up")

            Button {
                onMoveDown()
            } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.borderless)
            .disabled(!canMoveDown)
            .help("下移")
            .accessibilityLabel("下移笔记本")
            .accessibilityValue(controlAvailabilityValue(canMoveDown))
            .accessibilityIdentifier("editor.notebook.\(notebook.id).move-down")

            Button {
                onOutdent()
            } label: {
                Image(systemName: "decrease.indent")
            }
            .buttonStyle(.borderless)
            .disabled(!canOutdent)
            .help("减少缩进")
            .accessibilityLabel("减少笔记本缩进")
            .accessibilityValue(controlAvailabilityValue(canOutdent))
            .accessibilityIdentifier("editor.notebook.\(notebook.id).outdent")

            Button {
                onIndent()
            } label: {
                Image(systemName: "increase.indent")
            }
            .buttonStyle(.borderless)
            .disabled(!canIndent)
            .help("增加缩进")
            .accessibilityLabel("增加笔记本缩进")
            .accessibilityValue(controlAvailabilityValue(canIndent))
            .accessibilityIdentifier("editor.notebook.\(notebook.id).indent")

            Button {
                onAddChildNotebook()
            } label: {
                Image(systemName: "folder.badge.plus")
            }
            .buttonStyle(.borderless)
            .help("新建子笔记本")
            .accessibilityLabel("新建子笔记本")
            .accessibilityValue(controlAvailabilityValue(true))
            .accessibilityIdentifier("editor.notebook.\(notebook.id).add-child-notebook")

            Button {
                onAddPage()
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
            .help("新建页面")
            .accessibilityLabel("在笔记本中新建页面")
            .accessibilityValue(controlAvailabilityValue(true))
            .accessibilityIdentifier("editor.notebook.\(notebook.id).add-page")
        }
        .onChange(of: notebook.name) { _, name in
            if draftName != name {
                draftName = name
            }
        }
        .padding(.leading, CGFloat(nestingLevel) * 14)
    }

    private var nameBinding: Binding<String> {
        Binding {
            draftName
        } set: { name in
            draftName = name
            onRename(name)
        }
    }

    private func controlAvailabilityValue(_ isAvailable: Bool) -> String {
        isAvailable ? "可用" : "不可用"
    }
}

private struct SearchSectionView: View {
    @ObservedObject var viewModel: WorkspaceViewModel
    var showsSearchField = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showsSearchField {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(EditorDesignTokens.Colors.tertiaryText.color)

                    TextField("标题、正文、附件", text: searchBinding)
                        .textFieldStyle(.plain)
                        .accessibilityIdentifier("editor.search-field")

                    if !viewModel.searchQuery.isEmpty {
                        Button {
                            viewModel.clearSearchForUI()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(EditorDesignTokens.Colors.tertiaryText.color)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("清空搜索")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(EditorDesignTokens.Colors.sidebarBackground.color, in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(EditorDesignTokens.Colors.border.color, lineWidth: 1)
                )
            }

            if !viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("\(viewModel.searchResults.count) 个结果")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(EditorDesignTokens.Colors.tertiaryText.color)
                    .padding(.horizontal, 4)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(viewModel.searchResults) { result in
                    Button {
                        viewModel.selectSearchResult(result)
                    } label: {
                        SearchResultRow(result: result)
                    }
                    .buttonStyle(.plain)
                    .disabled(result.destinationPageID == nil)
                }
            }
        }
    }

    private var searchBinding: Binding<String> {
        Binding {
            viewModel.searchQuery
        } set: { query in
            viewModel.updateSearchQuery(query)
        }
    }
}

private struct SearchResultRow: View {
    let result: SearchResult

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: iconName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(EditorDesignTokens.Colors.accent.color)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.title)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Text(result.snippet)
                    .font(.caption)
                    .foregroundStyle(EditorDesignTokens.Colors.secondaryText.color)
                    .lineLimit(2)
                Text(matchKindTitle)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(EditorDesignTokens.Colors.tertiaryText.color)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EditorDesignTokens.Colors.sidebarBackground.color.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityIdentifier("editor.search-result.\(result.id)")
    }

    private var iconName: String {
        switch result.entityType {
        case "page":
            return "doc.text"
        case "attachment":
            return "paperclip"
        default:
            return "text.alignleft"
        }
    }

    private var matchKindTitle: String {
        switch result.matchKind {
        case .exact:
            return "精准匹配"
        case .fullText:
            return "全文匹配"
        case .fuzzy:
            return "模糊匹配"
        case .semantic:
            return "语义匹配"
        }
    }
}

enum PageRowDragVisualPolicy {
    static func opacity(isBeingDragged: Bool) -> Double {
        isBeingDragged ? 0.42 : 1
    }

    static func scale(isBeingDragged: Bool) -> Double {
        isBeingDragged ? 0.985 : 1
    }

    static func shadowOpacity(isBeingDragged: Bool) -> Double {
        isBeingDragged ? 0.10 : 0
    }

    static func shadowRadius(isBeingDragged: Bool) -> Double {
        isBeingDragged ? 10 : 0
    }

    static func shadowYOffset(isBeingDragged: Bool) -> Double {
        isBeingDragged ? 5 : 0
    }
}

enum PageRowLayoutPolicy {
    static let maxWidth: CGFloat = .infinity
    static let favoriteButtonSize: CGFloat = 22
}

private struct PageRow: View {
    let page: PageSummary
    var isSelected = false
    var isMarkedForBatch = false
    var tagNames: [String] = []
    var preview: PageListPreview?
    var usesRichPreview = false
    var onBatchSelectionToggle: (() -> Void)? = nil
    var onFavoriteToggle: (() -> Void)? = nil
    var isBeingDragged = false

    var body: some View {
        Group {
            if usesRichPreview {
                richPreviewBody
            } else {
                compactBody
            }
        }
        .opacity(PageRowDragVisualPolicy.opacity(isBeingDragged: isBeingDragged))
        .scaleEffect(PageRowDragVisualPolicy.scale(isBeingDragged: isBeingDragged), anchor: .center)
        .shadow(
            color: EditorDesignTokens.Colors.shadow.color.opacity(
                PageRowDragVisualPolicy.shadowOpacity(isBeingDragged: isBeingDragged)
            ),
            radius: CGFloat(PageRowDragVisualPolicy.shadowRadius(isBeingDragged: isBeingDragged)),
            x: 0,
            y: CGFloat(PageRowDragVisualPolicy.shadowYOffset(isBeingDragged: isBeingDragged))
        )
        .animation(.easeOut(duration: 0.12), value: isBeingDragged)
    }

    private var compactBody: some View {
        HStack(spacing: 8) {
            batchSelectionButton

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(displayTitle)
                        .font(isSelected ? .body.weight(.semibold) : .body)
                        .lineLimit(1)
                    PageRowStatusBadges(page: page, font: .caption2.weight(.semibold))
                }
                .accessibilityLabel(displayTitle)
                .accessibilityValue(pageRowAccessibilityValue)
                .accessibilityIdentifier("editor.page-row.\(page.id)")

                if !tagNames.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(tagNames, id: \.self) { tagName in
                            Text(tagName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(EditorDesignTokens.Colors.border.color.opacity(0.42))
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        }
                    }
                    .accessibilityHidden(true)
                }
            }

            Spacer(minLength: 8)
        }
        .frame(maxWidth: PageRowLayoutPolicy.maxWidth, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(compactBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(compactBorderColor, lineWidth: 1)
        )
    }

    private var richPreviewBody: some View {
        HStack(alignment: .top, spacing: 12) {
            batchSelectionButton
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(displayTitle)
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)
                        .foregroundStyle(EditorDesignTokens.Colors.primaryText.color)
                    PageRowStatusBadges(page: page, font: .caption.weight(.semibold))
                }
                .accessibilityLabel(displayTitle)
                .accessibilityValue(pageRowAccessibilityValue)
                .accessibilityIdentifier("editor.page-row.\(page.id)")

                if !tagNames.isEmpty {
                    tagChips
                }

                if let excerpt = preview?.excerpt, !excerpt.isEmpty {
                    Text(excerpt)
                        .font(.callout)
                        .foregroundStyle(EditorDesignTokens.Colors.tertiaryText.color)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                } else if page.isEncrypted {
                    Label("加密内容", systemImage: "lock.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(EditorDesignTokens.Colors.tertiaryText.color)
                }

                if preview?.imageAttachment != nil || preview?.fileAttachment != nil {
                    HStack(alignment: .top, spacing: 10) {
                        if let imageAttachment = preview?.imageAttachment {
                            PageRowImageAttachmentThumbnail(attachment: imageAttachment)
                        }

                        if let fileAttachment = preview?.fileAttachment {
                            PageRowFileAttachmentPill(attachment: fileAttachment)
                        }
                    }
                }

            }

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .frame(
            maxWidth: PageRowLayoutPolicy.maxWidth,
            minHeight: CGFloat(EditorDesignTokens.Layout.documentListRowMinHeight),
            alignment: .topLeading
        )
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(richBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(richBorderColor, lineWidth: 1)
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PageListChrome.dividerColor)
                .frame(height: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private var compactBackgroundColor: Color {
        if isMarkedForBatch {
            return PageListChrome.batchFillColor
        }
        return isSelected ? PageListChrome.selectedFillColor : Color.clear
    }

    private var displayTitle: String {
        PageTitleDisplayPolicy.listTitle(for: page.title)
    }

    private var compactBorderColor: Color {
        isMarkedForBatch ? PageListChrome.batchBorderColor : Color.clear
    }

    private var richBackgroundColor: Color {
        if isMarkedForBatch {
            return PageListChrome.batchFillColor
        }
        return isSelected ? PageListChrome.selectedFillColor : Color.clear
    }

    private var richBorderColor: Color {
        if isMarkedForBatch {
            return PageListChrome.batchBorderColor
        }
        return Color.clear
    }

    @ViewBuilder
    private var batchSelectionButton: some View {
        if let onBatchSelectionToggle {
            Button(action: onBatchSelectionToggle) {
                Image(systemName: isMarkedForBatch ? "checkmark.circle.fill" : "circle")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(isMarkedForBatch ? MobileActionChrome.accentColor : EditorDesignTokens.Colors.tertiaryText.color)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(isMarkedForBatch ? "取消选择页面" : "选择页面")
            .accessibilityValue(isMarkedForBatch ? "已选择" : "未选择")
            .accessibilityIdentifier("editor.page-row.\(page.id).selection-toggle")
        }
    }

    private var pageIcon: some View {
        Image(systemName: PageRowIconResolver.systemName(isEncrypted: page.isEncrypted))
            .font(.callout.weight(.medium))
            .foregroundStyle(isSelected ? EditorDesignTokens.Colors.primaryText.color : EditorDesignTokens.Colors.tertiaryText.color)
            .accessibilityHidden(true)
    }

    private var tagChips: some View {
        HStack(spacing: 5) {
            ForEach(tagNames, id: \.self) { tagName in
                Text(tagName)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(EditorDesignTokens.Colors.secondaryText.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(EditorDesignTokens.Colors.border.color.opacity(0.42))
                    .clipShape(Capsule())
            }
        }
        .accessibilityHidden(true)
    }

    private func favoriteButton(_ onFavoriteToggle: @escaping () -> Void) -> some View {
        Button {
            onFavoriteToggle()
        } label: {
            Image(systemName: page.isFavorite ? "star.fill" : "star")
                .font(.callout.weight(.medium))
                .foregroundStyle(page.isFavorite ? .yellow : EditorDesignTokens.Colors.tertiaryText.color)
                .frame(
                    width: PageRowLayoutPolicy.favoriteButtonSize,
                    height: PageRowLayoutPolicy.favoriteButtonSize
                )
        }
        .buttonStyle(.borderless)
        .help(page.isFavorite ? "取消收藏" : "加入收藏")
        .accessibilityLabel(page.isFavorite ? "取消收藏页面" : "收藏页面")
        .accessibilityValue(page.isFavorite ? "已收藏" : "未收藏")
        .accessibilityIdentifier("editor.page.\(page.id).favorite")
    }

    private var pageRowAccessibilityValue: String {
        let selection = isSelected ? "已选中" : "未选中"
        let batchSelection = isMarkedForBatch ? "已加入批量选择" : "未加入批量选择"
        let favorite = page.isFavorite ? "已收藏" : "未收藏"
        let pinned = page.isPinned ? "已置顶" : "未置顶"
        let encryption = page.isEncrypted ? "已加密" : "未加密"
        let tags = tagNames.isEmpty ? "无标签" : "标签：\(tagNames.joined(separator: ", "))"
        return "\(selection), \(batchSelection), \(pinned), \(favorite), \(encryption), \(tags)"
    }
}

enum PageTagEditorVisibilityPolicy {
    static func isVisible(selectedTagIDs: [String], selectedTagNames: [String]) -> Bool {
        !selectedTagIDs.isEmpty || !selectedTagNames.isEmpty
    }
}

enum PageTagEditorChromePolicy {
    static let showsCreateField = true
}

private struct PageTagEditor: View {
    let availableTags: [TagSummary]
    let selectedTagIDs: [String]
    let selectedTagNames: [String]
    let onRemoveTag: (String) -> Bool
    let onCreateTag: (String) -> Bool
    @State private var draftName = ""

    var body: some View {
        HStack(spacing: 6) {
            ForEach(selectedTags) { tag in
                Button {
                    _ = onRemoveTag(tag.id)
                } label: {
                    HStack(spacing: 4) {
                        Text(tag.path)
                            .lineLimit(1)
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(EditorDesignTokens.Colors.secondaryText.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(EditorDesignTokens.Colors.border.color.opacity(0.42))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("移除标签 \(tag.path)")
                .accessibilityIdentifier("editor.page-tag.\(tag.id).remove")
            }

            if PageTagEditorChromePolicy.showsCreateField {
                TextField("添加标签", text: $draftName)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .frame(width: 86)
                    .onSubmit(commitDraft)
                    .accessibilityIdentifier("editor.page-tag.add-field")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("页面标签")
        .accessibilityValue(selectedTagNames.isEmpty ? "无标签" : selectedTagNames.joined(separator: ", "))
    }

    private var selectedTags: [TagSummary] {
        let selectedTagIDSet = Set(selectedTagIDs)
        let matchedTags = availableTags.filter { selectedTagIDSet.contains($0.id) }
        if !matchedTags.isEmpty {
            return matchedTags
        }
        return selectedTagNames.map { name in
            TagSummary(id: name, workspaceID: "", parentTagID: nil, name: name, path: name)
        }
    }

    private func commitDraft() {
        let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            return
        }
        if onCreateTag(name) {
            draftName = ""
        }
    }
}

private struct PageDragPreview: View {
    let title: String
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: count > 1 ? "doc.on.doc" : "doc.text")
                .font(.callout.weight(.semibold))
            Text(count > 1 ? "\(count) 个文档" : title)
                .font(.callout.weight(.medium))
                .lineLimit(1)
        }
        .foregroundStyle(EditorDesignTokens.Colors.primaryText.color)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct PageRowImageAttachmentThumbnail: View {
    let attachment: AttachmentSnapshot

    var body: some View {
        Group {
            if let image = thumbnailImage {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(SpecialBlockSurfaceChrome.attachmentBackgroundToken.color)
            }
        }
        .frame(width: 112, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .accessibilityLabel("图片附件")
        .accessibilityValue(attachment.originalFilename)
    }

    private var thumbnailImage: Image? {
        for path in imageCandidatePaths {
#if os(macOS)
            if let image = NSImage(contentsOfFile: path) {
                return Image(nsImage: image)
            }
#elseif os(iOS)
            if let image = UIImage(contentsOfFile: path) {
                return Image(uiImage: image)
            }
#else
            return nil
#endif
        }
        return nil
    }

    private var imageCandidatePaths: [String] {
        var paths: [String] = []
        if !attachment.localPath.isEmpty {
            paths.append(attachment.localPath)
        }
        if let thumbnailPath = attachment.thumbnailPath,
           !thumbnailPath.isEmpty,
           !paths.contains(thumbnailPath) {
            paths.append(thumbnailPath)
        }
        return paths
    }
}

private struct PageRowFileAttachmentPill: View {
    let attachment: AttachmentSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(attachment.originalFilename)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(fileExtension)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(EditorDesignTokens.Colors.border.color.opacity(0.42))
                .clipShape(Capsule())
        }
        .frame(width: 108, height: 72, alignment: .leading)
        .padding(.horizontal, 10)
        .background(SpecialBlockSurfaceChrome.attachmentBackgroundToken.color)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .accessibilityLabel("文件附件")
        .accessibilityValue(attachment.originalFilename)
    }

    private var fileExtension: String {
        let ext = (attachment.originalFilename as NSString).pathExtension
        return ext.isEmpty ? "文件" : ext.uppercased()
    }
}

private struct ArchivedPageRow: View {
    let page: PageSummary
    let onRestore: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "archivebox")
                .foregroundStyle(.secondary)

            Text(PageTitleDisplayPolicy.listTitle(for: page.title))
                .font(.body)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 8)

            Button {
                onRestore()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .buttonStyle(.borderless)
            .help("恢复")
            .accessibilityIdentifier("editor.restore-page.\(page.id)")

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("永久删除")
            .accessibilityIdentifier("editor.delete-archived-page.\(page.id)")
        }
        .padding(.vertical, 5)
        .accessibilityIdentifier("editor.archived-page.\(page.id)")
    }
}

private enum EditorCanvasCoordinateSpace {
    static let blockSelection = "editor.canvas.block-selection"
#if os(iOS)
    static let mobileNavigationTitle = "editor.canvas.mobile-navigation-title"
#endif
}

private enum PageListCoordinateSpace {
    static let selection = "editor.page-list.selection"
}

enum MobileNavigationBarChrome {
    static let topMaskHeight: CGFloat = 72
    static let collapsedTitleVerticalOffset: CGFloat = 0
    static let usesSolidEditorBackground = true
}

enum PageTitleDisplayPolicy {
    static let emptyTitlePlaceholder = "未命名"

    static func listTitle(for title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? emptyTitlePlaceholder
            : title
    }

    static func editingText(for title: String) -> String {
        title
    }
}

enum PageTitleFieldChrome {
    static let cursorColorToken = EditorDesignTokens.Colors.accent

    static func placeholderText(isFocused: Bool, text: String) -> String? {
        guard !isFocused,
              text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return PageTitleDisplayPolicy.emptyTitlePlaceholder
    }
}

enum PageTitleFocusSchedulingPolicy {
    static let compactRetryDelays: [TimeInterval] = [0]
    static let regularRetryDelays: [TimeInterval] = [0.15, 0.35, 0.7]

    static func shouldRunScheduledAttempt(
        scheduledPageID: String?,
        requestedPageID: String,
        currentPageID: String?
    ) -> Bool {
        scheduledPageID == requestedPageID && currentPageID == requestedPageID
    }
}

private struct MobilePageTitleFramePreferenceKey: PreferenceKey {
    static let defaultValue = CGRect.zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private struct BlockRowFramePreferenceKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in newValue })
    }
}

private struct PageRowFramePreferenceKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in newValue })
    }
}

private struct AttachmentResizeHandleFramePreferenceKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in newValue })
    }
}

private struct BlockSelectionMarqueeOverlay: View {
    let rect: CGRect

    var body: some View {
        RoundedRectangle(
            cornerRadius: CGFloat(BlockSelectionMarqueeChrome.cornerRadius),
            style: .continuous
        )
        .fill(EditorDesignTokens.Colors.accent.color.opacity(BlockSelectionMarqueeChrome.fillOpacity))
        .overlay(
            RoundedRectangle(
                cornerRadius: CGFloat(BlockSelectionMarqueeChrome.cornerRadius),
                style: .continuous
            )
            .stroke(
                EditorDesignTokens.Colors.accent.color.opacity(BlockSelectionMarqueeChrome.strokeOpacity),
                lineWidth: CGFloat(BlockSelectionMarqueeChrome.strokeWidth)
            )
        )
        .frame(width: max(1, rect.width), height: max(1, rect.height))
        .offset(x: rect.minX, y: rect.minY)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct EncryptedPageLockedView: View {
    let isAuthenticating: Bool
    let onUnlock: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(EditorDesignTokens.Colors.tertiaryText.color)

            Text("加密内容")
                .font(.title3.weight(.semibold))
                .foregroundStyle(EditorDesignTokens.Colors.primaryText.color)

            Button {
                onUnlock()
            } label: {
                Label(isAuthenticating ? "验证中..." : "解锁", systemImage: "lock.open")
            }
            .buttonStyle(.borderedProminent)
            .disabled(isAuthenticating)
            .accessibilityIdentifier("editor.encrypted-page-unlock")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(EditorDesignTokens.Colors.appBackground.color)
        .accessibilityIdentifier("editor.encrypted-page-locked")
    }
}

#if os(iOS)
private struct PageTitleUIKitTextField: UIViewRepresentable {
    @Binding var text: String
    let focusRequestID: UUID?
    let contentFont: EditorContentFont
    let isEnabled: Bool
    let onInteractionBegan: () -> Void
    let onEditingBegan: () -> Void
    let onEditingEnded: () -> Void
    let onReturn: () -> Void
    let onFocusRequestFinished: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.placeholder = PageTitleFieldChrome.placeholderText(isFocused: false, text: "")
        textField.font = Self.titleFont(contentFont: contentFont)
        textField.textColor = EditorDesignTokens.Colors.primaryText.uiColor
        textField.tintColor = PageTitleFieldChrome.cursorColorToken.uiColor
        textField.adjustsFontForContentSizeCategory = true
        textField.returnKeyType = .next
        textField.delegate = context.coordinator
        textField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.textFieldTouchDown(_:)),
            for: .touchDown
        )
        textField.accessibilityIdentifier = "editor.page-title"
        return textField
    }

    func updateUIView(_ textField: UITextField, context: Context) {
        context.coordinator.parent = self
        textField.isEnabled = isEnabled
        textField.font = Self.titleFont(contentFont: contentFont)
        textField.tintColor = PageTitleFieldChrome.cursorColorToken.uiColor
        if !textField.isFirstResponder, textField.text != PageTitleDisplayPolicy.editingText(for: text) {
            textField.text = PageTitleDisplayPolicy.editingText(for: text)
        }
        context.coordinator.updatePlaceholder(for: textField)
        context.coordinator.handleFocusRequestIfNeeded(
            textField: textField,
            focusRequestID: focusRequestID
        )
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: PageTitleUIKitTextField
        private var handledFocusRequestID: UUID?
        private var scheduledFocusRequestID: UUID?

        init(parent: PageTitleUIKitTextField) {
            self.parent = parent
        }

        @objc func textFieldTouchDown(_ textField: UITextField) {
            parent.onInteractionBegan()
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            updatePlaceholder(for: textField)
            parent.onEditingBegan()
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            let title = textField.text ?? ""
            if title != parent.text {
                parent.text = title
            }
            parent.onEditingEnded()
            updatePlaceholder(for: textField)
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            let title = textField.text ?? ""
            if title != parent.text {
                parent.text = title
            }
            parent.onReturn()
            return false
        }

        func updatePlaceholder(for textField: UITextField) {
            textField.placeholder = PageTitleFieldChrome.placeholderText(
                isFocused: textField.isFirstResponder,
                text: textField.text ?? ""
            )
        }

        func handleFocusRequestIfNeeded(textField: UITextField, focusRequestID: UUID?) {
            guard let focusRequestID,
                  handledFocusRequestID != focusRequestID,
                  scheduledFocusRequestID != focusRequestID else {
                return
            }

            scheduledFocusRequestID = focusRequestID
            scheduleFocusAttempt(
                textField: textField,
                focusRequestID: focusRequestID,
                remainingAttempts: 24
            )
        }

        private func scheduleFocusAttempt(
            textField: UITextField,
            focusRequestID: UUID,
            remainingAttempts: Int
        ) {
            DispatchQueue.main.asyncAfter(deadline: .now() + focusDelay(for: remainingAttempts)) { [weak textField, weak self] in
                guard let textField, let self else {
                    return
                }

                if self.performFocus(textField: textField) {
                    self.scheduleFocusConfirmation(
                        textField: textField,
                        focusRequestID: focusRequestID,
                        remainingAttempts: remainingAttempts
                    )
                    return
                }

                guard remainingAttempts > 0 else {
                    self.finishFocusRequest(focusRequestID, didFocus: false)
                    EditorLog.focus.debug("page_title_focus_request_retry_exhausted")
                    return
                }

                self.scheduleFocusAttempt(
                    textField: textField,
                    focusRequestID: focusRequestID,
                    remainingAttempts: remainingAttempts - 1
                )
            }
        }

        private func performFocus(textField: UITextField) -> Bool {
            let didFocus = textField.window != nil && textField.becomeFirstResponder()
            if didFocus {
                textField.selectAll(nil)
            }
            return didFocus
        }

        private func scheduleFocusConfirmation(
            textField: UITextField,
            focusRequestID: UUID,
            remainingAttempts: Int
        ) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak textField, weak self] in
                guard let textField else {
                    return
                }
                guard let self else {
                    return
                }
                if textField.isFirstResponder {
                    self.finishFocusRequest(focusRequestID, didFocus: true)
                    return
                }

                guard remainingAttempts > 0 else {
                    self.finishFocusRequest(focusRequestID, didFocus: false)
                    EditorLog.focus.debug("page_title_focus_request_retry_exhausted")
                    return
                }

                self.scheduleFocusAttempt(
                    textField: textField,
                    focusRequestID: focusRequestID,
                    remainingAttempts: remainingAttempts - 1
                )
            }
        }

        private func finishFocusRequest(_ focusRequestID: UUID, didFocus: Bool) {
            if scheduledFocusRequestID == focusRequestID {
                scheduledFocusRequestID = nil
            }
            if didFocus {
                handledFocusRequestID = focusRequestID
            }
            parent.onFocusRequestFinished(didFocus)
        }

        private func focusDelay(for remainingAttempts: Int) -> DispatchTimeInterval {
            remainingAttempts == 24 ? .milliseconds(0) : .milliseconds(45)
        }
    }

    private static func titleFont(contentFont: EditorContentFont) -> UIFont {
        let size = CGFloat(EditorDesignTokens.Typography.documentTitleSize)
        if let postScriptName = contentFont.pageTitlePostScriptName,
           let font = UIFont(name: postScriptName, size: size) {
            return font
        }
        return UIFont.systemFont(ofSize: size, weight: .semibold)
    }
}
#endif

private struct EditorCanvasView: View {
    let page: PageSummary?
    let pages: [PageSummary]
    let blocks: [BlockSnapshot]
    let allBlocks: [BlockSnapshot]
    let attachments: [AttachmentSnapshot]
    let attachmentPreviewGenerationStatuses: [String: AttachmentPreviewGenerationStatus]
    let markdownImportStatusText: String?
    let backlinks: [Backlink]
    let externalLinks: [ExternalLink]
    let conflicts: [ConflictSnapshot]
    let outlineItems: [PageOutlineItem]
    let parentPageLink: PageParentLink?
    let pageTagNames: [String]
    var availableTags: [TagSummary] = []
    var selectedPageTagIDs: [String] = []
    let pendingFocusBlockID: String?
    var pendingSearchHighlight: SearchTransientHighlight? = nil
    var pendingFocusRequestID: UUID? = nil
    var pendingPageTitleFocusPageID: String? = nil
    let canUndoTextEdit: Bool
    let canRedoTextEdit: Bool
    var displayMode: EditorDisplayMode = .standard
    var showsAuxiliaryRail = true
    var isEncryptedContentLocked = false
    var isAuthenticatingEncryptedContent = false
    var onDisplayModeChange: (EditorDisplayMode) -> Void = { _ in }
    var onUnlockEncryptedContent: () -> Void = {}
    let onAddParagraphBlock: () -> String?
    let onAddPageReference: (String) -> Void
    let onAddBlockReference: (String) -> Void
    let onInsertMarkdownLink: (String, String, String) -> Bool
    let onInsertMarkdownLinkAtSelection: (String, String, String, EditorTextSelection) -> EditorTextSelection?
    let onRemoveMarkdownLinkAtSelection: (String, EditorTextSelection) -> EditorTextSelection?
    let onApplyMarkdownInlineFormat: (String, MarkdownInlineFormat, EditorTextSelection) -> EditorTextSelection?
    let onUndoTextEdit: () -> Void
    let onRedoTextEdit: () -> Void
    let onFocusCanvas: () -> String?
    let onMoveBlock: (String, Int) -> Void
    let onMoveBlocks: ([String], Int) -> Void
    let onUpdateBlockParent: (String, String?) -> Bool
    let onMoveBlockByKeyboard: (String, BlockKeyboardMoveDirection) -> Bool
    let onInsertBlockAfter: (String) -> Bool
    let onSplitTextBlockAtSelection: (String, EditorTextSelection) -> EditorTextSelection?
    let onReplaceTextAtSelection: (EditorTextSelection, String) -> EditorTextSelection?
    let onPasteTextAtSelection: (EditorTextSelection, String) -> EditorTextSelection?
    let onMergeTextBlockWithPrevious: (String, EditorTextSelection) -> EditorTextSelection?
    let onMergeTextBlockWithNext: (String, EditorTextSelection) -> EditorTextSelection?
    let onIndentBlock: (String) -> Bool
    let onOutdentBlock: (String) -> Bool
    let onDeleteBlock: (String) -> Void
    let onDeleteBlocks: ([String]) -> Bool
    let onSelectBacklink: (Backlink) -> Void
    let onSelectOutlineItem: (PageOutlineItem) -> Void
    let onOpenPageReference: (String) -> Void
    let onOpenParentPage: () -> Bool
    let onOpenBlockReference: (String, String) -> Void
    let onAcceptConflict: (ConflictSnapshot) -> Void
    let onAcceptAllConflicts: () -> Void
    let onAcceptLocalConflict: (ConflictSnapshot) -> Void
    let onAcceptAllLocalConflicts: () -> Void
    let onResolveConflictManually: (ConflictSnapshot, String) -> Void
    let onResolveAllConflictsManually: ([String: String]) -> Void
    let onPageTitleChange: (String) -> Void
    let onImportMarkdown: (URL) -> Void
    let onImportObsidianVault: (URL) -> Void
    let onExportMarkdown: () -> String
    let onExportMarkdownPackage: (URL) -> Void
    let onBlockTextChange: (String, String) -> Void
    let onTableRowsChange: (String, [[String]]) -> Void
    let onBlockTypeChange: (String, BlockType) -> Void
    let onConvertBlockToPage: (String) -> Void
    let onTaskItemCompletionChange: (String, Bool) -> Void
    let onCodeBlockLineWrappingChange: (String, Bool) -> Void
    let onToggleBlockExpansion: (String) -> Void
    let isToggleBlockExpanded: (String) -> Bool
    let onImportAttachment: (URL) -> Void
    let onImportAttachmentsAfterBlock: ([URL], String) -> Bool
    let onRetryAttachmentPreview: (String) -> Void
    let onRenameAttachmentImage: (String, String) -> Void
    let onAttachmentImageDisplayWidthChange: (String, Double) -> Void
    let onDrawingBlockDataChange: (String, Data) -> Void
    let onMobileRevealPageList: (() -> Void)?
    let onPendingBlockFocusHandled: () -> Void
    var onPendingPageTitleFocusHandled: () -> Void = {}
    var onRemoveTagFromSelectedPage: (String) -> Bool = { _ in false }
    var onCreateAndAssignTagToSelectedPage: (String) -> Bool = { _ in false }
    @State private var isAttachmentImporterPresented = false
    @State private var attachmentImporterAllowedContentTypes: [UTType] = [.image, .movie, .data, .item]
    @State private var pendingAttachmentImportAnchorBlockID: String?
    @State private var isMarkdownImporterPresented = false
    @State private var isObsidianVaultImporterPresented = false
    @State private var isMarkdownExporterPresented = false
    @State private var isInlineLinkPopoverPresented = false
    @State private var activeInlineLinkTarget: (blockID: String, selection: EditorTextSelection?)?
    @State private var inlineLinkLabel = ""
    @State private var inlineLinkURL = ""
    @State private var isEditingInlineLink = false
    @State private var markdownExportDocument = MarkdownFileDocument(text: "")
#if DEBUG
    @State private var uiTestMarkdownExportOutput: String?
#endif
    @StateObject private var editorSession = EditorSession()
    @State private var pendingFocusRequest: BlockFocusRequest?
    @State private var activeBlockDropTarget: BlockDropTarget?
    @State private var transientSelectionResetRequest = TransientSelectionResetRequest.none
    @State private var scrollMetricsTracker = EditorCanvasScrollMetricsTracker(pageID: nil, blockCount: 0)
    @State private var isAuxiliaryRailCollapsed = false
    @State private var isMobileOutlinePresented = false
    @State private var blockRowFrames: [String: CGRect] = [:]
#if os(macOS)
    @State private var desktopOutlineSelectedBlockID: String?
    @AppStorage(DesktopInlineOutlineUserPreference.appStorageKey)
    private var desktopOutlineUserPreferenceRawValue = DesktopInlineOutlineUserPreference.automatic.rawValue
    @State private var isDesktopOutlineTriggerHovered = false
    @State private var isDesktopOutlinePopoverHovered = false
    @State private var isDesktopOutlinePopoverPinned = false
#endif
    @State private var attachmentResizeHandleFrames: [String: CGRect] = [:]
    @State private var blockSelectionMarqueeStart: CGPoint?
    @State private var blockSelectionMarqueeCurrent: CGPoint?
    @State private var scheduledPageTitleFocusPageID: String?
    @State private var pageTitleFocusRequestID: UUID?
    @FocusState private var isPageTitleFocused: Bool
    @AppStorage(EditorContentFont.appStorageKey) private var contentFontRawValue = EditorContentFont.defaultRawValue
#if os(iOS)
    @State private var mobileNavigationTitleState = MobileNavigationTitleVisibilityState()
    @State private var isPageTitleInteractionActive = false
    @State private var isPageTitleFocusRequestActive = false
#endif

    var body: some View {
        if isEncryptedContentLocked {
            EncryptedPageLockedView(
                isAuthenticating: isAuthenticatingEncryptedContent,
                onUnlock: onUnlockEncryptedContent
            )
        } else {
            unlockedCanvasBody
        }
    }

    private var unlockedCanvasBody: some View {
        ZStack(alignment: .topTrailing) {
            GeometryReader { canvasProxy in
                ScrollViewReader { scrollProxy in
                    ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: CGFloat(EditorBlockChrome.blockSpacing)) {
                HStack(alignment: .center, spacing: 12) {
#if os(iOS)
                    PageTitleUIKitTextField(
                        text: pageTitleBinding,
                        focusRequestID: pageTitleFocusRequestID,
                        contentFont: contentFont,
                        isEnabled: page != nil,
                        onInteractionBegan: {
                            beginPageTitleInteraction()
                        },
                        onEditingBegan: {
                            beginPageTitleInteraction()
                        },
                        onEditingEnded: {
                            isPageTitleInteractionActive = false
                        },
                        onReturn: {
                            focusFirstEditableBlockFromPageTitle()
                        },
                        onFocusRequestFinished: { _ in
                            isPageTitleFocusRequestActive = false
                        }
                    )
                    .padding(.leading, CGFloat(EditorCanvasChromeLayout.pageTitleLeadingPadding))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(titleFrameReporter)
#else
                    TextField(PageTitleDisplayPolicy.emptyTitlePlaceholder, text: pageTitleBinding)
                        .textFieldStyle(.plain)
                        .font(pageTitleFont)
                        .foregroundStyle(EditorDesignTokens.Colors.primaryText.color)
                        .padding(.leading, CGFloat(EditorCanvasChromeLayout.pageTitleLeadingPadding))
                        .disabled(page == nil)
                        .focused($isPageTitleFocused)
                        .accessibilityIdentifier("editor.page-title")
                        .simultaneousGesture(
                            TapGesture().onEnded {
                                clearTransientSelections()
                            }
                        )
                        .onSubmit {
                            focusFirstEditableBlockFromPageTitle()
                        }
#endif

                    Spacer(minLength: 12)
                }

                if PageTagEditorVisibilityPolicy.isVisible(
                    selectedTagIDs: selectedPageTagIDs,
                    selectedTagNames: pageTagNames
                ) {
                    PageTagEditor(
                        availableTags: availableTags,
                        selectedTagIDs: selectedPageTagIDs,
                        selectedTagNames: pageTagNames,
                        onRemoveTag: onRemoveTagFromSelectedPage,
                        onCreateTag: onCreateAndAssignTagToSelectedPage
                    )
                    .padding(.leading, CGFloat(EditorCanvasChromeLayout.pageTitleLeadingPadding))
                }

                if isInlineLinkPopoverPresented {
                    inlineLinkPopover
                }

                if let markdownImportStatusText {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(StatusChrome.warningTextToken.color)

                        Text(markdownImportStatusText)
                            .font(.caption)
                            .foregroundStyle(EditorDesignTokens.Colors.secondaryText.color)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(StatusChrome.warningFillToken.color)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(StatusChrome.warningStrokeToken.color, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .accessibilityIdentifier("editor.markdown-import-status")
                }

#if DEBUG
                if let uiTestMarkdownExportOutput {
                    Text(uiTestMarkdownExportOutput)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("editor.markdown-export-test-output")
                        .accessibilityLabel(uiTestMarkdownExportOutput)
                        .accessibilityValue(uiTestMarkdownExportOutput)
                }

#endif

                let blockDragPayloadIndex = BlockDragPayloadIndex(blocks: blocks)
                ForEach(Array(blocks.enumerated()), id: \.element.id) { index, block in
                    let dragPayloadBlockIDs = blockDragPayloadIndex.payloadBlockIDs(rootBlockID: block.id)
                    let searchHighlight = pendingSearchHighlight?.blockID == block.id ? pendingSearchHighlight : nil

                    if index == 0 {
                        BlockDropSlot(
                            destinationBlockID: block.id,
                            slotKind: .before,
                            activeDropTarget: $activeBlockDropTarget,
                            destinationLevel: nestingLevel(for: block),
                            moveDroppedBlocks: moveDroppedBlocks
                        )
                    }

                    BlockRowView(
                        block: block,
                        attachment: attachment(for: block),
                        attachmentPreviewGenerationStatus: attachmentPreviewGenerationStatus(for: block),
                        searchHighlight: searchHighlight,
                        pageReferencePreviewText: PageReferencePreviewResolver.previewText(
                            targetPageID: block.pageReferenceTargetPageID,
                            blocks: allBlocks
                        ),
                        contentFont: contentFont,
                        editorSession: editorSession,
                        nestingLevel: nestingLevel(for: block),
                        listOrdinal: ListBlockOrdinalResolver.ordinal(for: block, at: index, in: blocks),
                        dragPayloadBlockIDs: dragPayloadBlockIDs,
                        canMoveUp: index > 0,
                        canMoveDown: index < blocks.count - 1,
                        isFocusModeActive: displayMode == .focus,
                        onToggleFocusMode: {
                            onDisplayModeChange(displayMode == .focus ? .standard : .focus)
                        },
                        onMoveUp: {
                            onMoveBlock(block.id, index - 1)
                        },
                        onMoveDown: {
                            onMoveBlock(block.id, index + 1)
                        },
                        onMoveByKeyboard: { direction in
                            onMoveBlockByKeyboard(block.id, direction)
                        },
                        onMoveFocusByKeyboard: { direction in
                            focusAdjacentBlock(from: block.id, direction: direction)
                        },
                        onExtendBlockSelectionByKeyboard: { direction in
                            extendBlockSelection(from: block.id, direction: direction)
                        },
                        onApplyInlineFormatByKeyboard: { format, selection in
                            applyMarkdownInlineFormat(format, selection: selection)
                        },
                        onInsertLinkByKeyboard: { selection in
                            presentInlineLinkInsertion(selection: selection)
                        },
                        onInsertBlockAfter: { selection in
                            if EmptyTextBlockReturnResolver.shouldDemoteToParagraph(
                                blockType: block.type,
                                text: block.textPlain
                            ) {
                                let nextSelection = EditorTextSelection(
                                    blockID: block.id,
                                    location: 0,
                                    length: 0
                                )
                                onBlockTypeChange(block.id, .paragraph)
                                pendingFocusRequest = BlockFocusRequest(
                                    blockID: block.id,
                                    selection: nextSelection
                                )
                                return nextSelection
                            }
                            guard let nextSelection = onSplitTextBlockAtSelection(block.id, selection) else {
                                return nil
                            }
                            pendingFocusRequest = BlockFocusRequest(
                                blockID: nextSelection.blockID,
                                selection: nextSelection
                            )
                            return nextSelection
                        },
                        onReplaceTextAtSelection: { selection, replacementText in
                            guard let nextSelection = onReplaceTextAtSelection(selection, replacementText) else {
                                return nil
                            }
                            pendingFocusRequest = BlockFocusRequest(
                                blockID: nextSelection.blockID,
                                selection: nextSelection
                            )
                            return nextSelection
                        },
                        onPasteTextAtSelection: { selection, pasteText in
                            guard let nextSelection = onPasteTextAtSelection(selection, pasteText) else {
                                return nil
                            }
                            pendingFocusRequest = BlockFocusRequest(
                                blockID: nextSelection.blockID,
                                selection: nextSelection
                            )
                            return nextSelection
                        },
                        onMergeBlockWithPrevious: { selection in
                            guard let nextSelection = onMergeTextBlockWithPrevious(block.id, selection) else {
                                return false
                            }
                            pendingFocusRequest = BlockFocusRequest(
                                blockID: nextSelection.blockID,
                                selection: nextSelection
                            )
                            return true
                        },
                        onMergeBlockWithNext: { selection in
                            guard let nextSelection = onMergeTextBlockWithNext(block.id, selection) else {
                                return false
                            }
                            pendingFocusRequest = BlockFocusRequest(
                                blockID: nextSelection.blockID,
                                selection: nextSelection
                            )
                            return true
                        },
                        onIndent: {
                            applyBlockIndentation(.indent, fallbackBlockID: block.id)
                        },
                        onOutdent: {
                            applyBlockIndentation(.outdent, fallbackBlockID: block.id)
                        },
                        onPasteAttachmentURLs: { urls in
                            guard !urls.isEmpty else {
                                return false
                            }
                            return onImportAttachmentsAfterBlock(urls, block.id)
                        },
                        onDelete: {
                            deleteBlockForCommand(fallbackBlockID: block.id)
                        },
                        canUndoTextEdit: canUndoTextEdit,
                        onUndoTextEdit: onUndoTextEdit,
                        onOpenPageReference: { targetPageID in
                            onOpenPageReference(targetPageID)
                        },
                        onOpenBlockReference: { targetPageID, targetBlockID in
                            onOpenBlockReference(targetPageID, targetBlockID)
                        },
                        onChangeType: { type in
                            onBlockTypeChange(block.id, type)
                        },
                        onConvertToPage: {
                            onConvertBlockToPage(block.id)
                        },
                        onTaskItemCompletionChange: { isCompleted in
                            onTaskItemCompletionChange(block.id, isCompleted)
                        },
                        onCodeBlockLineWrappingChange: { isWrapped in
                            onCodeBlockLineWrappingChange(block.id, isWrapped)
                        },
                        onToggleBlockExpansion: {
                            onToggleBlockExpansion(block.id)
                        },
                        onRetryAttachmentPreview: { attachmentID in
                            onRetryAttachmentPreview(attachmentID)
                        },
                        onRenameAttachmentImage: { name in
                            onRenameAttachmentImage(block.id, name)
                        },
                        onAttachmentImageDisplayWidthChange: { displayWidth in
                            onAttachmentImageDisplayWidthChange(block.id, displayWidth)
                        },
                        onRequestAttachmentImport: { type in
                            requestAttachmentImport(afterBlockID: block.id, type: type)
                        },
                        onCreateDrawingBlock: {
                            createDrawingBlock(afterBlockID: block.id)
                        },
                        onDrawingDataChange: { data in
                            onDrawingBlockDataChange(block.id, data)
                        },
                        isToggleBlockExpanded: isToggleBlockExpanded(block.id),
                        isMobileOutlinePresented: isMobileOutlinePresented,
                        onRevealPageList: {
#if os(iOS)
                            revealMobilePageList()
#endif
                        },
                        onRevealOutline: {
#if os(iOS)
                            revealMobileOutline()
#endif
                        },
                        onCloseOutline: {
#if os(iOS)
                            closeMobileOutline()
#endif
                        },
                        isMobileSelectionModeActive: !editorSession.selectedBlockIDs.isEmpty,
                        isBlockSelected: editorSession.selectedBlockIDs.contains(block.id),
                        selectionResetRequest: transientSelectionResetRequest,
                        dropPlacement: activeBlockDropTarget?.blockID == block.id ? activeBlockDropTarget?.placement : nil,
                        focusRequestID: pendingFocusRequest?.blockID == block.id ? pendingFocusRequest?.id : nil,
                        focusSelection: pendingFocusRequest?.blockID == block.id ? pendingFocusRequest?.selection : nil,
                        onFocusRequestHandled: {
                            let didHandlePendingRequest = pendingFocusRequest?.blockID == block.id
                            if didHandlePendingRequest {
                                pendingFocusRequest = nil
                                EditorLog.focus.debug(
                                    "editor_focus_request_handled block_id=\(block.id, privacy: .public)"
                                )
                            }
                            if pendingFocusBlockID == block.id {
                                onPendingBlockFocusHandled()
                            }
                        },
                        onSelectCurrentBlock: {
                            editorSession.selectBlocks([block.id])
                        },
                        onToggleBlockSelection: {
                            editorSession.selectBlocks(
                                MobileBlockSelectionReducer.selectionAfterSelecting(
                                    blockID: block.id,
                                    current: editorSession.selectedBlockIDs
                                )
                            )
                        },
                        onSelectAllBlocksByKeyboard: {
                            let blockIDs = Set(blocks.map(\.id))
                            guard !blockIDs.isEmpty else {
                                return false
                            }
                            editorSession.selectBlocks(blockIDs)
                            return true
                        },
                        onClearDropTarget: {
                            activeBlockDropTarget = BlockDropTargetLifecycleReducer
                                .targetAfterEditorInteraction(current: activeBlockDropTarget)
                        },
                        onClearTransientSelections: { excludingBlockID in
                            clearTransientSelections(excludingBlockID: excludingBlockID)
                        },
                        onTableRowsChange: { rows in
                            onTableRowsChange(block.id, rows)
                        }
                    ) { text in
                        onBlockTextChange(block.id, text)
                    }
                    .id(block.id)
                    .background(blockSelectionFrameReporter(block.id))
                    .onAppear {
                        scheduleVisibleBlockAppeared(block.id, index: index)
                    }
                    .onDisappear {
                        scheduleVisibleBlockDisappeared(block.id)
                    }
#if os(iOS)
                    .modifier(
                        MobileBlockRowDropTargetModifier(
                            isEnabled: MobileBlockDragActivationPolicy.usesWholeRowDropTarget,
                            destinationBlockID: block.id,
                            activeDropTarget: $activeBlockDropTarget,
                            destinationLevel: nestingLevel(for: block),
                            moveDroppedBlocks: moveDroppedBlocks
                        )
                    )
#endif

                    BlockDropSlot(
                        destinationBlockID: block.id,
                        slotKind: .after,
                        activeDropTarget: $activeBlockDropTarget,
                        destinationLevel: nestingLevel(for: block),
                        moveDroppedBlocks: moveDroppedBlocks
                    )
                }

                if !blocks.isEmpty {
                    CanvasTrailingInsertRegion {
                        focusCanvas()
                    }
                }

                if !conflicts.isEmpty {
                    ConflictPanel(
                        conflicts: conflicts,
                        onAcceptConflict: onAcceptConflict,
                        onAcceptAllConflicts: onAcceptAllConflicts,
                        onAcceptLocalConflict: onAcceptLocalConflict,
                        onAcceptAllLocalConflicts: onAcceptAllLocalConflicts,
                        onResolveManually: onResolveConflictManually,
                        onResolveAllManually: onResolveAllConflictsManually
                    )
                }

                CanvasTailFocusRegion(isEmpty: blocks.isEmpty) {
                    focusCanvas()
                } onMoveDroppedBlocksToEnd: { draggedBlockIDs in
                    activeBlockDropTarget = BlockDropTargetLifecycleReducer
                        .targetAfterDragEnded(current: activeBlockDropTarget)
                    return moveDroppedBlocksToEnd(draggedBlockIDs)
                }
            }
            .frame(
                width: EditorCanvasWidthPolicy.editorColumnWidth(
                    containerWidth: canvasProxy.size.width,
                    horizontalPadding: CGFloat(EditorCanvasChromeLayout.horizontalPadding),
                    editorMaxWidth: activeEditorMaxWidth
                ),
                alignment: .leading
            )
            .padding(.horizontal, CGFloat(EditorCanvasChromeLayout.horizontalPadding))
            .padding(.vertical, CGFloat(EditorCanvasChromeLayout.verticalPadding))
            .frame(width: canvasProxy.size.width, alignment: .center)
            }
            .accessibilityIdentifier("editor.canvas-scroll")
#if os(iOS)
            .scrollDismissesKeyboard(.interactively)
#endif
            .coordinateSpace(name: EditorCanvasCoordinateSpace.blockSelection)
            .onPreferenceChange(BlockRowFramePreferenceKey.self) { frames in
#if os(macOS)
                if blockRowFrames != frames {
                    desktopOutlineSelectedBlockID = nil
                }
#endif
                blockRowFrames = frames
            }
            .onPreferenceChange(AttachmentResizeHandleFramePreferenceKey.self) { frames in
                attachmentResizeHandleFrames = frames
            }
#if os(iOS)
            .onPreferenceChange(MobilePageTitleFramePreferenceKey.self) { frame in
                updateMobileNavigationTitleVisibility(titleFrame: frame)
            }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y
            } action: { _, offsetY in
                updateMobileNavigationTitleVisibility(scrollOffsetY: offsetY)
            }
#endif
            .overlay(alignment: .topLeading) {
                if let blockSelectionMarqueeRect {
                    BlockSelectionMarqueeOverlay(rect: blockSelectionMarqueeRect)
                }
            }
#if os(macOS)
            .simultaneousGesture(blockSelectionMarqueeGesture())
#elseif os(iOS)
            .simultaneousGesture(
                blockSelectionMarqueeGesture(
                    isEnabled: MobileBlockSelectionDragPolicy.isEnabled(
                        isSelectionModeActive: !editorSession.selectedBlockIDs.isEmpty
                    )
                )
            )
#endif
            .onChange(of: editorSession.focusedBlockID) { _, _ in
                activeBlockDropTarget = BlockDropTargetLifecycleReducer
                    .targetAfterEditorInteraction(current: activeBlockDropTarget)
            }
#if DEBUG
            .overlay(alignment: .topLeading) {
                scrollMetricsDebugProbe
            }
#endif
#if os(macOS)
            .overlay {
                GeometryReader { proxy in
                    desktopInlineOutlineLayer(containerSize: proxy.size)
                }
            }
#endif
            .onAppear {
                scrollToPendingFocusBlockIfNeeded(pendingFocusBlockID, proxy: scrollProxy)
            }
            .onChange(of: page?.id) { _, _ in
                scrollToPendingFocusBlockIfNeeded(pendingFocusBlockID, proxy: scrollProxy)
            }
            .onChange(of: pendingFocusBlockID) { _, blockID in
                scrollToPendingFocusBlockIfNeeded(blockID, proxy: scrollProxy)
            }
            .onChange(of: pendingFocusRequestID) { _, _ in
                scrollToPendingFocusBlockIfNeeded(pendingFocusBlockID, proxy: scrollProxy)
            }
                }
            }
#if os(macOS)
            macCanvasToolbar
                .padding(.top, 24)
                .padding(.trailing, macCanvasToolbarTrailingPadding)
#endif
#if os(iOS)
            mobileOutlineDrawerLayer
#endif
        }
        .background(EditorDesignTokens.Colors.editorBackground.color)
#if os(iOS)
        .coordinateSpace(name: EditorCanvasCoordinateSpace.mobileNavigationTitle)
#endif
#if os(iOS)
        .safeAreaInset(edge: .bottom) {
            if !editorSession.selectedBlockIDs.isEmpty {
                MobileBlockSelectionToolbar(
                    selectedCount: editorSession.selectedBlockIDs.count,
                    onClear: {
                        editorSession.clearBlockSelection()
                    },
                    onOutdent: {
                        applySelectedBlocksIndentation(.outdent)
                    },
                    onIndent: {
                        applySelectedBlocksIndentation(.indent)
                    },
                    onDelete: {
                        deleteSelectedBlocks()
                    }
                )
            }
        }
#endif
#if os(macOS)
        .background(
            DropTargetCleanupEventBridge(isEnabled: activeBlockDropTarget != nil) {
                activeBlockDropTarget = BlockDropTargetLifecycleReducer
                    .targetAfterDragEnded(current: activeBlockDropTarget)
            }
            .frame(width: 0, height: 0)
        )
        .onPasteCommand(of: [.fileURL, .png, .jpeg, .tiff]) { _ in
            let attachmentURLs = MacPasteboardAttachmentResolver.attachmentURLs(from: .general)
            _ = importPastedAttachments(attachmentURLs)
        }
#endif
#if os(macOS)
        .background(
            MacEditorKeyboardShortcutBridge(
                onInsertLink: {
                    presentInlineLinkInsertionFromKeyboardShortcut()
                },
                onPasteAttachments: {
                    let attachmentURLs = MacPasteboardAttachmentResolver.attachmentURLs(from: .general)
                    return importPastedAttachments(attachmentURLs)
                },
                hasBlockSelection: {
                    !editorSession.selectedBlockIDs.isEmpty
                },
                onCancelSelection: {
                    let hadBlockSelection = !editorSession.selectedBlockIDs.isEmpty
                    editorSession.clearBlockSelection()
                    return hadBlockSelection
                },
                onCopySelection: {
                    copySelectedBlocksToPasteboard()
                },
                onMoveFocus: { direction in
                    guard let blockID = BlockSelectionKeyboardAnchorResolver.anchorBlockID(
                        selectedBlockIDs: editorSession.selectedBlockIDs,
                        visibleBlockIDs: blocks.map(\.id)
                    ) else {
                        return false
                    }

                    return focusAdjacentBlock(
                        from: blockID,
                        direction: direction,
                        clearsBlockSelection: true
                    )
                },
                onExtendBlockSelection: { direction in
                    guard let blockID = BlockSelectionKeyboardAnchorResolver.anchorBlockID(
                        selectedBlockIDs: editorSession.selectedBlockIDs,
                        visibleBlockIDs: blocks.map(\.id)
                    ) else {
                        return false
                    }

                    return extendBlockSelection(from: blockID, direction: direction)
                },
                onIndentSelection: { direction in
                    applySelectedBlocksIndentation(direction)
                },
                onDeleteSelection: {
                    deleteSelectedBlocks()
                },
                onUndoEdit: {
                    guard canUndoTextEdit else {
                        return false
                    }
                    onUndoTextEdit()
                    return true
                },
                onRedoEdit: {
                    guard canRedoTextEdit else {
                        return false
                    }
                    onRedoTextEdit()
                    return true
                },
                onSelectFocusedCodeText: { textView in
                    let identifier = textView.accessibilityIdentifier()
                    guard identifier.hasPrefix("editor.text.") else {
                        return false
                    }

                    let blockID = String(identifier.dropFirst("editor.text.".count))
                    guard let block = blocks.first(where: { $0.id == blockID }),
                          block.type == .codeBlock else {
                        return false
                    }

                    let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
                    textView.setSelectedRange(fullRange)
                    editorSession.updateSelection(
                        blockID: blockID,
                        location: fullRange.location,
                        length: fullRange.length
                    )
                    editorSession.clearBlockSelection()
                    return true
                },
                onPromoteBlockToPage: {
                    promoteCurrentBlockToPageFromKeyboard()
                }
            )
        )
#elseif os(iOS)
        .background(
            IOSEditorKeyboardShortcutBridge(
                isPasteEnabled: IOSEditorKeyboardShortcutBridgeActivationResolver.capturesPaste(
                    hasFocusedTextBlock: editorSession.focusedBlockID != nil || pendingFocusRequest != nil,
                    hasCurrentPage: page != nil,
                    hasFocusedPageTitle: isPageTitleFocusActive
                ),
                isFocusMoveEnabled: IOSEditorKeyboardShortcutBridgeActivationResolver.capturesFocusMove(
                    hasBlockSelection: !editorSession.selectedBlockIDs.isEmpty
                ),
                onPasteAttachments: {
                    let attachmentURLs = IOSPasteboardAttachmentResolver.attachmentURLs(from: .general)
                    return importPastedAttachments(attachmentURLs)
                },
                onMoveFocus: { direction in
                    guard let blockID = BlockSelectionKeyboardAnchorResolver.anchorBlockID(
                        selectedBlockIDs: editorSession.selectedBlockIDs,
                        visibleBlockIDs: blocks.map(\.id)
                    ) else {
                        return false
                    }

                    return focusAdjacentBlock(
                        from: blockID,
                        direction: direction,
                        clearsBlockSelection: true
                    )
                }
            )
            .frame(width: 0, height: 0)
        )
#endif
#if os(iOS)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                mobileNavigationTitleView
            }

            ToolbarItem(placement: .topBarTrailing) {
                pageActionsMenu
            }
        }
        .toolbarBackground(EditorDesignTokens.Colors.editorBackground.color, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
#else
        .navigationTitle("")
#endif
        .focusedValue(\.insertMarkdownLinkAction, insertMarkdownLinkAction)
        .focusedValue(\.promoteDiarySelectionAction, promoteCurrentBlockToPageAction)
        .focusedValue(\.openParentPageAction, openParentPageAction)
        .onAppear {
            scheduleScrollMetricsReset()
            schedulePendingPageTitleFocusIfNeeded(pendingPageTitleFocusPageID)
            schedulePendingFocusIfNeeded(pendingFocusBlockID, requestID: pendingFocusRequestID)
            logRenderMetrics(reason: "appear")
        }
        .onChange(of: page?.id) { _, _ in
#if os(iOS)
            resetMobileNavigationTitleVisibility()
            isPageTitleInteractionActive = false
            isPageTitleFocusRequestActive = false
#elseif os(macOS)
            desktopOutlineSelectedBlockID = nil
            isDesktopOutlineTriggerHovered = false
            isDesktopOutlinePopoverHovered = false
            isDesktopOutlinePopoverPinned = false
#endif
            scheduledPageTitleFocusPageID = nil
            schedulePendingPageTitleFocusIfNeeded(pendingPageTitleFocusPageID)
            schedulePendingFocusIfNeeded(
                pendingFocusBlockID,
                requestID: pendingFocusRequestID,
                reason: .pageChanged
            )
        }
        .onChange(of: pendingPageTitleFocusPageID) { _, pageID in
            scheduledPageTitleFocusPageID = nil
            schedulePendingPageTitleFocusIfNeeded(pageID)
        }
        .onChange(of: pendingFocusBlockID) { _, blockID in
            schedulePendingFocusIfNeeded(blockID, requestID: pendingFocusRequestID)
        }
        .onChange(of: pendingFocusRequestID) { _, requestID in
            schedulePendingFocusIfNeeded(pendingFocusBlockID, requestID: requestID)
        }
        .onChange(of: renderMetrics) { _, _ in
            scheduleScrollMetricsReset()
            logRenderMetrics(reason: "change")
        }
        .fileImporter(
            isPresented: $isMarkdownImporterPresented,
            allowedContentTypes: MarkdownFileDocument.readableContentTypes,
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let sourceURL = urls.first {
                let isScoped = sourceURL.startAccessingSecurityScopedResource()
                defer {
                    if isScoped {
                        sourceURL.stopAccessingSecurityScopedResource()
                    }
                }
                onImportMarkdown(sourceURL)
            }
        }
        .fileImporter(
            isPresented: $isObsidianVaultImporterPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let sourceURL = urls.first {
                let isScoped = sourceURL.startAccessingSecurityScopedResource()
                defer {
                    if isScoped {
                        sourceURL.stopAccessingSecurityScopedResource()
                    }
                }
                onImportObsidianVault(sourceURL)
            }
        }
        .fileExporter(
            isPresented: $isMarkdownExporterPresented,
            document: markdownExportDocument,
            contentType: MarkdownFileDocument.markdownContentType,
            defaultFilename: "\(page?.title ?? "页面").md"
        ) { result in
            switch result {
            case .success(let destinationURL):
                onExportMarkdownPackage(destinationURL)
            case .failure(let error):
                EditorLog.markdown.error(
                    "markdown_file_export_failed error=\(String(describing: error), privacy: .public)"
                )
            }
        }
        .fileImporter(
            isPresented: $isAttachmentImporterPresented,
            allowedContentTypes: attachmentImporterAllowedContentTypes,
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let sourceURL = urls.first {
                let isScoped = sourceURL.startAccessingSecurityScopedResource()
                defer {
                    if isScoped {
                        sourceURL.stopAccessingSecurityScopedResource()
                    }
                }
                importAttachment(sourceURL)
            } else {
                pendingAttachmentImportAnchorBlockID = nil
            }
        }
    }

    private var pageTitleBinding: Binding<String> {
        Binding {
            page?.title ?? ""
        } set: { title in
            onPageTitleChange(title)
        }
    }

    private func schedulePendingPageTitleFocusIfNeeded(_ pageID: String?) {
        guard let pageID,
              pageID == page?.id else {
            return
        }
        guard scheduledPageTitleFocusPageID != pageID else {
            return
        }

        scheduledPageTitleFocusPageID = pageID
#if os(iOS)
        let retryDelays = PageTitleFocusSchedulingPolicy.compactRetryDelays
#else
        let retryDelays = PageTitleFocusSchedulingPolicy.regularRetryDelays
#endif
        for (index, delay) in retryDelays.enumerated() {
            let isLastAttempt = index == retryDelays.count - 1
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard PageTitleFocusSchedulingPolicy.shouldRunScheduledAttempt(
                    scheduledPageID: scheduledPageTitleFocusPageID,
                    requestedPageID: pageID,
                    currentPageID: page?.id
                ) else {
                    return
                }
                prepareTitleFocusAttempt()
#if os(iOS)
                isPageTitleFocusRequestActive = true
                pageTitleFocusRequestID = UUID()
#else
                isPageTitleFocused = true
#endif
                if isLastAttempt {
                    scheduledPageTitleFocusPageID = nil
                    onPendingPageTitleFocusHandled()
                }
            }
        }
    }

    private func prepareTitleFocusAttempt() {
        pendingFocusRequest = nil
        if let focusedBlockID = editorSession.focusedBlockID {
            editorSession.endEditing(blockID: focusedBlockID)
        }
#if os(iOS)
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
#elseif os(macOS)
        NSApp.keyWindow?.makeFirstResponder(nil)
#endif
    }

#if os(iOS)
    private var isPageTitleFocusActive: Bool {
        isPageTitleInteractionActive ||
            isPageTitleFocusRequestActive ||
            scheduledPageTitleFocusPageID != nil ||
            pendingPageTitleFocusPageID == page?.id
    }

    private func beginPageTitleInteraction() {
        isPageTitleInteractionActive = true
        isPageTitleFocusRequestActive = false
        pendingFocusRequest = nil
        if let focusedBlockID = editorSession.focusedBlockID {
            editorSession.endEditing(blockID: focusedBlockID)
        }
        clearTransientSelectionsAfterPageTitleFocusIfNeeded()
    }
#endif

    private var contentFont: EditorContentFont {
        EditorContentFont(rawValue: contentFontRawValue) ?? EditorContentFont.defaultFont
    }

    private var pageTitleFont: Font {
        if let postScriptName = contentFont.pageTitlePostScriptName {
            return .custom(postScriptName, size: EditorDesignTokens.Typography.documentTitleSize)
        }
        return .system(size: EditorDesignTokens.Typography.documentTitleSize, weight: .semibold)
    }

#if os(iOS)
    @ViewBuilder
    private var mobileNavigationTitleView: some View {
        if mobileNavigationTitleState.isVisible {
            Text(page?.title ?? "")
                .font(.headline)
                .foregroundStyle(EditorDesignTokens.Colors.primaryText.color)
                .lineLimit(1)
                .offset(y: MobileNavigationBarChrome.collapsedTitleVerticalOffset)
                .accessibilityIdentifier("editor.mobile-navigation-title")
        }
    }

    private func resetMobileNavigationTitleVisibility() {
        let nextState = MobileNavigationTitleVisibilityState()
        if mobileNavigationTitleState != nextState {
            mobileNavigationTitleState = nextState
        }
    }

    private func updateMobileNavigationTitleVisibility(
        titleFrame: CGRect? = nil,
        scrollOffsetY: CGFloat? = nil
    ) {
        let nextState = mobileNavigationTitleState.updated(
            titleFrame: titleFrame,
            scrollOffsetY: scrollOffsetY,
            topMaskHeight: MobileNavigationBarChrome.topMaskHeight
        )
        if mobileNavigationTitleState != nextState {
            mobileNavigationTitleState = nextState
        }
    }

    private var titleFrameReporter: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: MobilePageTitleFramePreferenceKey.self,
                value: proxy.frame(in: .named(EditorCanvasCoordinateSpace.mobileNavigationTitle))
            )
        }
    }
#endif

    private var pageReferenceTargets: [PageSummary] {
        pages.filter { targetPage in
            targetPage.id != page?.id
        }
    }

    private var shouldShowAuxiliaryRail: Bool {
        showsAuxiliaryRail
            && displayMode.showsAuxiliaryRail
            && (!outlineItems.isEmpty || !backlinks.isEmpty || !externalLinks.isEmpty)
    }

    private var shouldOfferAuxiliaryRail: Bool {
        DesktopAuxiliaryRailButtonPolicy.isOffered(
            showsAuxiliaryRail: showsAuxiliaryRail,
            displayMode: displayMode
        )
    }

    private var shouldReserveAuxiliaryRailSpace: Bool {
        shouldShowAuxiliaryRail && !isAuxiliaryRailCollapsed
    }

    private var activeEditorMaxWidth: CGFloat {
        CGFloat(
            EditorCanvasWidthPolicy.maxWidth(
                hasVisibleAuxiliaryRail: shouldReserveAuxiliaryRailSpace
            )
        )
    }

#if os(macOS)
    private var desktopOutlineUserPreference: DesktopInlineOutlineUserPreference {
        DesktopInlineOutlineUserPreference(rawValue: desktopOutlineUserPreferenceRawValue) ?? .automatic
    }

    @ViewBuilder
    private func desktopInlineOutlineLayer(containerSize: CGSize) -> some View {
        let horizontalPadding = CGFloat(EditorCanvasChromeLayout.horizontalPadding)
        let leadingGap = DesktopInlineOutlinePlacementPolicy.leadingGap(
            containerWidth: containerSize.width,
            horizontalPadding: horizontalPadding,
            editorMaxWidth: activeEditorMaxWidth
        )
        let presentation = DesktopInlineOutlinePlacementPolicy.presentation(
            outlineItemCount: outlineItems.count,
            leadingGap: leadingGap,
            userPreference: desktopOutlineUserPreference
        )
        let canExpand = DesktopInlineOutlinePlacementPolicy.canExpand(leadingGap: leadingGap)
        let topOffset = DesktopInlineOutlinePlacementPolicy.topOffset(containerHeight: containerSize.height)
        let shouldShowPopover = !canExpand
            && (isDesktopOutlineTriggerHovered || isDesktopOutlinePopoverHovered || isDesktopOutlinePopoverPinned)

        ZStack(alignment: .topLeading) {
            if presentation != .hidden {
                if presentation == .expanded {
                    DesktopInlineOutline(
                        outlineItems: outlineItems,
                        activeBlockID: desktopOutlineActiveBlockID,
                        style: .inline,
                        onSelectOutlineItem: selectDesktopOutlineItem,
                        onCollapse: collapseDesktopInlineOutline
                    )
                    .offset(
                        x: DesktopInlineOutlinePlacementPolicy.xOffset(
                            leadingGap: leadingGap,
                            presentation: .expanded
                        ),
                        y: topOffset
                    )
                } else {
                    DesktopInlineOutlineTriggerButton(
                        isPopoverPresented: shouldShowPopover,
                        onToggle: {
                            toggleDesktopInlineOutlineTrigger(leadingGap: leadingGap)
                        },
                        onHoverChange: { isHovering in
                            isDesktopOutlineTriggerHovered = isHovering
                        }
                    )
                    .offset(
                        x: DesktopInlineOutlinePlacementPolicy.xOffset(
                            leadingGap: leadingGap,
                            presentation: .collapsed
                        ),
                        y: topOffset
                    )

                    if shouldShowPopover {
                        DesktopInlineOutline(
                            outlineItems: outlineItems,
                            activeBlockID: desktopOutlineActiveBlockID,
                            style: .popover,
                            onSelectOutlineItem: selectDesktopOutlineItem,
                            onCollapse: nil
                        )
                        .onHover { isHovering in
                            isDesktopOutlinePopoverHovered = isHovering
                        }
                        .offset(
                            x: DesktopInlineOutlinePlacementPolicy.popoverXOffset(leadingGap: leadingGap),
                            y: topOffset
                        )
                    }
                }
            }
        }
        .frame(width: containerSize.width, height: containerSize.height, alignment: .topLeading)
    }

    private var desktopOutlineActiveBlockID: String? {
        DesktopInlineOutlineActiveHeadingResolver.activeBlockID(
            outlineItems: outlineItems,
            visibleBlockFrames: blockRowFrames,
            blockIDsInDocumentOrder: blocks.map(\.id),
            selectedBlockID: desktopOutlineSelectedBlockID,
            focusedBlockID: pendingFocusRequest?.blockID ?? pendingFocusBlockID ?? editorSession.focusedBlockID
        )
    }

    private func selectDesktopOutlineItem(_ item: PageOutlineItem) {
        desktopOutlineSelectedBlockID = item.blockID
        isDesktopOutlinePopoverPinned = false
        isDesktopOutlineTriggerHovered = false
        onSelectOutlineItem(item)
    }

    private func collapseDesktopInlineOutline() {
        desktopOutlineUserPreferenceRawValue = DesktopInlineOutlineUserPreference.collapsed.rawValue
        isDesktopOutlinePopoverPinned = false
    }

    private func toggleDesktopInlineOutlineTrigger(leadingGap: CGFloat) {
        switch DesktopInlineOutlineTogglePolicy.triggerAction(leadingGap: leadingGap) {
        case let .persist(preference):
            desktopOutlineUserPreferenceRawValue = preference.rawValue
            isDesktopOutlinePopoverPinned = false
        case .togglePopover:
            isDesktopOutlinePopoverPinned.toggle()
        }
    }

    private var macCanvasToolbarTrailingPadding: CGFloat {
        if shouldReserveAuxiliaryRailSpace {
            return CGFloat(EditorDesignTokens.Layout.auxiliaryRailWidth + 24)
        }
        return 28
    }

    private var macCanvasToolbar: some View {
        HStack(spacing: 10) {
            pageActionsMenu

            if shouldOfferAuxiliaryRail {
                Button {
                    isAuxiliaryRailCollapsed.toggle()
                } label: {
                    Image(systemName: "sidebar.right")
                        .font(.callout.weight(.medium))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundStyle(EditorDesignTokens.Colors.tertiaryText.color.opacity(0.78))
                .help(shouldReserveAuxiliaryRailSpace ? "收起右侧栏" : "展开右侧栏")
                .accessibilityLabel(shouldReserveAuxiliaryRailSpace ? "收起右侧栏" : "展开右侧栏")
                .accessibilityIdentifier(shouldReserveAuxiliaryRailSpace ? "editor.auxiliary-rail.collapse" : "editor.auxiliary-rail.expand")
                .focusable(false)
            }
        }
    }
#endif

#if os(iOS)
    private var mobileOutlineCloseGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onEnded { value in
                let horizontalDistance = value.translation.width
                guard horizontalDistance > 56,
                      horizontalDistance > abs(value.translation.height) * 1.25 else {
                    return
                }
                closeMobileOutline()
            }
    }

    @ViewBuilder
    private var mobileOutlineDrawerLayer: some View {
        if isMobileOutlinePresented {
            GeometryReader { proxy in
                ZStack(alignment: .trailing) {
                    EditorDesignTokens.Colors.shadow.color.opacity(0.22)
                        .ignoresSafeArea()
                        .onTapGesture {
                            closeMobileOutline()
                        }

                    MobileOutlineDrawer(
                        outlineItems: outlineItems,
                        onSelectOutlineItem: { item in
                            closeMobileOutline()
                            onSelectOutlineItem(item)
                        },
                        onClose: {
                            closeMobileOutline()
                        }
                    )
                    .frame(width: min(proxy.size.width * 0.82, 340))
                    .frame(maxHeight: .infinity, alignment: .top)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(EditorDesignTokens.Colors.border.color.opacity(0.68), lineWidth: 1)
                    )
                    .shadow(color: EditorDesignTokens.Colors.shadow.color.opacity(0.18), radius: 28, x: -10, y: 0)
                    .padding(.vertical, 16)
                    .padding(.trailing, 10)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .accessibilityIdentifier("editor.mobile-outline-drawer")
                }
                .contentShape(Rectangle())
                .highPriorityGesture(mobileOutlineCloseGesture)
            }
        }
    }
#endif

    private var pageActionsMenu: some View {
        Menu {
            Section("视图") {
                Button {
                    onDisplayModeChange(displayMode == .writing ? .standard : .writing)
                } label: {
                    Label(displayMode == .writing ? "退出写作模式" : "写作模式", systemImage: "sidebar.trailing")
                }

                Button {
                    onDisplayModeChange(displayMode == .focus ? .standard : .focus)
                } label: {
                    Label(displayMode == .focus ? "退出专注模式" : "专注模式", systemImage: "rectangle.center.inset.filled")
                }
            }

            Section("块") {
                Button {
                    _ = onAddParagraphBlock()
                } label: {
                    Label("新增文本块", systemImage: "plus")
                }
                .accessibilityIdentifier("editor.add-block")

                Menu {
                    ForEach(pageReferenceTargets) { targetPage in
                        Button {
                            onAddPageReference(targetPage.id)
                        } label: {
                            Label(targetPage.title, systemImage: "doc.text")
                        }
                    }
                } label: {
                    Label("页面引用", systemImage: "doc.badge.plus")
                }
                .disabled(pageReferenceTargets.isEmpty)

                Menu {
                    ForEach(blockReferenceTargets) { targetBlock in
                        Button {
                            onAddBlockReference(targetBlock.id)
                        } label: {
                            Label(blockReferenceTitle(for: targetBlock), systemImage: "text.quote")
                        }
                    }
                } label: {
                    Label("块引用", systemImage: "text.badge.plus")
                }
                .disabled(blockReferenceTargets.isEmpty)

                Button {
                    handleAttachmentImportButton()
                } label: {
                    Label("附件", systemImage: "paperclip")
                }
                .disabled(page == nil)
                .accessibilityIdentifier("editor.insert-attachment")
            }

            Section("文本") {
                Menu {
                    ForEach(EditorContentFont.allCases) { font in
                        Button {
                            contentFontRawValue = font.rawValue
                        } label: {
                            Label(
                                font.displayName,
                                systemImage: contentFont == font ? "checkmark" : "textformat"
                            )
                        }
                    }
                } label: {
                    Label("正文字体", systemImage: "textformat")
                }
                .accessibilityIdentifier("editor.content-font-menu")

                Button {
                    _ = presentInlineLinkInsertionFromCurrentTarget()
                } label: {
                    Label("链接", systemImage: "link")
                }
                .disabled(inlineLinkToolbarTargetBlockID == nil)

                Button {
                    applyMarkdownInlineFormat(.bold)
                } label: {
                    Label("加粗", systemImage: "bold")
                }
                .disabled(inlineFormatTarget == nil)

                Button {
                    applyMarkdownInlineFormat(.italic)
                } label: {
                    Label("斜体", systemImage: "italic")
                }
                .disabled(inlineFormatTarget == nil)

                Button {
                    applyMarkdownInlineFormat(.strikethrough)
                } label: {
                    Label("删除线", systemImage: "strikethrough")
                }
                .disabled(inlineFormatTarget == nil)

                Button {
                    applyMarkdownInlineFormat(.code)
                } label: {
                    Label("代码", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                .disabled(inlineFormatTarget == nil)
            }

            Section("页面") {
                Button {
                    onUndoTextEdit()
                } label: {
                    Label("撤销编辑", systemImage: "arrow.uturn.backward")
                }
                .disabled(!canUndoTextEdit)

                Button {
                    onRedoTextEdit()
                } label: {
                    Label("重做编辑", systemImage: "arrow.uturn.forward")
                }
                .disabled(!canRedoTextEdit)

                Button {
                    handleMarkdownImportButton()
                } label: {
                    Label("导入 Markdown", systemImage: "square.and.arrow.down")
                }
                .disabled(page == nil)
                .accessibilityIdentifier("editor.import-markdown")

                Button {
                    handleObsidianVaultImportButton()
                } label: {
                    Label("导入 Obsidian", systemImage: "folder.badge.plus")
                }
                .disabled(page == nil)
                .accessibilityIdentifier("editor.import-obsidian")

                Button {
                    handleMarkdownExportButton()
                } label: {
                    Label("导出 Markdown", systemImage: "square.and.arrow.up")
                }
                .disabled(page == nil)
                .accessibilityIdentifier("editor.export-markdown")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.callout.weight(.semibold))
                .frame(width: 28, height: 28)
        }
        .menuStyle(.borderlessButton)
        .foregroundStyle(EditorDesignTokens.Colors.primaryText.color.opacity(0.82))
        .help("更多")
        .accessibilityIdentifier("editor.page-actions")
    }

    private var blockReferenceTargets: [BlockSnapshot] {
        allBlocks.filter { block in
            block.type.isTextEditable && !block.textPlain.isEmpty
        }
    }

#if os(iOS)
    private func revealMobilePageList() {
        onMobileRevealPageList?()
    }

    private func revealMobileOutline() {
        withAnimation(.easeInOut(duration: 0.18)) {
            isMobileOutlinePresented = true
        }
    }

    private func closeMobileOutline() {
        withAnimation(.easeInOut(duration: 0.18)) {
            isMobileOutlinePresented = false
        }
    }
#endif

#if os(macOS)
    private func copySelectedBlocksToPasteboard() -> Bool {
        let markdown = SelectedBlockMarkdownCopyResolver.markdown(
            selectedBlockIDs: editorSession.selectedBlockIDs,
            visibleBlocks: blocks,
            attachments: attachments
        )
        guard !markdown.isEmpty else {
            return false
        }

        NSPasteboard.general.clearContents()
        return NSPasteboard.general.setString(markdown, forType: .string)
    }
#endif

    private var inlineFormatTarget: (blockID: String, selection: EditorTextSelection)? {
        if let selection = editorSession.textSelection,
           let block = blocks.first(where: { $0.id == selection.blockID && $0.type.isTextEditable }),
           isValid(selection: selection, for: block) {
            return (block.id, selection)
        }

        if let focusedBlockID = editorSession.focusedBlockID,
           let block = blocks.first(where: { $0.id == focusedBlockID && $0.type.isTextEditable }) {
            return (block.id, endSelection(for: block))
        }

        if let block = blocks.last(where: { $0.type.isTextEditable }) {
            return (block.id, endSelection(for: block))
        }

        return nil
    }

    private var inlineLinkTarget: (blockID: String, selection: EditorTextSelection?)? {
        if let selection = editorSession.textSelection,
           let block = blocks.first(where: { $0.id == selection.blockID && $0.type.isTextEditable }),
           isValid(selection: selection, for: block) {
            return (block.id, selection)
        }

        if let focusedBlockID = editorSession.focusedBlockID,
           blocks.contains(where: { $0.id == focusedBlockID && $0.type.isTextEditable }) {
            return (focusedBlockID, nil)
        }

        if let block = blocks.last(where: { $0.type.isTextEditable }) {
            return (block.id, nil)
        }

        return nil
    }

    private var inlineLinkTargetBlockID: String? {
        inlineLinkTarget?.blockID
    }

    private var inlineLinkKeyboardTarget: (blockID: String, selection: EditorTextSelection?)? {
        guard let selection = editorSession.textSelection,
              let block = blocks.first(where: { $0.id == selection.blockID && $0.type.isTextEditable }),
              isValid(selection: selection, for: block) else {
            return nil
        }

        return (block.id, selection)
    }

    private var inlineLinkToolbarTargetBlockID: String? {
        inlineLinkTargetBlockID ?? activeInlineLinkTarget?.blockID
    }

    private var insertMarkdownLinkAction: (() -> Void)? {
        guard inlineLinkToolbarTargetBlockID != nil else {
            return nil
        }

        return {
            _ = presentInlineLinkInsertionFromCurrentTarget()
        }
    }

    private var promoteCurrentBlockToPageAction: (() -> Void)? {
        guard let blockID = BlockPromotionCommandResolver.promotableBlockID(
            selection: editorSession.textSelection,
            focusedBlockID: editorSession.focusedBlockID,
            blocks: blocks
        ) else {
            return nil
        }

        return {
            onConvertBlockToPage(blockID)
        }
    }

    private func promoteCurrentBlockToPageFromKeyboard() -> Bool {
        guard let promoteCurrentBlockToPageAction else {
            return false
        }

        promoteCurrentBlockToPageAction()
        return true
    }

    private var openParentPageAction: (() -> Void)? {
        guard parentPageLink != nil else {
            return nil
        }

        return {
            _ = onOpenParentPage()
        }
    }

    private func handleMarkdownImportButton() {
#if DEBUG
        if let sourceURL = makeUITestMarkdownImportSourceURL() {
            onImportMarkdown(sourceURL)
            return
        }
#endif
        isMarkdownImporterPresented = true
    }

    private func handleObsidianVaultImportButton() {
        isObsidianVaultImporterPresented = true
    }

    private func handleMarkdownExportButton() {
        let markdown = onExportMarkdown()
#if DEBUG
        if ProcessInfo.processInfo.environment["EDITOR_UI_TEST_MARKDOWN_EXPORT_CAPTURE"] == "1" {
            uiTestMarkdownExportOutput = markdown
            return
        }
#endif
        markdownExportDocument = MarkdownFileDocument(text: markdown)
        isMarkdownExporterPresented = true
    }

    private func handleAttachmentImportButton() {
        pendingAttachmentImportAnchorBlockID = nil
        attachmentImporterAllowedContentTypes = [.image, .movie, .data, .item]
#if DEBUG
        if let sourceURL = makeUITestAttachmentImportSourceURL() {
            importAttachment(sourceURL)
            return
        }
#endif
        isAttachmentImporterPresented = true
    }

    private func requestAttachmentImport(afterBlockID blockID: String, type: BlockType) {
        pendingAttachmentImportAnchorBlockID = blockID
        attachmentImporterAllowedContentTypes = attachmentImporterContentTypes(for: type)
#if DEBUG
        if let sourceURL = makeUITestAttachmentImportSourceURL() {
            importAttachment(sourceURL, anchorBlockID: blockID)
            return
        }
#endif
        isAttachmentImporterPresented = true
    }

    private func importAttachment(_ sourceURL: URL, anchorBlockID explicitAnchorBlockID: String? = nil) {
        let anchorBlockID = explicitAnchorBlockID ?? pendingAttachmentImportAnchorBlockID
        pendingAttachmentImportAnchorBlockID = nil
        if let anchorBlockID {
            _ = onImportAttachmentsAfterBlock([sourceURL], anchorBlockID)
        } else {
            onImportAttachment(sourceURL)
        }
    }

    private func createDrawingBlock(afterBlockID blockID: String) {
        do {
            let sourceURL = try makeBlankDrawingImportSourceURL()
            _ = onImportAttachmentsAfterBlock([sourceURL], blockID)
        } catch {
            EditorLog.attachment.error(
                "drawing_block_fixture_failed block_id=\(blockID, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
        }
    }

    private func attachmentImporterContentTypes(for type: BlockType) -> [UTType] {
        switch type {
        case .attachmentImage:
            return [.image]
        case .attachmentVideo:
            return [.movie]
        case .attachmentFile:
            return [.item]
        default:
            return [.image, .movie, .data, .item]
        }
    }

    private func makeBlankDrawingImportSourceURL() throws -> URL {
        let importDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("EditorDrawingImports", isDirectory: true)
        try FileManager.default.createDirectory(at: importDirectory, withIntermediateDirectories: true)
        let sourceURL = importDirectory.appendingPathComponent("Untitled-\(UUID().uuidString).drawing")
        try EditorDrawingDocument.empty.dataRepresentation().write(to: sourceURL, options: .atomic)
        return sourceURL
    }

#if DEBUG
    private func makeUITestMarkdownImportSourceURL() -> URL? {
        guard let markdown = ProcessInfo.processInfo.environment["EDITOR_UI_TEST_MARKDOWN_IMPORT_TEXT"] else {
            return nil
        }

        do {
            let fixtureDirectory = try makeUITestFixtureDirectory()
            let sourceURL = fixtureDirectory.appendingPathComponent("toolbar-import.md")
            try markdown.write(to: sourceURL, atomically: true, encoding: .utf8)
            return sourceURL
        } catch {
            EditorLog.markdown.error(
                "markdown_ui_test_fixture_failed error=\(String(describing: error), privacy: .public)"
            )
            return nil
        }
    }

    private func makeUITestAttachmentImportSourceURL() -> URL? {
        guard let filename = ProcessInfo.processInfo.environment["EDITOR_UI_TEST_ATTACHMENT_IMPORT_FILENAME"],
              !filename.isEmpty else {
            return nil
        }

        do {
            let fixtureDirectory = try makeUITestFixtureDirectory()
            let safeFilename = URL(fileURLWithPath: filename).lastPathComponent
            let sourceURL = fixtureDirectory.appendingPathComponent(safeFilename)
            let contents = ProcessInfo.processInfo.environment["EDITOR_UI_TEST_ATTACHMENT_IMPORT_CONTENTS"]
                ?? "Attachment fixture from macOS toolbar UI automation"
            try contents.write(to: sourceURL, atomically: true, encoding: .utf8)
            return sourceURL
        } catch {
            EditorLog.attachment.error(
                "attachment_ui_test_fixture_failed error=\(String(describing: error), privacy: .public)"
            )
            return nil
        }
    }

    private func makeUITestFixtureDirectory() throws -> URL {
        let fixtureDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("EditorUITestFixtures", isDirectory: true)
        try FileManager.default.createDirectory(at: fixtureDirectory, withIntermediateDirectories: true)
        return fixtureDirectory
    }
#endif

    private var inlineLinkPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("文本", text: $inlineLinkLabel)
                .textFieldStyle(.roundedBorder)
                .frame(width: 240)
                .accessibilityIdentifier("editor.insert-markdown-link.label")

            TextField("URL", text: $inlineLinkURL)
                .textFieldStyle(.roundedBorder)
                .frame(width: 240)
                .accessibilityIdentifier("editor.insert-markdown-link.url")

            HStack {
                Button {
                    cancelInlineLinkInsertion()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .help("取消")
                .accessibilityIdentifier("editor.insert-markdown-link.cancel")

                if isEditingInlineLink {
                    Button(role: .destructive) {
                        removeInlineLink()
                    } label: {
                        Label("移除链接", systemImage: "link.badge.minus")
                    }
                    .buttonStyle(.borderless)
                    .help("移除链接")
                    .accessibilityIdentifier("editor.insert-markdown-link.remove")
                }

                Spacer()
                Button {
                    insertInlineLink()
                } label: {
                    Label(isEditingInlineLink ? "更新链接" : "插入链接", systemImage: "link")
                }
                .disabled(MarkdownInlineLinkComposer.markdown(label: inlineLinkLabel, url: inlineLinkURL) == nil)
                .accessibilityIdentifier("editor.insert-markdown-link.confirm")
            }
        }
        .padding(12)
    }

    private func blockReferenceTitle(for block: BlockSnapshot) -> String {
        let pageTitle = pages.first { $0.id == block.pageID }?.title ?? "页面"
        return "\(pageTitle): \(block.textPlain)"
    }

    private func insertInlineLink() {
        guard let target = activeInlineLinkTarget ?? inlineLinkTarget else {
            return
        }

        if let selection = target.selection {
            guard let nextSelection = onInsertMarkdownLinkAtSelection(
                target.blockID,
                inlineLinkLabel,
                inlineLinkURL,
                selection
            ) else {
                return
            }
            pendingFocusRequest = BlockFocusRequest(blockID: target.blockID, selection: nextSelection)
        } else {
            guard onInsertMarkdownLink(target.blockID, inlineLinkLabel, inlineLinkURL) else {
                return
            }
            pendingFocusRequest = BlockFocusRequest(blockID: target.blockID)
        }

        inlineLinkLabel = ""
        inlineLinkURL = ""
        isEditingInlineLink = false
        isInlineLinkPopoverPresented = false
        activeInlineLinkTarget = nil
    }

    private func removeInlineLink() {
        guard let target = activeInlineLinkTarget,
              let selection = target.selection,
              let nextSelection = onRemoveMarkdownLinkAtSelection(target.blockID, selection) else {
            return
        }

        pendingFocusRequest = BlockFocusRequest(blockID: target.blockID, selection: nextSelection)
        inlineLinkLabel = ""
        inlineLinkURL = ""
        isEditingInlineLink = false
        isInlineLinkPopoverPresented = false
        activeInlineLinkTarget = nil
    }

    private func cancelInlineLinkInsertion() {
        inlineLinkLabel = ""
        inlineLinkURL = ""
        isEditingInlineLink = false
        isInlineLinkPopoverPresented = false
        activeInlineLinkTarget = nil
    }

    private func applyMarkdownInlineFormat(_ format: MarkdownInlineFormat) {
        guard let target = inlineFormatTarget,
              let nextSelection = onApplyMarkdownInlineFormat(target.blockID, format, target.selection) else {
            return
        }

        pendingFocusRequest = BlockFocusRequest(blockID: target.blockID, selection: nextSelection)
    }

    private func applyMarkdownInlineFormat(
        _ format: MarkdownInlineFormat,
        selection: EditorTextSelection
    ) -> Bool {
        guard let nextSelection = onApplyMarkdownInlineFormat(selection.blockID, format, selection) else {
            return false
        }

        pendingFocusRequest = BlockFocusRequest(blockID: selection.blockID, selection: nextSelection)
        EditorLog.focus.debug(
            "editor_focus_request_scheduled block_id=\(selection.blockID, privacy: .public) source=keyboard_inline_format"
        )
        return true
    }

    private func presentInlineLinkInsertion(selection: EditorTextSelection) -> Bool {
        guard let block = blocks.first(where: { $0.id == selection.blockID && $0.type.isTextEditable }),
              isValid(selection: selection, for: block) else {
            return false
        }

        activeInlineLinkTarget = preparedInlineLinkTarget(for: (selection.blockID, selection))
        isInlineLinkPopoverPresented = true
        EditorLog.focus.debug(
            "editor_inline_link_panel_presented block_id=\(selection.blockID, privacy: .public) source=keyboard_link"
        )
        return true
    }

    private func presentInlineLinkInsertionFromCurrentTarget() -> Bool {
        guard let target = inlineLinkTarget else {
            return false
        }

        activeInlineLinkTarget = preparedInlineLinkTarget(for: target)
        isInlineLinkPopoverPresented = true
        return true
    }

#if os(macOS)
    private func presentInlineLinkInsertionFromKeyboardShortcut() -> Bool {
        guard let target = inlineLinkKeyboardTarget else {
            return false
        }

        activeInlineLinkTarget = preparedInlineLinkTarget(for: target)
        isInlineLinkPopoverPresented = true
        return true
    }
#endif

    private func preparedInlineLinkTarget(
        for target: (blockID: String, selection: EditorTextSelection?)
    ) -> (blockID: String, selection: EditorTextSelection?) {
        inlineLinkLabel = ""
        inlineLinkURL = ""
        isEditingInlineLink = false

        guard let selection = target.selection,
              let block = blocks.first(where: { $0.id == selection.blockID && $0.type.isTextEditable }),
              let editTarget = MarkdownInlineLinkEditTarget.target(in: block.textPlain, selection: selection) else {
            return target
        }

        inlineLinkLabel = editTarget.label
        inlineLinkURL = editTarget.url
        isEditingInlineLink = true
        return (blockID: target.blockID, selection: editTarget.replacementSelection)
    }

    private func isValid(selection: EditorTextSelection, for block: BlockSnapshot) -> Bool {
        let textLength = (block.textPlain as NSString).length
        return selection.location >= 0 &&
            selection.length >= 0 &&
            selection.location <= textLength &&
            selection.length <= textLength - selection.location
    }

    private func endSelection(for block: BlockSnapshot) -> EditorTextSelection {
        EditorTextSelection(
            blockID: block.id,
            location: (block.textPlain as NSString).length,
            length: 0
        )
    }

    private func schedulePendingFocusIfNeeded(
        _ blockID: String?,
        requestID: UUID?,
        reason: EditorPendingBlockFocusScheduleReason = .pendingValueChanged
    ) {
        guard EditorPendingBlockFocusSchedulePolicy.shouldSchedule(
            blockID: blockID,
            existingRequestBlockID: pendingFocusRequest?.blockID,
            requestID: requestID,
            reason: reason
        ) else {
            return
        }
        guard let blockID else {
            return
        }

        setPendingFocusRequest(blockID: blockID, reason: reason)
        schedulePendingFocusRetriesIfNeeded(blockID: blockID, requestID: requestID, reason: reason)
    }

    private func scrollToPendingFocusBlockIfNeeded(_ blockID: String?, proxy: ScrollViewProxy) {
        guard let blockID,
              blocks.contains(where: { $0.id == blockID }) else {
            return
        }

        withAnimation(.easeInOut(duration: 0.22)) {
            proxy.scrollTo(blockID, anchor: .center)
        }
    }

    private func setPendingFocusRequest(
        blockID: String,
        reason: EditorPendingBlockFocusScheduleReason
    ) {
        pendingFocusRequest = BlockFocusRequest(blockID: blockID)
        let reasonLabel: String
        switch reason {
        case .pendingValueChanged:
            reasonLabel = "pending_value_changed"
        case .pageChanged:
            reasonLabel = "page_changed"
        case .retry:
            reasonLabel = "retry"
        }
        EditorLog.focus.debug(
            "editor_focus_request_scheduled block_id=\(blockID, privacy: .public) source=view_model reason=\(reasonLabel, privacy: .public)"
        )
    }

    private func schedulePendingFocusRetriesIfNeeded(
        blockID: String,
        requestID: UUID?,
        reason: EditorPendingBlockFocusScheduleReason
    ) {
        guard reason != .retry,
              requestID != nil || reason == .pageChanged else {
            return
        }

        for delay in [0.08, 0.2, 0.4] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard pendingFocusRequest?.blockID == blockID else {
                    return
                }
                schedulePendingFocusIfNeeded(blockID, requestID: requestID, reason: .retry)
            }
        }
    }

    private func focusCanvas() {
        clearTransientSelections()
        guard let blockID = onFocusCanvas() else {
            return
        }

        pendingFocusRequest = BlockFocusRequest(blockID: blockID)
    }

    private func focusFirstEditableBlockFromPageTitle() {
        cancelPendingPageTitleFocus()
        clearTransientSelections()
        guard let block = blocks.first(where: { $0.type.isTextEditable }) else {
            focusCanvas()
            return
        }

        pendingFocusRequest = BlockFocusRequest(
            blockID: block.id,
            selection: endSelection(for: block)
        )
    }

    private func cancelPendingPageTitleFocus() {
        guard scheduledPageTitleFocusPageID != nil || pendingPageTitleFocusPageID == page?.id else {
            return
        }

        scheduledPageTitleFocusPageID = nil
#if os(iOS)
        pageTitleFocusRequestID = nil
#else
        isPageTitleFocused = false
#endif
        onPendingPageTitleFocusHandled()
    }

    private func clearTransientSelections(excludingBlockID: String? = nil) {
        editorSession.clearBlockSelection()
        activeBlockDropTarget = BlockDropTargetLifecycleReducer
            .targetAfterEditorInteraction(current: activeBlockDropTarget)
        transientSelectionResetRequest = TransientSelectionResetRequest(excludingBlockID: excludingBlockID)
    }

    private func clearTransientSelectionsAfterPageTitleFocusIfNeeded() {
        guard !editorSession.selectedBlockIDs.isEmpty ||
            activeBlockDropTarget != nil ||
            blockSelectionMarqueeStart != nil ||
            blockSelectionMarqueeCurrent != nil else {
            return
        }

        clearTransientSelections()
    }

    @discardableResult
    private func extendBlockSelection(
        from blockID: String,
        direction: BlockKeyboardFocusDirection
    ) -> Bool {
        let blockIDs = BlockSelectionRangeResolver.selectionAfterExtending(
            from: blockID,
            direction: direction,
            currentSelection: editorSession.selectedBlockIDs,
            visibleBlockIDs: blocks.map(\.id)
        )
        guard !blockIDs.isEmpty else {
            return false
        }

        editorSession.selectBlocks(Set(blockIDs))
        return true
    }

    @discardableResult
    private func applySelectedBlocksIndentation(_ direction: BlockKeyboardIndentationDirection) -> Bool {
        let blockIDs = MobileBlockSelectionBatchResolver.orderedBlockIDs(
            selectedBlockIDs: editorSession.selectedBlockIDs,
            visibleBlockIDs: blocks.map(\.id)
        )
        guard !blockIDs.isEmpty else {
            return false
        }

        var didChange = false
        for blockID in blockIDs {
            switch direction {
            case .indent:
                didChange = onIndentBlock(blockID) || didChange
            case .outdent:
                didChange = onOutdentBlock(blockID) || didChange
            }
        }

        if didChange {
            editorSession.selectBlocks(Set(blockIDs))
        }
        return didChange
    }

    @discardableResult
    private func applyBlockIndentation(
        _ direction: BlockKeyboardIndentationDirection,
        fallbackBlockID: String
    ) -> Bool {
        if editorSession.selectedBlockIDs.contains(fallbackBlockID),
           applySelectedBlocksIndentation(direction) {
            return true
        }

        switch direction {
        case .indent:
            return onIndentBlock(fallbackBlockID)
        case .outdent:
            return onOutdentBlock(fallbackBlockID)
        }
    }

    @discardableResult
    private func deleteSelectedBlocks() -> Bool {
        let blockIDs = MobileBlockSelectionBatchResolver.orderedBlockIDs(
            selectedBlockIDs: editorSession.selectedBlockIDs,
            visibleBlockIDs: blocks.map(\.id)
        )
        guard !blockIDs.isEmpty else {
            return false
        }

        if onDeleteBlocks(blockIDs) {
            editorSession.clearBlockSelection()
            return true
        }
        return false
    }

    private func deleteBlockForCommand(fallbackBlockID: String) {
        if editorSession.selectedBlockIDs.contains(fallbackBlockID),
           deleteSelectedBlocks() {
            return
        }

        onDeleteBlock(fallbackBlockID)
    }

    private func blockSelectionFrameReporter(_ blockID: String) -> some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: BlockRowFramePreferenceKey.self,
                value: [blockID: proxy.frame(in: .named(EditorCanvasCoordinateSpace.blockSelection))]
            )
        }
    }

    private var blockSelectionMarqueeRect: CGRect? {
        guard let blockSelectionMarqueeStart,
              let blockSelectionMarqueeCurrent else {
            return nil
        }

        let rect = BlockSelectionMarqueeRectResolver.rect(
            start: blockSelectionMarqueeStart,
            current: blockSelectionMarqueeCurrent
        )
        guard BlockSelectionMarqueeRectResolver.isVisible(rect) else {
            return nil
        }
        return rect
    }

    private func blockSelectionMarqueeGesture() -> some Gesture {
        blockSelectionMarqueeGesture(isEnabled: true)
    }

    private func blockSelectionMarqueeGesture(isEnabled: Bool) -> some Gesture {
        DragGesture(
            minimumDistance: 2,
            coordinateSpace: .named(EditorCanvasCoordinateSpace.blockSelection)
        )
        .onChanged { value in
            guard isEnabled else {
                return
            }
            guard isBlockSelectionMarqueeDragStart(value.startLocation) else {
                return
            }

            if blockSelectionMarqueeStart == nil {
                blockSelectionMarqueeStart = value.startLocation
            }
            blockSelectionMarqueeCurrent = value.location

            let selectionRect = BlockSelectionMarqueeRectResolver.rect(
                start: value.startLocation,
                current: value.location
            )
            let blockIDs = BlockSelectionMarqueeSelectionResolver.selectedBlockIDs(
                selectionRect: selectionRect,
                blockFrames: blockRowFrames,
                visibleBlockIDs: blocks.map(\.id)
            )

            editorSession.selectBlocks(Set(blockIDs))
        }
        .onEnded { _ in
            blockSelectionMarqueeStart = nil
            blockSelectionMarqueeCurrent = nil
        }
    }

    private func isBlockSelectionMarqueeDragStart(_ location: CGPoint) -> Bool {
        BlockSelectionMarqueeStartPolicy.isAllowed(
            location: location,
            blockFrames: blockRowFrames,
            blockedInteractionFrames: blockSelectionBlockedInteractionFrames
        )
    }

    private var blockSelectionBlockedInteractionFrames: [CGRect] {
        Array(attachmentResizeHandleFrames.values)
            + BlockSelectionMarqueeInteractionFrameResolver.blockedFrames(
                blocks: blocks,
                blockFrames: blockRowFrames
            )
    }

    private func importPastedAttachments(_ attachmentURLs: [URL]) -> Bool {
        guard !attachmentURLs.isEmpty else {
            return false
        }

        if let anchorBlockID = PastedAttachmentAnchorResolver.anchorBlockID(
            textSelection: editorSession.textSelection,
            focusedBlockID: editorSession.focusedBlockID,
            selectedBlockIDs: editorSession.selectedBlockIDs,
            visibleBlockIDs: blocks.map(\.id)
        ) {
            return onImportAttachmentsAfterBlock(attachmentURLs, anchorBlockID)
        }

        attachmentURLs.forEach(onImportAttachment)
        return true
    }

    private func focusAdjacentBlock(
        from blockID: String,
        direction: BlockKeyboardFocusDirection,
        clearsBlockSelection: Bool = false
    ) -> Bool {
        guard let target = BlockKeyboardFocusResolver.target(
            currentBlockID: blockID,
            direction: direction,
            blocks: blocks
        ) else {
            return false
        }

        if clearsBlockSelection {
            editorSession.clearBlockSelection()
        }

        pendingFocusRequest = BlockFocusRequest(
            blockID: target.blockID,
            selection: target.selection
        )
        EditorLog.focus.debug(
            "editor_focus_request_scheduled block_id=\(target.blockID, privacy: .public) source=keyboard_navigation direction=\(direction.debugName, privacy: .public)"
        )
        return true
    }

    private func moveDroppedBlocks(
        _ draggedBlockIDs: [String],
        destinationBlockID: String,
        placement: BlockDropPlacement,
        targetLevel: Int?
    ) -> Bool {
        let movedBlockIDs = visibleDraggedBlockIDs(from: draggedBlockIDs)
        guard let draggedBlockID = movedBlockIDs.first,
              let targetIndex = BlockDragReorderResolver.targetIndex(
                draggedBlockIDs: movedBlockIDs,
                destinationBlockID: destinationBlockID,
                visibleBlockIDs: blocks.map(\.id),
                placement: placement
              ) else {
            return false
        }

        let parentBlockID: String?
        if let targetLevel {
            parentBlockID = BlockDropParentResolver.parentBlockID(
                destinationBlockID: destinationBlockID,
                targetLevel: targetLevel,
                blocks: blocks
            )
        } else {
            parentBlockID = nil
        }

        onMoveBlocks(movedBlockIDs, targetIndex)
        if targetLevel != nil {
            _ = onUpdateBlockParent(draggedBlockID, parentBlockID)
        }
        pendingFocusRequest = BlockFocusRequest(blockID: draggedBlockID)
        return true
    }

    private func moveDroppedBlocksToEnd(_ draggedBlockIDs: [String]) -> Bool {
        let movedBlockIDs = visibleDraggedBlockIDs(from: draggedBlockIDs)
        guard let draggedBlockID = movedBlockIDs.first,
              let targetIndex = BlockDragReorderResolver.endTargetIndex(
                draggedBlockIDs: movedBlockIDs,
                visibleBlockIDs: blocks.map(\.id)
              ) else {
            return false
        }

        onMoveBlocks(movedBlockIDs, targetIndex)
        _ = onUpdateBlockParent(draggedBlockID, BlockDropParentResolver.parentBlockIDForEndDrop())
        pendingFocusRequest = BlockFocusRequest(blockID: draggedBlockID)
        return true
    }

    private func visibleDraggedBlockIDs(from draggedBlockIDs: [String]) -> [String] {
        let draggedBlockIDSet = Set(draggedBlockIDs)
        return blocks.map(\.id).filter { draggedBlockIDSet.contains($0) }
    }

    private func attachment(for block: BlockSnapshot) -> AttachmentSnapshot? {
        attachments.first { $0.matches(block: block) }
    }

    private func attachmentPreviewGenerationStatus(for block: BlockSnapshot) -> AttachmentPreviewGenerationStatus {
        guard let attachment = attachment(for: block) else {
            return .idle
        }

        return attachmentPreviewGenerationStatuses[attachment.id] ?? .idle
    }

    private var renderMetrics: EditorCanvasRenderMetrics {
        EditorCanvasRenderMetrics(
            pageID: page?.id,
            blockCount: blocks.count,
            attachmentCount: attachments.count,
            backlinkCount: backlinks.count,
            conflictCount: conflicts.count
        )
    }

    private func logRenderMetrics(reason: String) {
        let metrics = renderMetrics
        EditorLog.render.debug(
            "editor_canvas_rendered reason=\(reason, privacy: .public) page_id=\(metrics.pageID ?? "none", privacy: .public) block_count=\(metrics.blockCount, privacy: .public) attachment_count=\(metrics.attachmentCount, privacy: .public) backlink_count=\(metrics.backlinkCount, privacy: .public) conflict_count=\(metrics.conflictCount, privacy: .public) large_page=\(metrics.isLargePage, privacy: .public)"
        )
    }

    private func resetScrollMetrics() {
        scrollMetricsTracker.reset(pageID: page?.id, blockCount: blocks.count)
        logScrollMetrics(reason: "reset")
    }

    private func scheduleScrollMetricsReset() {
        DispatchQueue.main.async {
            resetScrollMetrics()
        }
    }

    private func scheduleVisibleBlockAppeared(_ blockID: String, index: Int) {
        DispatchQueue.main.async {
            recordVisibleBlockAppeared(blockID, index: index)
        }
    }

    private func scheduleVisibleBlockDisappeared(_ blockID: String) {
        DispatchQueue.main.async {
            recordVisibleBlockDisappeared(blockID)
        }
    }

    private func recordVisibleBlockAppeared(_ blockID: String, index: Int) {
        guard blocks.indices.contains(index),
              blocks[index].id == blockID else {
            return
        }
        scrollMetricsTracker.blockAppeared(blockID, index: index)
        logScrollMetrics(reason: "appear")
    }

    private func recordVisibleBlockDisappeared(_ blockID: String) {
        scrollMetricsTracker.blockDisappeared(blockID)
        logScrollMetrics(reason: "disappear")
    }

    private func logScrollMetrics(reason: String) {
        let metrics = scrollMetricsTracker.metrics
        EditorLog.scroll.debug(
            "editor_canvas_scroll_visible reason=\(reason, privacy: .public) \(metrics.runtimeSummary, privacy: .public)"
        )
    }

#if DEBUG
    private var scrollMetricsDebugProbe: some View {
        let summary = scrollMetricsTracker.metrics.runtimeSummary
        return Text(summary)
            .font(.system(size: 1))
            .opacity(0.01)
            .frame(width: 1, height: 1)
            .id(summary)
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("editor.scroll-metrics-test-output")
            .accessibilityLabel(summary)
            .accessibilityValue(summary)
    }
#endif

    private func nestingLevel(for block: BlockSnapshot) -> Int {
        var level = 0
        var visitedBlockIDs: Set<String> = [block.id]
        var parentBlockID = block.parentBlockID

        while let currentParentID = parentBlockID,
              !visitedBlockIDs.contains(currentParentID),
              let parentBlock = blocks.first(where: { $0.id == currentParentID }) {
            level += 1
            visitedBlockIDs.insert(currentParentID)
            parentBlockID = parentBlock.parentBlockID
        }

        return min(level, 6)
    }
}

#if os(macOS)
private struct EditorGlobalShortcutBridge: NSViewRepresentable {
    let onCommand: (EditorShortcutCommand) -> Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(onCommand: onCommand)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.hostView = view
        context.coordinator.onCommand = onCommand
        context.coordinator.install()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.hostView = nsView
        context.coordinator.onCommand = onCommand
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    final class Coordinator {
        weak var hostView: NSView?
        var onCommand: (EditorShortcutCommand) -> Bool
        private var eventMonitor: Any?

        init(onCommand: @escaping (EditorShortcutCommand) -> Bool) {
            self.onCommand = onCommand
        }

        func install() {
            guard eventMonitor == nil else {
                return
            }

            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self,
                      self.hostView?.window?.isKeyWindow == true,
                      let rawValue = event.editorShortcutRawValue,
                      let command = EditorGlobalShortcutActionResolver.command(forRawValue: rawValue) else {
                    return event
                }
                return self.onCommand(command) ? nil : event
            }
        }

        func uninstall() {
            if let eventMonitor {
                NSEvent.removeMonitor(eventMonitor)
                self.eventMonitor = nil
            }
        }

        deinit {
            uninstall()
        }
    }
}

enum MacEditorKeyboardShortcutAction: Equatable, Sendable {
    case cancelSelection
    case copySelection
    case deleteSelection
    case indentSelection(BlockKeyboardIndentationDirection)
    case extendBlockSelection(BlockKeyboardFocusDirection)
    case undoEdit
    case redoEdit
    case selectFocusedCodeText
    case insertLink
    case pasteAttachments
    case moveFocus(BlockKeyboardFocusDirection)
    case promoteBlockToPage
}

enum MacEditorKeyboardShortcutActionResolver {
    private static let deleteKeyCodes: Set<UInt16> = [51, 117]

    static func action(
        keyCode: UInt16,
        input: String?,
        modifiers: Set<BlockKeyboardShortcutModifier>,
        hasBlockSelection: Bool,
        hasPasteableAttachments: Bool
    ) -> MacEditorKeyboardShortcutAction? {
        if hasBlockSelection,
           BlockSelectionCancelKeyboardResolver.requestsCancel(
            keyCode: keyCode,
            input: input,
            modifiers: modifiers
        ) {
            return .cancelSelection
        }

        if hasBlockSelection,
           deleteKeyCodes.contains(keyCode),
           modifiers.isEmpty {
            return .deleteSelection
        }

        if hasBlockSelection,
           input?.lowercased() == "c",
           modifiers == [.command] {
            return .copySelection
        }

        if hasBlockSelection,
           let direction = BlockKeyboardShortcutResolver.indentationDirection(
            keyCode: keyCode,
            modifiers: modifiers
           ) {
            return .indentSelection(direction)
        }

        if hasBlockSelection,
           let direction = BlockKeyboardSelectionExtensionResolver.direction(
            keyCode: keyCode,
            modifiers: modifiers
           ) {
            return .extendBlockSelection(direction)
        }

        if hasBlockSelection,
           let direction = NonEditableBlockKeyboardFocusResolver.focusDirection(
            keyCode: keyCode,
            modifiers: modifiers
           ) {
            return .moveFocus(direction)
        }

        if input?.lowercased() == "z",
           modifiers == [.command] {
            return .undoEdit
        }

        if input?.lowercased() == "z",
           modifiers == [.command, .shift] {
            return .redoEdit
        }

        if BlockSelectAllKeyboardResolver.requestsSelectAll(
            input: input,
            modifiers: modifiers
        ) {
            return .selectFocusedCodeText
        }

        if MarkdownInlineLinkKeyboardResolver.requestsLinkInsertion(
            input: input,
            modifiers: modifiers
        ) {
            return .insertLink
        }

        if DiaryPromotionKeyboardResolver.requestsPromotion(
            input: input,
            modifiers: modifiers
        ) {
            return .promoteBlockToPage
        }

        if hasPasteableAttachments,
           MacPasteKeyboardShortcutResolver.requestsAttachmentPaste(
            keyCode: keyCode,
            input: input,
            modifiers: modifiers
           ) {
            return .pasteAttachments
        }

        return nil
    }
}

private struct MacEditorKeyboardShortcutBridge: NSViewRepresentable {
    let onInsertLink: () -> Bool
    let onPasteAttachments: () -> Bool
    let hasBlockSelection: () -> Bool
    let onCancelSelection: () -> Bool
    let onCopySelection: () -> Bool
    let onMoveFocus: (BlockKeyboardFocusDirection) -> Bool
    let onExtendBlockSelection: (BlockKeyboardFocusDirection) -> Bool
    let onIndentSelection: (BlockKeyboardIndentationDirection) -> Bool
    let onDeleteSelection: () -> Bool
    let onUndoEdit: () -> Bool
    let onRedoEdit: () -> Bool
    let onSelectFocusedCodeText: (NSTextView) -> Bool
    let onPromoteBlockToPage: () -> Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        context.coordinator.onInsertLink = onInsertLink
        context.coordinator.onPasteAttachments = onPasteAttachments
        context.coordinator.hasBlockSelection = hasBlockSelection
        context.coordinator.onCancelSelection = onCancelSelection
        context.coordinator.onCopySelection = onCopySelection
        context.coordinator.onMoveFocus = onMoveFocus
        context.coordinator.onExtendBlockSelection = onExtendBlockSelection
        context.coordinator.onIndentSelection = onIndentSelection
        context.coordinator.onDeleteSelection = onDeleteSelection
        context.coordinator.onUndoEdit = onUndoEdit
        context.coordinator.onRedoEdit = onRedoEdit
        context.coordinator.onSelectFocusedCodeText = onSelectFocusedCodeText
        context.coordinator.onPromoteBlockToPage = onPromoteBlockToPage
        context.coordinator.install()
        return NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onInsertLink = onInsertLink
        context.coordinator.onPasteAttachments = onPasteAttachments
        context.coordinator.hasBlockSelection = hasBlockSelection
        context.coordinator.onCancelSelection = onCancelSelection
        context.coordinator.onCopySelection = onCopySelection
        context.coordinator.onMoveFocus = onMoveFocus
        context.coordinator.onExtendBlockSelection = onExtendBlockSelection
        context.coordinator.onIndentSelection = onIndentSelection
        context.coordinator.onDeleteSelection = onDeleteSelection
        context.coordinator.onUndoEdit = onUndoEdit
        context.coordinator.onRedoEdit = onRedoEdit
        context.coordinator.onSelectFocusedCodeText = onSelectFocusedCodeText
        context.coordinator.onPromoteBlockToPage = onPromoteBlockToPage
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    final class Coordinator {
        var onInsertLink: (() -> Bool)?
        var onPasteAttachments: (() -> Bool)?
        var hasBlockSelection: (() -> Bool)?
        var onCancelSelection: (() -> Bool)?
        var onCopySelection: (() -> Bool)?
        var onMoveFocus: ((BlockKeyboardFocusDirection) -> Bool)?
        var onExtendBlockSelection: ((BlockKeyboardFocusDirection) -> Bool)?
        var onIndentSelection: ((BlockKeyboardIndentationDirection) -> Bool)?
        var onDeleteSelection: (() -> Bool)?
        var onUndoEdit: (() -> Bool)?
        var onRedoEdit: (() -> Bool)?
        var onSelectFocusedCodeText: ((NSTextView) -> Bool)?
        var onPromoteBlockToPage: (() -> Bool)?
        private var eventMonitor: Any?

        func install() {
            guard eventMonitor == nil else {
                return
            }

            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else {
                    return event
                }

                let action = MacEditorKeyboardShortcutActionResolver.action(
                    keyCode: event.keyCode,
                    input: event.charactersIgnoringModifiers,
                    modifiers: event.blockKeyboardShortcutModifiers,
                    hasBlockSelection: self.hasBlockSelection?() == true,
                    hasPasteableAttachments: true
                )

                switch action {
                case .cancelSelection:
                    if self.onCancelSelection?() == true {
                        return nil
                    }
                case .copySelection:
                    if self.onCopySelection?() == true {
                        return nil
                    }
                case .deleteSelection:
                    if self.onDeleteSelection?() == true {
                        return nil
                    }
                case .indentSelection(let direction):
                    if self.onIndentSelection?(direction) == true {
                        return nil
                    }
                case .extendBlockSelection(let direction):
                    if self.onExtendBlockSelection?(direction) == true {
                        return nil
                    }
                case .undoEdit:
                    if self.onUndoEdit?() == true {
                        return nil
                    }
                case .redoEdit:
                    if self.onRedoEdit?() == true {
                        return nil
                    }
                case .selectFocusedCodeText:
                    let focusedTextView = MainActor.assumeIsolated {
                        NSApp.keyWindow?.firstResponder as? NSTextView
                    }
                    if let textView = focusedTextView,
                       self.onSelectFocusedCodeText?(textView) == true {
                        return nil
                    }
                case .insertLink:
                    if self.onInsertLink?() == true {
                        return nil
                    }
                case .pasteAttachments:
                    if self.onPasteAttachments?() == true {
                        return nil
                    }
                case .moveFocus(let direction):
                    if self.onMoveFocus?(direction) == true {
                        return nil
                    }
                case .promoteBlockToPage:
                    if self.onPromoteBlockToPage?() == true {
                        return nil
                    }
                case nil:
                    break
                }

                return event
            }
        }

        func uninstall() {
            if let eventMonitor {
                NSEvent.removeMonitor(eventMonitor)
                self.eventMonitor = nil
            }
        }

        deinit {
            uninstall()
        }
    }
}

private struct PageListKeyboardShortcutBridge: NSViewRepresentable {
    let isEnabled: Bool
    let activationVersion: Int
    let hasArchiveTargets: () -> Bool
    let onSelectAllVisiblePages: () -> Bool
    let onSelectRangeToSelectedPage: () -> Bool
    let onArchiveSelectedPages: () -> Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        context.coordinator.isEnabled = isEnabled
        context.coordinator.activationVersion = activationVersion
        context.coordinator.hasArchiveTargets = hasArchiveTargets
        context.coordinator.onSelectAllVisiblePages = onSelectAllVisiblePages
        context.coordinator.onSelectRangeToSelectedPage = onSelectRangeToSelectedPage
        context.coordinator.onArchiveSelectedPages = onArchiveSelectedPages
        context.coordinator.install()
        return ShortcutCaptureView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        let shouldActivate = context.coordinator.activationVersion != activationVersion
        context.coordinator.isEnabled = isEnabled
        context.coordinator.activationVersion = activationVersion
        context.coordinator.hasArchiveTargets = hasArchiveTargets
        context.coordinator.onSelectAllVisiblePages = onSelectAllVisiblePages
        context.coordinator.onSelectRangeToSelectedPage = onSelectRangeToSelectedPage
        context.coordinator.onArchiveSelectedPages = onArchiveSelectedPages
        if shouldActivate {
            context.coordinator.activate(nsView)
        }
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    final class Coordinator {
        var isEnabled = false
        var activationVersion = 0
        var hasArchiveTargets: (() -> Bool)?
        var onSelectAllVisiblePages: (() -> Bool)?
        var onSelectRangeToSelectedPage: (() -> Bool)?
        var onArchiveSelectedPages: (() -> Bool)?
        private var eventMonitor: Any?

        func install() {
            guard eventMonitor == nil else {
                return
            }

            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else {
                    return event
                }

                let isTextEditing = MainActor.assumeIsolated {
                    NSApp.keyWindow?.firstResponder is NSTextView
                }
                let action = PageListKeyboardShortcutActionResolver.action(
                    keyCode: event.keyCode,
                    input: event.charactersIgnoringModifiers,
                    modifiers: event.blockKeyboardShortcutModifiers,
                    hasVisiblePages: self.isEnabled,
                    hasArchiveTargets: self.hasArchiveTargets?() == true,
                    isTextEditing: isTextEditing
                )

                switch action {
                case .selectAllVisiblePages:
                    if self.onSelectAllVisiblePages?() == true {
                        return nil
                    }
                case .selectRangeToSelectedPage:
                    if self.onSelectRangeToSelectedPage?() == true {
                        return nil
                    }
                case .archiveSelectedPages:
                    if self.onArchiveSelectedPages?() == true {
                        return nil
                    }
                case nil:
                    break
                }

                return event
            }
        }

        func uninstall() {
            if let eventMonitor {
                NSEvent.removeMonitor(eventMonitor)
                self.eventMonitor = nil
            }
        }

        func activate(_ view: NSView) {
            guard isEnabled else {
                return
            }

            DispatchQueue.main.async { [weak view] in
                guard let view else {
                    return
                }
                view.window?.makeFirstResponder(view)
            }
        }

        deinit {
            uninstall()
        }
    }

    final class ShortcutCaptureView: NSView {
        override var acceptsFirstResponder: Bool {
            true
        }
    }
}
#elseif os(iOS)
private struct IOSEditorKeyboardShortcutBridge: UIViewRepresentable {
    let isPasteEnabled: Bool
    let isFocusMoveEnabled: Bool
    let onPasteAttachments: () -> Bool
    let onMoveFocus: (BlockKeyboardFocusDirection) -> Bool

    func makeUIView(context: Context) -> ShortcutCaptureView {
        let view = ShortcutCaptureView(frame: .zero)
        view.isPasteEnabled = isPasteEnabled
        view.isFocusMoveEnabled = isFocusMoveEnabled
        view.onPasteAttachments = onPasteAttachments
        view.onMoveFocus = onMoveFocus
        return view
    }

    func updateUIView(_ uiView: ShortcutCaptureView, context: Context) {
        uiView.isPasteEnabled = isPasteEnabled
        uiView.isFocusMoveEnabled = isFocusMoveEnabled
        uiView.onPasteAttachments = onPasteAttachments
        uiView.onMoveFocus = onMoveFocus
        uiView.updateFirstResponderIfNeeded()
    }

    final class ShortcutCaptureView: UIView {
        var isPasteEnabled = false
        var isFocusMoveEnabled = false
        var onPasteAttachments: () -> Bool = { false }
        var onMoveFocus: (BlockKeyboardFocusDirection) -> Bool = { _ in false }
        private var isCapturingKeyboard = false
        private var firstResponderUpdateGeneration = 0

        override var canBecomeFirstResponder: Bool {
            isPasteEnabled || isFocusMoveEnabled
        }

        override var keyCommands: [UIKeyCommand]? {
            guard canBecomeFirstResponder else {
                return []
            }

            var commands: [UIKeyCommand] = []
            if isPasteEnabled {
                commands.append(UIKeyCommand(
                    input: "v",
                    modifierFlags: [.command],
                    action: #selector(pasteAttachments)
                ))
            }
            if isFocusMoveEnabled {
                commands.append(UIKeyCommand(
                    input: IOSEditorKeyboardShortcutActionResolver.upArrowInput,
                    modifierFlags: [],
                    action: #selector(moveFocusUp)
                ))
                commands.append(UIKeyCommand(
                    input: IOSEditorKeyboardShortcutActionResolver.downArrowInput,
                    modifierFlags: [],
                    action: #selector(moveFocusDown)
                ))
            }
            return commands
        }

        func updateFirstResponderIfNeeded() {
            firstResponderUpdateGeneration += 1
            let updateGeneration = firstResponderUpdateGeneration
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }
                guard updateGeneration == self.firstResponderUpdateGeneration else {
                    return
                }

                if self.canBecomeFirstResponder {
                    self.becomeFirstResponder()
                    self.isCapturingKeyboard = self.isFirstResponder
                } else if self.isCapturingKeyboard {
                    self.resignFirstResponder()
                    self.isCapturingKeyboard = false
                }
            }
        }

        @objc private func pasteAttachments(_ sender: Any?) {
            performShortcut(input: "v", modifiers: [.command])
        }

        @objc private func moveFocusUp(_ sender: Any?) {
            performShortcut(
                input: IOSEditorKeyboardShortcutActionResolver.upArrowInput,
                modifiers: []
            )
        }

        @objc private func moveFocusDown(_ sender: Any?) {
            performShortcut(
                input: IOSEditorKeyboardShortcutActionResolver.downArrowInput,
                modifiers: []
            )
        }

        private func performShortcut(
            input: String?,
            modifiers: Set<BlockKeyboardShortcutModifier>
        ) {
            switch IOSEditorKeyboardShortcutActionResolver.action(
                input: input,
                modifiers: modifiers
            ) {
            case .pasteAttachments:
                _ = onPasteAttachments()
            case let .moveFocus(direction):
                _ = onMoveFocus(direction)
            case nil:
                break
            }
        }
    }
}
#endif

#if os(macOS)
private enum DesktopInlineOutlineStyle {
    case inline
    case popover
}

private struct DesktopInlineOutline: View {
    let outlineItems: [PageOutlineItem]
    let activeBlockID: String?
    let style: DesktopInlineOutlineStyle
    let onSelectOutlineItem: (PageOutlineItem) -> Void
    let onCollapse: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if style == .inline, let onCollapse {
                Button(action: onCollapse) {
                    Image(systemName: "chevron.left.2")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(EditorDesignTokens.Colors.tertiaryText.color.opacity(0.74))
                        .frame(width: 22, height: 22, alignment: .leading)
                }
                .buttonStyle(.plain)
                .help("收起大纲")
                .accessibilityLabel("收起大纲")
                .accessibilityIdentifier("editor.desktop-inline-outline-collapse")
            }

            OutlinePanel(
                outlineItems: outlineItems,
                activeBlockID: activeBlockID,
                style: style == .inline ? .inline : .popover,
                onSelectOutlineItem: onSelectOutlineItem
            )
        }
        .padding(.vertical, style == .inline ? 0 : 10)
        .padding(.horizontal, style == .inline ? 0 : 10)
        .frame(width: DesktopInlineOutlinePlacementPolicy.expandedWidth, alignment: .leading)
        .background(background)
        .overlay(border)
        .shadow(
            color: style == .popover ? EditorDesignTokens.Shadows.popoverSmall.swiftUIColor : .clear,
            radius: style == .popover ? CGFloat(EditorDesignTokens.Shadows.popoverSmall.radius) : 0,
            x: style == .popover ? CGFloat(EditorDesignTokens.Shadows.popoverSmall.x) : 0,
            y: style == .popover ? CGFloat(EditorDesignTokens.Shadows.popoverSmall.y) : 0
        )
        .accessibilityIdentifier(style == .inline ? "editor.desktop-inline-outline" : "editor.desktop-inline-outline-popover")
    }

    @ViewBuilder
    private var background: some View {
        if style == .popover {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(EditorDesignTokens.Colors.editorBackground.color.opacity(0.96))
        }
    }

    @ViewBuilder
    private var border: some View {
        if style == .popover {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(EditorDesignTokens.Colors.border.color.opacity(0.70), lineWidth: 1)
        }
    }
}

private struct DesktopInlineOutlineTriggerButton: View {
    let isPopoverPresented: Bool
    let onToggle: () -> Void
    let onHoverChange: (Bool) -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onToggle) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(
                    EditorDesignTokens.Colors.secondaryText.color.opacity(
                        isHovering || isPopoverPresented ? 0.78 : 0.34
                    )
                )
                .frame(
                    width: DesktopInlineOutlinePlacementPolicy.collapsedWidth,
                    height: 30
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            Capsule(style: .continuous)
                .fill(
                    EditorDesignTokens.Colors.border.color.opacity(
                        isHovering || isPopoverPresented ? 0.18 : 0
                    )
                )
        )
        .onHover { hovering in
            isHovering = hovering
            onHoverChange(hovering)
        }
        .help("显示大纲")
        .accessibilityLabel("显示大纲")
        .accessibilityIdentifier("editor.desktop-inline-outline-trigger")
    }
}
#endif

private struct AuxiliaryRailColumnChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(width: CGFloat(EditorDesignTokens.Layout.auxiliaryRailWidth), alignment: .topLeading)
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .background(EditorDesignTokens.Colors.editorBackground.color)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(EditorDesignTokens.Colors.border.color.opacity(0.42))
                    .frame(width: 1)
            }
    }
}

private struct EditorAuxiliaryRail: View {
    let outlineItems: [PageOutlineItem]
    let backlinks: [Backlink]
    let externalLinks: [ExternalLink]
    let activeBlockID: String?
    let onSelectOutlineItem: (PageOutlineItem) -> Void
    let onSelectBacklink: (Backlink) -> Void
    let onCollapse: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            if !outlineItems.isEmpty {
                OutlinePanel(
                    outlineItems: outlineItems,
                    activeBlockID: activeBlockID,
                    onSelectOutlineItem: onSelectOutlineItem
                )
            }

            if !backlinks.isEmpty {
                BacklinksPanel(backlinks: backlinks, onSelectBacklink: onSelectBacklink)
            }

            if !externalLinks.isEmpty {
                ExternalLinksPanel(externalLinks: externalLinks)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 92)
        .padding(.bottom, 10)
        .foregroundStyle(EditorDesignTokens.Colors.tertiaryText.color)
        .opacity(0.92)
    }
}

private struct BacklinksPanel: View {
    let backlinks: [Backlink]
    let onSelectBacklink: (Backlink) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("反向链接")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(backlinks) { backlink in
                Button {
                    onSelectBacklink(backlink)
                } label: {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "link")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 16)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(backlink.sourcePageTitle)
                                .font(.callout)
                            Text("[[\(backlink.linkText)]]")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 3)
                .accessibilityIdentifier("editor.backlink.\(backlink.id)")
            }
        }
        .padding(.top, 10)
    }
}

private struct ExternalLinksPanel: View {
    @Environment(\.openURL) private var openURL

    let externalLinks: [ExternalLink]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("外部链接")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(externalLinks) { externalLink in
                Button {
                    guard let destinationURL = externalLink.destinationURL else {
                        return
                    }
                    openURL(destinationURL)
                } label: {
                    externalLinkRow(externalLink)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 3)
                .disabled(externalLink.destinationURL == nil)
                .accessibilityIdentifier("editor.external-link.\(externalLink.id)")
            }
        }
        .padding(.top, 10)
        .accessibilityIdentifier("editor.external-links")
    }

    private func externalLinkRow(_ externalLink: ExternalLink) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "safari")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(externalLink.linkText)
                    .font(.callout)
                Text(externalLink.targetURL)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }
}

private enum OutlinePanelStyle {
    case standard
    case inline
    case popover

    var showsTitle: Bool {
        self == .standard
    }

    var showsLevelBadges: Bool {
        self == .standard
    }

    var topPadding: CGFloat {
        switch self {
        case .standard:
            return 10
        case .inline, .popover:
            return 0
        }
    }

    var rowHorizontalPadding: CGFloat {
        switch self {
        case .standard:
            return 8
        case .inline:
            return 0
        case .popover:
            return 6
        }
    }

    var rowVerticalPadding: CGFloat {
        switch self {
        case .standard:
            return 7
        case .inline, .popover:
            return 4
        }
    }

    var indentWidth: CGFloat {
        switch self {
        case .standard:
            return 12
        case .inline, .popover:
            return 14
        }
    }
}

private struct OutlinePanel: View {
    let outlineItems: [PageOutlineItem]
    let activeBlockID: String?
    var style: OutlinePanelStyle = .standard
    let onSelectOutlineItem: (PageOutlineItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: style == .standard ? 8 : 3) {
            if style.showsTitle {
                Text("大纲")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("editor.outline")
            }

            ForEach(outlineItems) { item in
                let isActive = item.blockID == activeBlockID
                Button {
                    onSelectOutlineItem(item)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: style.showsLevelBadges ? 8 : 0) {
                        if style.showsLevelBadges {
                            Text("H\(min(max(item.level, 1), 6))")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(EditorDesignTokens.Colors.tertiaryText.color)
                                .frame(width: 22, height: 18)
                                .background(EditorDesignTokens.Colors.border.color.opacity(0.62))
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        }

                        Text(item.title)
                            .font(style == .standard ? .callout : .caption)
                            .lineLimit(1)
                            .foregroundStyle(titleColor(isActive: isActive))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.leading, CGFloat(max(item.level - 1, 0)) * style.indentWidth)
                    .padding(.horizontal, style.rowHorizontalPadding)
                    .padding(.vertical, style.rowVerticalPadding)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(activeBackground(isActive: isActive))
                    )
                    .overlay(alignment: .leading) {
                        if isActive && style == .standard {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(EditorDesignTokens.Colors.accent.color.opacity(0.78))
                                .frame(width: 3)
                                .padding(.vertical, 6)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Outline heading \(item.title)")
                .accessibilityValue("Level \(item.level)")
                .accessibilityIdentifier("editor.outline.\(item.blockID)")
            }
        }
        .padding(.top, style.topPadding)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("editor.outline")
    }

    private func titleColor(isActive: Bool) -> Color {
        switch style {
        case .standard:
            return isActive
                ? EditorDesignTokens.Colors.primaryText.color
                : EditorDesignTokens.Colors.secondaryText.color
        case .inline, .popover:
            return isActive
                ? EditorDesignTokens.Colors.accent.color
                : EditorDesignTokens.Colors.secondaryText.color.opacity(0.78)
        }
    }

    private func activeBackground(isActive: Bool) -> Color {
        guard isActive else {
            return .clear
        }
        switch style {
        case .standard:
            return EditorDesignTokens.Colors.accent.color.opacity(0.12)
        case .inline:
            return .clear
        case .popover:
            return EditorDesignTokens.Colors.accent.color.opacity(0.08)
        }
    }
}

#if os(iOS)
private struct MobileOutlineDrawer: View {
    let outlineItems: [PageOutlineItem]
    let onSelectOutlineItem: (PageOutlineItem) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("大纲")
                        .font(.title3.weight(.semibold))
                    Text(outlineItems.isEmpty ? "暂无标题" : "\(outlineItems.count) 个标题")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "chevron.right")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 34, height: 34)
                        .background(EditorDesignTokens.Colors.controlBackground.color.opacity(0.72))
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关闭大纲")
                .accessibilityIdentifier("editor.mobile-outline.close")
            }

            if outlineItems.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.title3)
                        .foregroundStyle(.secondary.opacity(0.75))
                    Text("暂无大纲")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(EditorDesignTokens.Colors.controlBackgroundSubtle.color)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("editor.mobile-outline.empty")
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(outlineItems) { item in
                            Button {
                                onSelectOutlineItem(item)
                            } label: {
                                HStack(alignment: .center, spacing: 10) {
                                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                                        .fill(MobileActionChrome.accentColor.opacity(item.level == 1 ? 0.72 : 0.28))
                                        .frame(width: 3, height: item.level == 1 ? 22 : 16)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title)
                                            .font(.callout.weight(item.level == 1 ? .semibold : .medium))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        Text("\(item.level) 级标题")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.leading, CGFloat(max(item.level - 1, 0)) * 14)
                                .padding(.vertical, 9)
                                .padding(.horizontal, 10)
                                .background(EditorDesignTokens.Colors.controlBackgroundSubtle.color)
                                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("大纲标题 \(item.title)")
                            .accessibilityValue("\(item.level) 级")
                            .accessibilityIdentifier("editor.mobile-outline.\(item.blockID)")
                        }
                    }
                }
            }
        }
        .padding(.top, 20)
        .padding(.horizontal, 18)
        .padding(.bottom, 22)
    }
}
#endif

private struct ConflictPanel: View {
    let conflicts: [ConflictSnapshot]
    let onAcceptConflict: (ConflictSnapshot) -> Void
    let onAcceptAllConflicts: () -> Void
    let onAcceptLocalConflict: (ConflictSnapshot) -> Void
    let onAcceptAllLocalConflicts: () -> Void
    let onResolveManually: (ConflictSnapshot, String) -> Void
    let onResolveAllManually: ([String: String]) -> Void
    @State private var mergeDrafts = ConflictMergeDrafts()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            ForEach(conflicts) { conflict in
                ConflictResolutionRow(
                    conflict: conflict,
                    mergedText: binding(for: conflict),
                    onUseLocalDraft: { conflict in
                        mergeDrafts.useLocalText(for: conflict)
                    },
                    onUseRemoteDraft: { conflict in
                        mergeDrafts.useRemoteText(for: conflict)
                    },
                    onAcceptConflict: onAcceptConflict,
                    onAcceptLocalConflict: onAcceptLocalConflict,
                    onResolveManually: onResolveManually
                )
            }
        }
        .padding(.top, 10)
        .onChange(of: conflicts.map(\.id)) { _, conflictIDs in
            mergeDrafts.prune(keeping: conflictIDs)
        }
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                headerTitle
                Spacer(minLength: 8)
                headerButtons
            }

            VStack(alignment: .leading, spacing: 6) {
                headerTitle
                HStack(spacing: 8) {
                    headerButtons
                }
            }
        }
    }

    private var headerTitle: some View {
        Text("同步冲突")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var headerButtons: some View {
        Button {
            mergeDrafts.useLocalText(for: conflicts)
        } label: {
            Label("全部使用本地草稿", systemImage: "square.and.pencil")
        }
        .buttonStyle(.borderless)
        .disabled(conflicts.isEmpty)
        .accessibilityIdentifier("editor.conflict.draft-all-local")

        Button {
            mergeDrafts.useRemoteText(for: conflicts)
        } label: {
            Label("全部使用远端草稿", systemImage: "square.and.pencil")
        }
        .buttonStyle(.borderless)
        .disabled(conflicts.isEmpty)
        .accessibilityIdentifier("editor.conflict.draft-all-remote")

        Button {
            onResolveAllManually(currentMergedTexts())
        } label: {
            Label("应用全部合并", systemImage: "checkmark.circle")
        }
        .buttonStyle(.borderless)
        .disabled(conflicts.isEmpty)
        .accessibilityIdentifier("editor.conflict.apply-all-merged")

        Button {
            onAcceptAllLocalConflicts()
        } label: {
            Label("全部保留本地", systemImage: "arrow.up.doc")
        }
        .buttonStyle(.borderless)
        .disabled(conflicts.isEmpty)
        .accessibilityIdentifier("editor.conflict.accept-all-local")

        Button {
            onAcceptAllConflicts()
        } label: {
            Label("全部采用远端", systemImage: "arrow.down.doc")
        }
        .buttonStyle(.borderless)
        .disabled(conflicts.isEmpty)
        .accessibilityIdentifier("editor.conflict.accept-all-remote")
    }

    private func binding(for conflict: ConflictSnapshot) -> Binding<String> {
        Binding(
            get: {
                mergeDrafts.text(for: conflict)
            },
            set: { newValue in
                mergeDrafts.setText(newValue, for: conflict)
            }
        )
    }

    private func currentMergedTexts() -> [String: String] {
        mergeDrafts.mergedTexts(for: conflicts)
    }
}

private struct ConflictResolutionRow: View {
    let conflict: ConflictSnapshot
    @Binding var mergedText: String
    let onUseLocalDraft: (ConflictSnapshot) -> Void
    let onUseRemoteDraft: (ConflictSnapshot) -> Void
    let onAcceptConflict: (ConflictSnapshot) -> Void
    let onAcceptLocalConflict: (ConflictSnapshot) -> Void
    let onResolveManually: (ConflictSnapshot, String) -> Void

    init(
        conflict: ConflictSnapshot,
        mergedText: Binding<String>,
        onUseLocalDraft: @escaping (ConflictSnapshot) -> Void,
        onUseRemoteDraft: @escaping (ConflictSnapshot) -> Void,
        onAcceptConflict: @escaping (ConflictSnapshot) -> Void,
        onAcceptLocalConflict: @escaping (ConflictSnapshot) -> Void,
        onResolveManually: @escaping (ConflictSnapshot, String) -> Void
    ) {
        self.conflict = conflict
        _mergedText = mergedText
        self.onUseLocalDraft = onUseLocalDraft
        self.onUseRemoteDraft = onUseRemoteDraft
        self.onAcceptConflict = onAcceptConflict
        self.onAcceptLocalConflict = onAcceptLocalConflict
        self.onResolveManually = onResolveManually
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(StatusChrome.warningTextToken.color)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 12) {
                        conflictTextColumn(title: "本地", text: conflict.localTextPlain)
                        conflictTextColumn(
                            title: "远端 r\(conflict.remoteRevision)",
                            text: conflict.remoteTextPlain
                        )
                    }

                    ConflictDiffView(
                        segments: ConflictTextDiff.segments(
                            local: conflict.localTextPlain,
                            remote: conflict.remoteTextPlain
                        )
                    )
                    .accessibilityIdentifier("editor.conflict.\(conflict.id).diff")

                    TextEditor(text: $mergedText)
                        .font(.callout)
                        .frame(minHeight: 72)
                        .accessibilityIdentifier("editor.conflict.\(conflict.id).merge-text")

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) {
                            draftButtons
                            resolutionButtons
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                draftButtons
                            }
                            HStack(spacing: 8) {
                                resolutionButtons
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("editor.conflict.\(conflict.id)")
    }

    @ViewBuilder
    private var draftButtons: some View {
        Button {
            onUseLocalDraft(conflict)
        } label: {
            Label("编辑本地", systemImage: "square.and.pencil")
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier("editor.conflict.\(conflict.id).draft-local")

        Button {
            onUseRemoteDraft(conflict)
        } label: {
            Label("编辑远端", systemImage: "square.and.pencil")
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier("editor.conflict.\(conflict.id).draft-remote")
    }

    @ViewBuilder
    private var resolutionButtons: some View {
        Button {
            onResolveManually(conflict, mergedText)
        } label: {
            Label("应用合并", systemImage: "checkmark.circle")
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier("editor.conflict.\(conflict.id).apply-merge")

        Button {
            onAcceptLocalConflict(conflict)
        } label: {
            Label("保留本地", systemImage: "arrow.up.doc")
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier("editor.conflict.\(conflict.id).accept-local")

        Button {
            onAcceptConflict(conflict)
        } label: {
            Label("采用远端", systemImage: "arrow.down.doc")
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier("editor.conflict.\(conflict.id).accept-remote")
    }

    private func conflictTextColumn(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(text.isEmpty ? " " : text)
                .font(.caption)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}

private struct ConflictDiffView: View {
    let segments: [ConflictTextDiffSegment]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(prefix(for: segment.kind))
                        .font(.caption.monospaced())
                        .foregroundStyle(foregroundColor(for: segment.kind))
                        .frame(width: 14, alignment: .center)

                    Text(segment.text.isEmpty ? " " : segment.text)
                        .font(.caption.monospaced())
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(backgroundColor(for: segment.kind))
            }
        }
    }

    private func prefix(for kind: ConflictTextDiffSegmentKind) -> String {
        switch kind {
        case .unchanged:
            return " "
        case .removed:
            return "-"
        case .added:
            return "+"
        }
    }

    private func foregroundColor(for kind: ConflictTextDiffSegmentKind) -> Color {
        switch kind {
        case .unchanged:
            return ConflictDiffChrome.unchangedTextToken.color
        case .removed:
            return ConflictDiffChrome.removedTextToken.color
        case .added:
            return ConflictDiffChrome.addedTextToken.color
        }
    }

    private func backgroundColor(for kind: ConflictTextDiffSegmentKind) -> Color {
        switch kind {
        case .unchanged:
            return ConflictDiffChrome.unchangedFillToken.color
        case .removed:
            return ConflictDiffChrome.removedFillToken.color
        case .added:
            return ConflictDiffChrome.addedFillToken.color
        }
    }
}

private struct MarkdownFileDocument: FileDocument {
    static var markdownContentType: UTType {
        UTType(filenameExtension: "md") ?? .plainText
    }

    static var readableContentTypes: [UTType] {
        [markdownContentType, .plainText]
    }

    var text: String

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = String(decoding: data, as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

private struct BlockFocusRequest: Equatable {
    let id = UUID()
    let blockID: String
    let selection: EditorTextSelection?

    init(blockID: String, selection: EditorTextSelection? = nil) {
        self.blockID = blockID
        self.selection = selection
    }
}

struct QuoteBlockChromeDescriptor: Equatable, Sendable {
    let accessibilityLabel: String
    let accessibilityValue: String
    let accessibilityIdentifier: String

    init(block: BlockSnapshot) {
        accessibilityLabel = "Quote block"
        accessibilityValue = block.textPlain.isEmpty ? "Empty" : block.textPlain
        accessibilityIdentifier = "editor.quote.\(block.id)"
    }
}

struct ListBlockChromeDescriptor: Equatable, Sendable {
    let marker: String
    let accessibilityLabel: String
    let accessibilityValue: String
    let accessibilityIdentifier: String

    init(block: BlockSnapshot, ordinal: Int?) {
        accessibilityValue = block.textPlain.isEmpty ? "Empty" : block.textPlain

        if block.type == .orderedListItem {
            marker = "\(max(ordinal ?? 1, 1))."
            accessibilityLabel = "Numbered list block"
            accessibilityIdentifier = "editor.ordered-list.\(block.id)"
        } else {
            marker = "\u{2022}"
            accessibilityLabel = "Bulleted list block"
            accessibilityIdentifier = "editor.unordered-list.\(block.id)"
        }
    }
}

private struct ListMarkerGlyph: View {
    let descriptor: ListBlockChromeDescriptor
    let nestingLevel: Int
    private let frameDescriptor = ListMarkerGlyphFrameDescriptor()

    var body: some View {
        Group {
            if descriptor.marker.hasSuffix(".") {
                Text(descriptor.marker)
                    .font(.system(size: EditorDesignTokens.Typography.bodySize, weight: .regular))
                    .monospacedDigit()
                    .foregroundStyle(Color.primary)
            } else {
                Text(ListMarkerBulletStyleResolver.isHollow(nestingLevel: nestingLevel) ? "\u{25E6}" : "\u{2022}")
                    .font(.system(size: EditorDesignTokens.Typography.bodySize, weight: .regular))
                    .foregroundStyle(Color.primary)
            }
        }
        .frame(
            width: CGFloat(frameDescriptor.width),
            height: CGFloat(frameDescriptor.height),
            alignment: frameDescriptor.horizontalAlignment.frameAlignment
        )
        .accessibilityHidden(true)
    }
}

private struct ListMarkerBulletGlyph: View {
    let isHollow: Bool
    private let descriptor = ListMarkerBulletGlyphDescriptor()

    var body: some View {
        Group {
            if isHollow {
                Circle()
                    .stroke(Color.primary, lineWidth: CGFloat(descriptor.strokeLineWidth))
            } else {
                Circle()
                    .fill(Color.primary)
            }
        }
        .frame(width: CGFloat(descriptor.diameter), height: CGFloat(descriptor.diameter))
        .offset(
            x: CGFloat(descriptor.visibleLeadingOffset),
            y: CGFloat(descriptor.visibleTopOffset)
        )
        .accessibilityHidden(true)
    }
}

struct ListBlockOrdinalResolver: Equatable, Sendable {
    static func ordinal(for block: BlockSnapshot, at index: Int, in blocks: [BlockSnapshot]) -> Int? {
        guard block.type == .orderedListItem,
              blocks.indices.contains(index),
              blocks[index].id == block.id else {
            return nil
        }

        var ordinal = 1
        var candidateIndex = index - 1
        while candidateIndex >= 0 {
            let candidate = blocks[candidateIndex]
            if candidate.parentBlockID == block.parentBlockID {
                guard candidate.type == .orderedListItem else {
                    break
                }
                ordinal += 1
            }
            candidateIndex -= 1
        }
        return ordinal
    }
}

struct HeadingBlockChromeDescriptor: Equatable, Sendable {
    let level: Int
    let accentWidth: Double
    let accentVerticalInset: Double
    let textLeadingPadding: Double
    let verticalPadding: Double
    let horizontalPadding: Double
    let backgroundOpacity: Double
    let cornerRadius: Double
    let accessibilityLabel: String
    let accessibilityValue: String
    let accessibilityIdentifier: String

    init(block: BlockSnapshot) {
        switch block.type {
        case .heading1:
            level = 1
            accessibilityLabel = "一级标题块"
            accessibilityIdentifier = "editor.heading1.\(block.id)"
        case .heading2:
            level = 2
            accessibilityLabel = "二级标题块"
            accessibilityIdentifier = "editor.heading2.\(block.id)"
        case .heading3:
            level = 3
            accessibilityLabel = "三级标题块"
            accessibilityIdentifier = "editor.heading3.\(block.id)"
        case .heading4:
            level = 4
            accessibilityLabel = "四级标题块"
            accessibilityIdentifier = "editor.heading4.\(block.id)"
        case .heading5:
            level = 5
            accessibilityLabel = "五级标题块"
            accessibilityIdentifier = "editor.heading5.\(block.id)"
        case .heading6:
            level = 6
            accessibilityLabel = "六级标题块"
            accessibilityIdentifier = "editor.heading6.\(block.id)"
        default:
            level = 0
            accessibilityLabel = "文本块"
            accessibilityIdentifier = "editor.block.\(block.id)"
        }
        let resolvedLevel = max(1, level)
        accentWidth = resolvedLevel == 1 ? 5 : resolvedLevel == 2 ? 4 : 3
        accentVerticalInset = resolvedLevel == 1 ? 5 : resolvedLevel == 2 ? 6 : 7
        textLeadingPadding = resolvedLevel == 1 ? 16 : resolvedLevel == 2 ? 14 : 12
        verticalPadding = resolvedLevel <= 2 ? 6 : 4
        horizontalPadding = 10
        backgroundOpacity = resolvedLevel == 1 ? 0.15 : resolvedLevel == 2 ? 0.11 : 0.075
        cornerRadius = resolvedLevel == 1 ? 7 : 6
        accessibilityValue = block.textPlain.isEmpty ? "空" : block.textPlain
    }
}

enum DividerBlockAxis: Equatable, Sendable {
    case horizontal
}

struct DividerBlockChromeDescriptor: Equatable, Sendable {
    let accessibilityLabel: String
    let accessibilityValue: String
    let accessibilityIdentifier: String
    let axis: DividerBlockAxis
    let height: Double
    let waveAmplitude: Double
    let loopCount: Int
    let strokeOpacity: Double
    let strokeWidth: Double
    let casualVariance: Double

    init(block: BlockSnapshot) {
        accessibilityLabel = "分割线块"
        accessibilityValue = "分割线"
        accessibilityIdentifier = "editor.divider.\(block.id)"
        axis = .horizontal
        height = 56
        waveAmplitude = 12
        loopCount = 5
        strokeOpacity = 0.58
        strokeWidth = 1.6
        casualVariance = 0.16
    }
}

private struct CraftDividerBlockRow: View {
    let descriptor: DividerBlockChromeDescriptor

    var body: some View {
        Canvas { context, size in
            guard size.width > 1, size.height > 1 else {
                return
            }

            var path = Path()
            let midY = size.height * 0.5
            let left = size.width * 0.04
            let right = size.width * 0.96
            let loopWidth = min(38, max(28, size.width / 22))
            let loopTotalWidth = loopWidth * CGFloat(descriptor.loopCount)
            let loopStart = max(left + 20, (size.width - loopTotalWidth) / 2)
            let loopEnd = min(right - 20, loopStart + loopTotalWidth)
            let amplitude = CGFloat(descriptor.waveAmplitude)
            let variance = CGFloat(descriptor.casualVariance)

            path.move(to: CGPoint(x: left, y: midY))
            path.addCurve(
                to: CGPoint(x: loopStart, y: midY),
                control1: CGPoint(x: left + (loopStart - left) * 0.16, y: midY + amplitude * (0.86 + variance)),
                control2: CGPoint(x: loopStart - (loopStart - left) * 0.24, y: midY + amplitude * (0.42 + variance * 0.4))
            )

            for index in 0..<descriptor.loopCount {
                let startX = loopStart + CGFloat(index) * loopWidth
                let sway = CGFloat(index % 2 == 0 ? 1 : -1) * variance
                let middleX = startX + loopWidth * (0.50 + sway * 0.10)
                let endX = startX + loopWidth
                let topScale = 1.22 - CGFloat(index % 3) * variance * 0.18
                let bottomScale = 1.06 + CGFloat(index % 2) * variance * 0.5
                path.addCurve(
                    to: CGPoint(x: middleX, y: midY),
                    control1: CGPoint(x: startX + loopWidth * (0.13 + sway * 0.04), y: midY - amplitude * topScale),
                    control2: CGPoint(x: middleX - loopWidth * (0.24 - sway * 0.05), y: midY - amplitude * (topScale + variance * 0.25))
                )
                path.addCurve(
                    to: CGPoint(x: endX, y: midY),
                    control1: CGPoint(x: middleX + loopWidth * (0.22 + sway * 0.03), y: midY + amplitude * bottomScale),
                    control2: CGPoint(x: endX - loopWidth * (0.16 - sway * 0.04), y: midY + amplitude * (bottomScale + variance * 0.22))
                )
            }

            path.addCurve(
                to: CGPoint(x: right, y: midY),
                control1: CGPoint(x: loopEnd + (right - loopEnd) * 0.22, y: midY - amplitude * 0.5),
                control2: CGPoint(x: right - (right - loopEnd) * 0.18, y: midY - amplitude * 0.9)
            )

            context.stroke(
                path,
                with: .color(Color.primary.opacity(descriptor.strokeOpacity)),
                style: StrokeStyle(
                    lineWidth: CGFloat(descriptor.strokeWidth),
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }
        .frame(maxWidth: .infinity)
        .frame(height: CGFloat(descriptor.height))
    }
}

struct AttachmentBlockChromeDescriptor: Equatable, Sendable {
    let accessibilityLabel: String
    let accessibilityValue: String
    let accessibilityIdentifier: String

    init(
        block: BlockSnapshot,
        attachment: AttachmentSnapshot?,
        generationStatus: AttachmentPreviewGenerationStatus
    ) {
        let kindTitle = Self.kindTitle(for: block)
        let filename = block.textPlain.isEmpty
            ? attachment?.originalFilename ?? "未命名附件"
            : block.textPlain
        let previewState = attachment?.previewState(for: block) ?? .unavailable

        accessibilityLabel = "\(kindTitle)附件：\(filename)"
        accessibilityIdentifier = "editor.attachment.\(block.id)"
        let statusLabel = Self.statusLabel(
            attachment: attachment,
            generationStatus: generationStatus,
            previewState: previewState
        )
        accessibilityValue = "\(kindTitle), \(statusLabel)"
    }

    private static func statusLabel(
        attachment: AttachmentSnapshot?,
        generationStatus: AttachmentPreviewGenerationStatus,
        previewState: AttachmentPreviewState
    ) -> String {
        guard attachment != nil else {
            return "附件不可用"
        }

        if case .failed = generationStatus {
            return "预览失败"
        }

        if generationStatus == .generating || previewState == .pending {
            return "正在生成预览"
        }

        if case .thumbnail = previewState {
            return "预览就绪"
        }

        return "就绪"
    }

    private static func kindTitle(for block: BlockSnapshot) -> String {
        switch block.type {
        case .attachmentImage:
            return "图片"
        case .attachmentVideo:
            return "视频"
        case .attachmentFile:
            return "文件"
        default:
            return "附件"
        }
    }
}

#if os(iOS)
private struct MobileBlockRowSwipeGestureModifier: ViewModifier {
    let attachment: MobileBlockRowSwipeGestureAttachment
    let onSwipe: (CGSize) -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        switch attachment {
        case .nativeTextEditorOnly:
            content
        case .rowHighPriority:
            content.highPriorityGesture(
                DragGesture(minimumDistance: 24, coordinateSpace: .local)
                    .onEnded { value in
                        onSwipe(value.translation)
                    }
            )
        }
    }
}

private struct MobileBlockRowDraggableModifier: ViewModifier {
    let isEnabled: Bool
    let dragPayloadText: String
    let block: BlockSnapshot

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content.draggable(dragPayloadText) {
                DragPreviewBlock(block: block)
            }
        } else {
            content
        }
    }
}

private struct BlockRowContextMenuModifier<MenuContent: View>: ViewModifier {
    let isEnabled: Bool
    @ViewBuilder let menuContent: () -> MenuContent

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content.contextMenu(menuItems: menuContent)
        } else {
            content
        }
    }
}

private struct MobileBlockRowDropTargetModifier: ViewModifier {
    let isEnabled: Bool
    let destinationBlockID: String
    @Binding var activeDropTarget: BlockDropTarget?
    let destinationLevel: Int
    let moveDroppedBlocks: ([String], String, BlockDropPlacement, Int?) -> Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content.onDrop(
                of: [UTType.plainText.identifier, UTType.text.identifier],
                delegate: EditorBlockDropDelegate(
                    destinationBlockID: destinationBlockID,
                    slotKind: .body,
                    activeDropTarget: $activeDropTarget,
                    destinationLevel: destinationLevel,
                    moveDroppedBlocks: moveDroppedBlocks
                )
            )
        } else {
            content
        }
    }
}
#endif

enum SearchHighlightOverlayPolicy {
    static let rectCornerRadius: CGFloat = 3

    static var rowFillColor: Color {
        EditorDesignTokens.Colors.searchHighlightFill.color.opacity(0.24)
    }

    static var rectFillColor: Color {
        EditorDesignTokens.Colors.searchHighlightFill.color.opacity(0.30)
    }

    static var rectStrokeColor: Color {
        EditorDesignTokens.Colors.searchHighlightStroke.color.opacity(0.56)
    }

    static func highlightsWholeRow(rectCount: Int) -> Bool {
        rectCount == 0
    }

    static func displayRects(
        highlightRects: [SearchResultHighlightRect],
        imageSize: CGSize
    ) -> [CGRect] {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return []
        }

        return highlightRects.map { rect in
            let x = clamped(rect.x)
            let y = clamped(rect.y)
            let width = clamped(rect.width)
            let height = clamped(rect.height)
            let maxWidth = max(0, 1 - x)
            let maxHeight = max(0, 1 - y)
            let resolvedWidth = min(width, maxWidth)
            let resolvedHeight = min(height, maxHeight)

            return CGRect(
                x: x * imageSize.width,
                y: (1 - y - resolvedHeight) * imageSize.height,
                width: resolvedWidth * imageSize.width,
                height: resolvedHeight * imageSize.height
            )
        }
    }

    private static func clamped(_ value: Double) -> CGFloat {
        CGFloat(min(max(value, 0), 1))
    }
}

private struct BlockRowView: View {
    let block: BlockSnapshot
    let attachment: AttachmentSnapshot?
    let attachmentPreviewGenerationStatus: AttachmentPreviewGenerationStatus
    let searchHighlight: SearchTransientHighlight?
    let pageReferencePreviewText: String?
    let contentFont: EditorContentFont
    let editorSession: EditorSession
    let nestingLevel: Int
    let listOrdinal: Int?
    let dragPayloadBlockIDs: [String]
    let canMoveUp: Bool
    let canMoveDown: Bool
    let isFocusModeActive: Bool
    let onToggleFocusMode: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onMoveByKeyboard: (BlockKeyboardMoveDirection) -> Bool
    let onMoveFocusByKeyboard: (BlockKeyboardFocusDirection) -> Bool
    let onExtendBlockSelectionByKeyboard: (BlockKeyboardFocusDirection) -> Bool
    let onApplyInlineFormatByKeyboard: (MarkdownInlineFormat, EditorTextSelection) -> Bool
    let onInsertLinkByKeyboard: (EditorTextSelection) -> Bool
    let onInsertBlockAfter: (EditorTextSelection) -> EditorTextSelection?
    let onReplaceTextAtSelection: (EditorTextSelection, String) -> EditorTextSelection?
    let onPasteTextAtSelection: (EditorTextSelection, String) -> EditorTextSelection?
    let onMergeBlockWithPrevious: (EditorTextSelection) -> Bool
    let onMergeBlockWithNext: (EditorTextSelection) -> Bool
    let onIndent: () -> Bool
    let onOutdent: () -> Bool
    let onPasteAttachmentURLs: ([URL]) -> Bool
    let onDelete: () -> Void
    let canUndoTextEdit: Bool
    let onUndoTextEdit: () -> Void
    let onOpenPageReference: (String) -> Void
    let onOpenBlockReference: (String, String) -> Void
    let onChangeType: (BlockType) -> Void
    let onConvertToPage: () -> Void
    let onTaskItemCompletionChange: (Bool) -> Void
    let onCodeBlockLineWrappingChange: (Bool) -> Void
    let onToggleBlockExpansion: () -> Void
    let onRetryAttachmentPreview: (String) -> Void
    let onRenameAttachmentImage: (String) -> Void
    let onAttachmentImageDisplayWidthChange: (Double) -> Void
    let onRequestAttachmentImport: (BlockType) -> Void
    let onCreateDrawingBlock: () -> Void
    let onDrawingDataChange: (Data) -> Void
    let isToggleBlockExpanded: Bool
    let isMobileOutlinePresented: Bool
    let onRevealPageList: () -> Void
    let onRevealOutline: () -> Void
    let onCloseOutline: () -> Void
    let isMobileSelectionModeActive: Bool
    let isBlockSelected: Bool
    let selectionResetRequest: TransientSelectionResetRequest
    let dropPlacement: BlockDropPlacement?
    let focusRequestID: UUID?
    let focusSelection: EditorTextSelection?
    let onFocusRequestHandled: () -> Void
    let onSelectCurrentBlock: () -> Void
    let onToggleBlockSelection: () -> Void
    let onSelectAllBlocksByKeyboard: () -> Bool
    let onClearDropTarget: () -> Void
    let onClearTransientSelections: (String?) -> Void
    let onTableRowsChange: ([[String]]) -> Void
    let onTextChange: (String) -> Void
    @State private var isRowHovered = false
    @State private var rowFocusRequest: BlockFocusRequest?
    @State private var slashCommandSelectionIndex = 0
    @State private var slashCommandSelectionSource: SlashCommandSelectionSource = .keyboard
    @State private var isAttachmentRenameAlertPresented = false
    @State private var attachmentRenameText = ""
    @State private var isAttachmentResizeActive = false
#if os(iOS)
    @State private var mobileFormatPaletteTab: MobileFormatPaletteTab = .more
    @State private var isMobileFormatPanelPresented = false
#endif

    init(
        block: BlockSnapshot,
        attachment: AttachmentSnapshot? = nil,
        attachmentPreviewGenerationStatus: AttachmentPreviewGenerationStatus = .idle,
        searchHighlight: SearchTransientHighlight? = nil,
        pageReferencePreviewText: String? = nil,
        contentFont: EditorContentFont = EditorContentFont.defaultFont,
        editorSession: EditorSession,
        nestingLevel: Int = 0,
        listOrdinal: Int? = nil,
        dragPayloadBlockIDs: [String] = [],
        canMoveUp: Bool = false,
        canMoveDown: Bool = false,
        isFocusModeActive: Bool = false,
        onToggleFocusMode: @escaping () -> Void = {},
        onMoveUp: @escaping () -> Void = {},
        onMoveDown: @escaping () -> Void = {},
        onMoveByKeyboard: @escaping (BlockKeyboardMoveDirection) -> Bool = { _ in false },
        onMoveFocusByKeyboard: @escaping (BlockKeyboardFocusDirection) -> Bool = { _ in false },
        onExtendBlockSelectionByKeyboard: @escaping (BlockKeyboardFocusDirection) -> Bool = { _ in false },
        onApplyInlineFormatByKeyboard: @escaping (MarkdownInlineFormat, EditorTextSelection) -> Bool = { _, _ in false },
        onInsertLinkByKeyboard: @escaping (EditorTextSelection) -> Bool = { _ in false },
        onInsertBlockAfter: @escaping (EditorTextSelection) -> EditorTextSelection? = { _ in nil },
        onReplaceTextAtSelection: @escaping (EditorTextSelection, String) -> EditorTextSelection? = { _, _ in nil },
        onPasteTextAtSelection: @escaping (EditorTextSelection, String) -> EditorTextSelection? = { _, _ in nil },
        onMergeBlockWithPrevious: @escaping (EditorTextSelection) -> Bool = { _ in false },
        onMergeBlockWithNext: @escaping (EditorTextSelection) -> Bool = { _ in false },
        onIndent: @escaping () -> Bool = { false },
        onOutdent: @escaping () -> Bool = { false },
        onPasteAttachmentURLs: @escaping ([URL]) -> Bool = { _ in false },
        onDelete: @escaping () -> Void = {},
        canUndoTextEdit: Bool = false,
        onUndoTextEdit: @escaping () -> Void = {},
        onOpenPageReference: @escaping (String) -> Void = { _ in },
        onOpenBlockReference: @escaping (String, String) -> Void = { _, _ in },
        onChangeType: @escaping (BlockType) -> Void = { _ in },
        onConvertToPage: @escaping () -> Void = {},
        onTaskItemCompletionChange: @escaping (Bool) -> Void = { _ in },
        onCodeBlockLineWrappingChange: @escaping (Bool) -> Void = { _ in },
        onToggleBlockExpansion: @escaping () -> Void = {},
        onRetryAttachmentPreview: @escaping (String) -> Void = { _ in },
        onRenameAttachmentImage: @escaping (String) -> Void = { _ in },
        onAttachmentImageDisplayWidthChange: @escaping (Double) -> Void = { _ in },
        onRequestAttachmentImport: @escaping (BlockType) -> Void = { _ in },
        onCreateDrawingBlock: @escaping () -> Void = {},
        onDrawingDataChange: @escaping (Data) -> Void = { _ in },
        isToggleBlockExpanded: Bool = true,
        isMobileOutlinePresented: Bool = false,
        onRevealPageList: @escaping () -> Void = {},
        onRevealOutline: @escaping () -> Void = {},
        onCloseOutline: @escaping () -> Void = {},
        isMobileSelectionModeActive: Bool = false,
        isBlockSelected: Bool = false,
        selectionResetRequest: TransientSelectionResetRequest = .none,
        dropPlacement: BlockDropPlacement? = nil,
        focusRequestID: UUID? = nil,
        focusSelection: EditorTextSelection? = nil,
        onFocusRequestHandled: @escaping () -> Void = {},
        onSelectCurrentBlock: @escaping () -> Void = {},
        onToggleBlockSelection: @escaping () -> Void = {},
        onSelectAllBlocksByKeyboard: @escaping () -> Bool = { false },
        onClearDropTarget: @escaping () -> Void = {},
        onClearTransientSelections: @escaping (String?) -> Void = { _ in },
        onTableRowsChange: @escaping ([[String]]) -> Void = { _ in },
        onTextChange: @escaping (String) -> Void
    ) {
        self.block = block
        self.attachment = attachment
        self.attachmentPreviewGenerationStatus = attachmentPreviewGenerationStatus
        self.searchHighlight = searchHighlight
        self.pageReferencePreviewText = pageReferencePreviewText
        self.contentFont = contentFont
        self.editorSession = editorSession
        self.nestingLevel = nestingLevel
        self.listOrdinal = listOrdinal
        self.dragPayloadBlockIDs = dragPayloadBlockIDs
        self.canMoveUp = canMoveUp
        self.canMoveDown = canMoveDown
        self.isFocusModeActive = isFocusModeActive
        self.onToggleFocusMode = onToggleFocusMode
        self.onMoveUp = onMoveUp
        self.onMoveDown = onMoveDown
        self.onMoveByKeyboard = onMoveByKeyboard
        self.onMoveFocusByKeyboard = onMoveFocusByKeyboard
        self.onExtendBlockSelectionByKeyboard = onExtendBlockSelectionByKeyboard
        self.onApplyInlineFormatByKeyboard = onApplyInlineFormatByKeyboard
        self.onInsertLinkByKeyboard = onInsertLinkByKeyboard
        self.onInsertBlockAfter = onInsertBlockAfter
        self.onReplaceTextAtSelection = onReplaceTextAtSelection
        self.onPasteTextAtSelection = onPasteTextAtSelection
        self.onMergeBlockWithPrevious = onMergeBlockWithPrevious
        self.onMergeBlockWithNext = onMergeBlockWithNext
        self.onIndent = onIndent
        self.onOutdent = onOutdent
        self.onPasteAttachmentURLs = onPasteAttachmentURLs
        self.onDelete = onDelete
        self.canUndoTextEdit = canUndoTextEdit
        self.onUndoTextEdit = onUndoTextEdit
        self.onOpenPageReference = onOpenPageReference
        self.onOpenBlockReference = onOpenBlockReference
        self.onChangeType = onChangeType
        self.onConvertToPage = onConvertToPage
        self.onTaskItemCompletionChange = onTaskItemCompletionChange
        self.onCodeBlockLineWrappingChange = onCodeBlockLineWrappingChange
        self.onToggleBlockExpansion = onToggleBlockExpansion
        self.onRetryAttachmentPreview = onRetryAttachmentPreview
        self.onRenameAttachmentImage = onRenameAttachmentImage
        self.onAttachmentImageDisplayWidthChange = onAttachmentImageDisplayWidthChange
        self.onRequestAttachmentImport = onRequestAttachmentImport
        self.onCreateDrawingBlock = onCreateDrawingBlock
        self.onDrawingDataChange = onDrawingDataChange
        self.isToggleBlockExpanded = isToggleBlockExpanded
        self.isMobileOutlinePresented = isMobileOutlinePresented
        self.onRevealPageList = onRevealPageList
        self.onRevealOutline = onRevealOutline
        self.onCloseOutline = onCloseOutline
        self.isMobileSelectionModeActive = isMobileSelectionModeActive
        self.isBlockSelected = isBlockSelected
        self.selectionResetRequest = selectionResetRequest
        self.dropPlacement = dropPlacement
        self.focusRequestID = focusRequestID
        self.focusSelection = focusSelection
        self.onFocusRequestHandled = onFocusRequestHandled
        self.onSelectCurrentBlock = onSelectCurrentBlock
        self.onToggleBlockSelection = onToggleBlockSelection
        self.onSelectAllBlocksByKeyboard = onSelectAllBlocksByKeyboard
        self.onClearDropTarget = onClearDropTarget
        self.onClearTransientSelections = onClearTransientSelections
        self.onTableRowsChange = onTableRowsChange
        self.onTextChange = onTextChange
    }

    var body: some View {
        HStack(alignment: .top, spacing: CGFloat(EditorBlockChrome.actionColumnSpacing)) {
            blockActionColumn
            blockContent
#if os(iOS)
                .allowsHitTesting(!isMobileSelectionModeActive)
#endif
        }
        .padding(.vertical, CGFloat(EditorBlockChrome.rowVerticalPadding))
        .padding(.leading, CGFloat(BlockRowNestingIndentResolver.leadingPadding(
            nestingLevel: nestingLevel,
            blockType: block.type
        )))
        .padding(.horizontal, 4)
        .padding(.leading, -CGFloat(EditorCanvasChromeLayout.blockRowTitleAlignmentCompensation))
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .contentShape(Rectangle())
#if os(iOS)
        .modifier(
            BlockRowContextMenuModifier(
                isEnabled: MobileBlockContextMenuPolicy.enablesRowContextMenu(
                    usesNativeTextEditor: usesNativeTextEditor
                )
            ) {
                blockContextCommands
            }
        )
#else
        .contextMenu {
            blockContextCommands
        }
#endif
#if os(iOS)
        .modifier(
            MobileBlockRowDraggableModifier(
                isEnabled: MobileBlockDragActivationPolicy.usesLongPressDraggableRow,
                dragPayloadText: dragPayloadText,
                block: block
            )
        )
#endif
        .alert("修改图片名字", isPresented: $isAttachmentRenameAlertPresented) {
            TextField("图片名字", text: $attachmentRenameText)
            Button("保存") {
                commitAttachmentRename()
            }
            .disabled(attachmentRenameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("取消", role: .cancel) {}
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(rowAccessibilityIdentifier)
        .accessibilityLabel(rowAccessibilityValue)
        .accessibilityValue(rowAccessibilityValue)
        .simultaneousGesture(
            TapGesture().onEnded {
                handleRowTap()
            }
        )
#if os(iOS)
        .modifier(
            MobileBlockRowSwipeGestureModifier(
                attachment: MobileBlockRowSwipeGestureAttachmentResolver.attachment(
                    usesNativeTextEditor: usesNativeTextEditor
                ),
                onSwipe: { translation in
                    handleMobileHorizontalSwipe(translation: translation)
                }
            )
        )
        .onChange(of: editorSession.focusedBlockID) { _, focusedBlockID in
            if let focusedBlockID, focusedBlockID != block.id {
                resetMobileFormatPanelForInactiveRow()
            }
        }
        .onDisappear {
            resetMobileFormatPanelForInactiveRow()
        }
#endif
#if os(macOS)
        .onHover { hovering in
            isRowHovered = hovering
        }
#endif
        .animation(.easeInOut(duration: 0.12), value: isRowActive)
        .animation(.easeInOut(duration: 0.12), value: isBlockSelected)
        .animation(.easeInOut(duration: 0.16), value: searchHighlight?.id)
        .onAppear {
            handleNonEditableFocusRequestIfNeeded(effectiveFocusRequestID)
        }
        .onChange(of: effectiveFocusRequestID) { _, requestID in
            handleNonEditableFocusRequestIfNeeded(requestID)
        }
#if os(macOS)
        .background(
            NonEditableBlockKeyboardFocusBridge(
                isEnabled: NonEditableBlockKeyboardBridgeActivationResolver.isEnabled(
                    blockType: block.type,
                    isBlockSelected: isBlockSelected
                )
            ) { direction in
                onMoveFocusByKeyboard(direction)
            }
            .frame(width: 0, height: 0)
        )
#endif
    }

    @ViewBuilder
    private var blockContent: some View {
        if block.type == .table {
            StructuredTableBlockEditor(
                blockID: block.id,
                text: block.textPlain,
                rows: block.tableRows,
                focusedBlockID: editorSession.focusedBlockID,
                selectionResetRequest: selectionResetRequest,
                onClearExternalSelections: {
                    onClearTransientSelections(block.id)
                },
                onRowsChange: onTableRowsChange,
                onMoveFocusByKeyboard: onMoveFocusByKeyboard
            )
            .onTapGesture {
                onClearDropTarget()
            }
        } else if block.type.isTextEditable {
            VStack(alignment: .leading, spacing: 4) {
                textEditableBlockContent
                    .frame(maxWidth: .infinity, alignment: .leading)
                slashCommandMenu
            }
        } else if block.type == .pageReference {
            PageReferenceBlockRow(
                block: block,
                previewText: pageReferencePreviewText,
                onOpenPageReference: onOpenPageReference
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if block.type == .blockReference {
            BlockReferenceBlockRow(block: block, onOpenBlockReference: onOpenBlockReference)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if block.type == .divider {
            let descriptor = DividerBlockChromeDescriptor(block: block)
            CraftDividerBlockRow(descriptor: descriptor)
                .accessibilityLabel(descriptor.accessibilityLabel)
                .accessibilityValue(descriptor.accessibilityValue)
                .accessibilityIdentifier(descriptor.accessibilityIdentifier)
        } else if block.type == .drawing {
            DrawingBlockRow(
                block: block,
                attachment: attachment,
                onDataChange: onDrawingDataChange
            )
        } else {
            AttachmentBlockRow(
                block: block,
                attachment: attachment,
                generationStatus: attachmentPreviewGenerationStatus,
                searchHighlight: searchHighlight,
                isBlockSelected: isBlockSelected,
                onRetryPreview: onRetryAttachmentPreview,
                onImageResizeActiveChange: { isActive in
                    isAttachmentResizeActive = isActive
                },
                onImageDisplayWidthChange: onAttachmentImageDisplayWidthChange
            )
        }
    }

    private var rowBackground: some View {
        let borderOpacity = BlockRowSelectionBorderPolicy.opacity(
            blockType: block.type,
            isSelected: isBlockSelected,
            suppressesSelectionChrome: suppressesSelectionChrome
        )
        return RoundedRectangle(cornerRadius: CGFloat(EditorDesignTokens.Layout.rowCornerRadius), style: .continuous)
            .fill(rowBackgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: CGFloat(EditorDesignTokens.Layout.rowCornerRadius), style: .continuous)
                    .stroke(EditorDesignTokens.Colors.accent.color.opacity(borderOpacity), lineWidth: 1)
            )
    }

    private var rowBackgroundColor: Color {
        if let searchHighlight,
           SearchHighlightOverlayPolicy.highlightsWholeRow(rectCount: searchHighlight.rects.count) {
            return SearchHighlightOverlayPolicy.rowFillColor
        }
        let opacity = BlockRowBackgroundPolicy.opacity(
            blockType: block.type,
            isSelected: isBlockSelected,
            isFocused: editorSession.focusedBlockID == block.id,
            isSlashCommandMenuVisible: isSlashCommandMenuVisible,
            suppressesSelectionChrome: suppressesSelectionChrome
        )
        guard opacity > 0 else {
            return Color.clear
        }
        if isBlockSelected {
            return EditorDesignTokens.Colors.accent.color.opacity(opacity)
        }
        return EditorDesignTokens.Colors.border.color.opacity(opacity)
    }

    private var suppressesSelectionChrome: Bool {
        block.type == .attachmentImage && isAttachmentResizeActive
    }

    private var isRowActive: Bool {
        isRowHovered || isBlockSelected || editorSession.focusedBlockID == block.id
    }

    private var isSlashCommandMenuVisible: Bool {
        editorSession.focusedBlockID == block.id
            && block.textPlain.hasPrefix("/")
            && !SlashCommandResolver.matchingCommands(for: block.textPlain).isEmpty
    }

    private var usesNativeTextEditor: Bool {
        block.type.isTextEditable && block.type != .table
    }

    private var blockActionOpacity: Double {
#if os(macOS)
        BlockDragHandleVisibilityPolicy.opacity(isHovered: isRowHovered)
#else
        MobileBlockDragHandleVisibilityPolicy.opacity(
            isSelectionModeActive: isMobileSelectionModeActive
        )
#endif
    }

    @ViewBuilder
    private var blockActionColumn: some View {
#if os(iOS)
        if MobileBlockSelectionChromeResolver.isSelectionControlVisible(
            isSelectionModeActive: isMobileSelectionModeActive
        ) {
            Image(systemName: MobileBlockSelectionChromeResolver.symbolName(isSelected: isBlockSelected))
                .font(.callout.weight(isBlockSelected ? .semibold : .regular))
                .foregroundStyle(isBlockSelected ? MobileActionChrome.accentColor : Color.secondary.opacity(0.72))
            .frame(width: CGFloat(EditorBlockChrome.dragHandleWidth), height: 24)
            .contentShape(Rectangle())
            .padding(.top, 0)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(isBlockSelected ? "取消选择块" : "选择块")
            .accessibilityValue(block.type.editorMenuTitle)
            .accessibilityIdentifier("editor.block.\(block.id).selection-toggle")
        } else {
            dragHandleColumn
        }
#else
        dragHandleColumn
#endif
    }

    private var dragHandleColumn: some View {
        Image(systemName: "circle.grid.2x2")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .draggable(dragPayloadText) {
                DragPreviewBlock(block: block)
            }
            .accessibilityLabel("块拖拽手柄")
            .accessibilityValue(block.type.editorMenuTitle)
            .accessibilityHint("长按并拖动调整块位置或层级")
            .accessibilityIdentifier("editor.block.\(block.id).drag-handle")
            .frame(width: CGFloat(EditorBlockChrome.dragHandleWidth), height: 20)
            .contentShape(Rectangle())
            .padding(.top, 2)
            .opacity(blockActionOpacity)
    }

    private var dragPayloadText: String {
        let payloadBlockIDs = dragPayloadBlockIDs.isEmpty ? [block.id] : dragPayloadBlockIDs
        return payloadBlockIDs.joined(separator: "\n")
    }

    private var dropIndicatorAlignment: Alignment {
        switch dropPlacement {
        case .before:
            return .topLeading
        case .after, .childAfter, .outdentAfter, nil:
            return .bottomLeading
        }
    }

    private func dropIndicatorLeadingPadding(for placement: BlockDropPlacement) -> CGFloat {
        placement == .childAfter ? 28 : 0
    }

    private func dropIndicatorVerticalOffset(for placement: BlockDropPlacement) -> CGFloat {
        switch placement {
        case .before:
            return -CGFloat(EditorBlockChrome.dropIndicatorAfterOffset)
        case .after, .childAfter, .outdentAfter:
            return CGFloat(EditorBlockChrome.dropIndicatorAfterOffset)
        }
    }

    @ViewBuilder
    private var slashCommandMenu: some View {
        let commands = SlashCommandResolver.matchingCommands(for: block.textPlain)
        if editorSession.focusedBlockID == block.id,
           block.textPlain.hasPrefix("/"),
           !commands.isEmpty {
            SlashCommandMenu(
                commands: commands,
                selectedIndex: clampedSlashCommandSelectionIndex(for: commands),
                scrollsSelectionIntoView: SlashCommandMenuScrollPolicy.shouldScrollSelectionIntoView(
                    source: slashCommandSelectionSource
                ),
                onHover: { index in
                    guard slashCommandSelectionIndex != index || slashCommandSelectionSource != .hover else {
                        return
                    }
                    slashCommandSelectionSource = .hover
                    slashCommandSelectionIndex = index
                },
                onSelect: applySlashCommand
            )
            .padding(.top, 2)
        }
    }

    @ViewBuilder
    private var blockContextCommands: some View {
        Button {
            _ = onInsertBlockAfter(blockEndSelection)
        } label: {
            Label("下方新增", systemImage: "plus")
        }

        if block.type == .attachmentImage {
            Button {
                presentAttachmentRename()
            } label: {
                Label("修改名字", systemImage: "pencil")
            }
        }

        if block.type.isTextEditable {
            Divider()

            Button {
                onConvertToPage()
            } label: {
                Label("页面", systemImage: "doc.text")
            }

            ForEach(Self.textBlockMenuTypes, id: \.self) { type in
                Button {
                    onChangeType(type)
                } label: {
                    Label(type.editorMenuTitle, systemImage: type.editorMenuSystemImage)
                }
            }
        }

        Divider()

        Button {
            onMoveUp()
        } label: {
            Label("上移", systemImage: "chevron.up")
        }
        .disabled(!canMoveUp)

        Button {
            onMoveDown()
        } label: {
            Label("下移", systemImage: "chevron.down")
        }
        .disabled(!canMoveDown)

        Button {
            _ = onOutdent()
        } label: {
            Label("减少缩进", systemImage: "decrease.indent")
        }
        .disabled(nestingLevel == 0)

        Button {
            _ = onIndent()
        } label: {
            Label("增加缩进", systemImage: "increase.indent")
        }
        .disabled(!canMoveUp)

        Divider()

        Button(role: .destructive) {
            onDelete()
        } label: {
            Label("删除", systemImage: "trash")
        }
    }

    private var blockEndSelection: EditorTextSelection {
        EditorTextSelection(
            blockID: block.id,
            location: (block.textPlain as NSString).length,
            length: 0
        )
    }

    private func presentAttachmentRename() {
        attachmentRenameText = AttachmentImageCaptionVisibilityPolicy.isVisible(
            blockText: block.textPlain,
            originalFilename: attachment?.originalFilename
        ) ? block.textPlain : ""
        isAttachmentRenameAlertPresented = true
    }

    private func commitAttachmentRename() {
        let displayName = attachmentRenameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !displayName.isEmpty else {
            return
        }
        onRenameAttachmentImage(displayName)
    }

    private var effectiveFocusRequestID: UUID? {
        rowFocusRequest?.id ?? focusRequestID
    }

    private var effectiveFocusSelection: EditorTextSelection? {
        rowFocusRequest?.selection ?? focusSelection
    }

    private var rowAccessibilityIdentifier: String {
        switch block.type {
        case .pageReference:
            return "editor.page-reference.\(block.id)"
        case .blockReference:
            return "editor.block-reference.\(block.id)"
        default:
            return "editor.block.\(block.id)"
        }
    }

    private var rowAccessibilityValue: String {
        let selectionState = isBlockSelected ? "当前块已选中" : "当前块未选中"
        let content = block.textPlain.isEmpty ? "空" : block.textPlain
        return "\(content), \(selectionState)"
    }

    @ViewBuilder
    private var textEditableBlockContent: some View {
        if block.type.isHeading {
            let descriptor = HeadingBlockChromeDescriptor(block: block)
            nativeTextBlockEditor
                .padding(.leading, CGFloat(descriptor.textLeadingPadding))
                .padding(.trailing, CGFloat(descriptor.horizontalPadding))
                .padding(.vertical, CGFloat(descriptor.verticalPadding))
                .background(
                    RoundedRectangle(cornerRadius: CGFloat(descriptor.cornerRadius), style: .continuous)
                        .fill(headingAccentColor(level: descriptor.level).opacity(descriptor.backgroundOpacity))
                )
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: CGFloat(descriptor.accentWidth / 2), style: .continuous)
                        .fill(headingAccentColor(level: descriptor.level))
                        .frame(width: CGFloat(descriptor.accentWidth))
                        .padding(.vertical, CGFloat(descriptor.accentVerticalInset))
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel(descriptor.accessibilityLabel)
                .accessibilityValue(descriptor.accessibilityValue)
                .accessibilityIdentifier(descriptor.accessibilityIdentifier)
                .accessibilityAddTraits(.isHeader)
        } else if block.type == .unorderedListItem || block.type == .orderedListItem {
            let descriptor = ListBlockChromeDescriptor(block: block, ordinal: listOrdinal)
            let controlFrame = InlineLeadingControlFrameDescriptor()
            HStack(alignment: .top, spacing: CGFloat(controlFrame.textSpacing)) {
                ListMarkerGlyph(descriptor: descriptor, nestingLevel: nestingLevel)
                    .padding(.top, CGFloat(controlFrame.topPadding))

                inlineBodyTextEditor(descriptor: controlFrame)
            }
            .padding(.vertical, CGFloat(EditorBlockChrome.listVerticalPadding))
            .padding(.horizontal, CGFloat(EditorBlockChrome.listHorizontalPadding))
            .background(Color.secondary.opacity(EditorBlockChrome.listBackgroundOpacity))
            .accessibilityElement(children: .contain)
            .accessibilityLabel(descriptor.accessibilityLabel)
            .accessibilityValue(descriptor.accessibilityValue)
            .accessibilityIdentifier(descriptor.accessibilityIdentifier)
        } else if block.type == .taskItem {
            let controlFrame = InlineLeadingControlFrameDescriptor(
                topPadding: EditorBlockChrome.inlineControlTopPadding
            )
            HStack(alignment: .top, spacing: CGFloat(controlFrame.textSpacing)) {
                inlineLeadingControl(taskItemCompletionButton, descriptor: controlFrame)

                inlineBodyTextEditor(descriptor: controlFrame)
            }
            .padding(.vertical, CGFloat(EditorBlockChrome.listVerticalPadding))
            .padding(.horizontal, CGFloat(EditorBlockChrome.listHorizontalPadding))
            .background(Color.secondary.opacity(TextEditableBlockChromePolicy.backgroundOpacity(blockType: block.type)))
            .accessibilityElement(children: .contain)
            .accessibilityLabel(taskBlockAccessibilityLabel)
            .accessibilityValue(block.taskItemIsCompleted ? "已完成" : "未完成")
            .accessibilityIdentifier("editor.task.\(block.id)")
        } else if block.type == .codeBlock {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: block.type.editorMenuSystemImage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)

                    Spacer(minLength: 8)

                    codeBlockWrapButton
                }

                nativeTextBlockEditor
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(SpecialBlockSurfaceChrome.codeBackgroundToken.color)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(EditorDesignTokens.Colors.border.color, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .accessibilityElement(children: .contain)
            .accessibilityLabel(codeBlockAccessibilityLabel)
            .accessibilityValue(block.codeBlockLineWrapping ? "已开启自动换行" : "已关闭自动换行")
            .accessibilityIdentifier("editor.code.\(block.id)")
        } else if block.type == .toggle {
            let controlFrame = InlineLeadingControlFrameDescriptor(
                topPadding: EditorBlockChrome.inlineControlTopPadding
            )
            HStack(alignment: .top, spacing: CGFloat(controlFrame.textSpacing)) {
                inlineLeadingControl(toggleBlockExpansionButton, descriptor: controlFrame)

                inlineBodyTextEditor(descriptor: controlFrame)
            }
            .padding(.vertical, CGFloat(EditorBlockChrome.listVerticalPadding))
            .padding(.horizontal, CGFloat(EditorBlockChrome.listHorizontalPadding))
            .background(Color.secondary.opacity(TextEditableBlockChromePolicy.backgroundOpacity(blockType: block.type)))
            .accessibilityElement(children: .contain)
            .accessibilityLabel(toggleBlockAccessibilityLabel)
            .accessibilityValue(isToggleBlockExpanded ? "已展开" : "已折叠")
            .accessibilityIdentifier("editor.toggle.\(block.id)")
        } else if block.type == .callout {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "text.bubble")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
                    .accessibilityHidden(true)

                nativeTextBlockEditor
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(SpecialBlockSurfaceChrome.calloutBackgroundToken.color)
            .overlay(
                RoundedRectangle(cornerRadius: CGFloat(EditorBlockChrome.specialBlockCornerRadius))
                    .stroke(EditorDesignTokens.Colors.border.color.opacity(0.75), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: CGFloat(EditorBlockChrome.specialBlockCornerRadius)))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Callout block")
            .accessibilityValue(block.textPlain.isEmpty ? "空" : block.textPlain)
            .accessibilityIdentifier("editor.callout.\(block.id)")
        } else if block.type == .quote {
            let descriptor = QuoteBlockChromeDescriptor(block: block)
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "quote.opening")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(EditorDesignTokens.Colors.tertiaryText.color.opacity(0.62))
                    .accessibilityHidden(true)

                nativeTextBlockEditor
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
            .background(SpecialBlockSurfaceChrome.quoteBackgroundToken.color)
            .clipShape(RoundedRectangle(cornerRadius: CGFloat(EditorBlockChrome.specialBlockCornerRadius), style: .continuous))
            .accessibilityElement(children: .contain)
            .accessibilityLabel(descriptor.accessibilityLabel)
            .accessibilityValue(descriptor.accessibilityValue)
            .accessibilityIdentifier(descriptor.accessibilityIdentifier)
        } else {
            HStack(alignment: .top, spacing: 8) {
                textBlockLeadingControls
                nativeTextBlockEditor
            }
        }
    }

    @ViewBuilder
    private var textBlockLeadingControls: some View {
        if block.type == .taskItem {
            taskItemCompletionButton
        }

        if block.type == .toggle {
            toggleBlockExpansionButton
        }

        if block.type == .codeBlock {
            codeBlockWrapButton
        }
    }

    private func inlineLeadingControl<Control: View>(
        _ control: Control,
        descriptor: InlineLeadingControlFrameDescriptor
    ) -> some View {
        control
            .frame(
                width: CGFloat(descriptor.width),
                height: CGFloat(descriptor.height),
                alignment: .leading
            )
            .padding(.top, CGFloat(descriptor.topPadding))
    }

    private func inlineBodyTextEditor(descriptor: InlineLeadingControlFrameDescriptor) -> some View {
        nativeTextBlockEditor
            .offset(y: CGFloat(descriptor.textVerticalOffset))
    }

    private func headingAccentColor(level: Int) -> Color {
        switch level {
        case 1:
            return Color(red: 0.68, green: 0.29, blue: 0.41)
        case 2:
            return EditorDesignTokens.Colors.accent.color
        case 3:
            return EditorDesignTokens.Colors.warningText.color
        default:
            return EditorDesignTokens.Colors.secondaryText.color
        }
    }

    private var taskItemCompletionButton: some View {
        Button {
            onTaskItemCompletionChange(!block.taskItemIsCompleted)
        } label: {
            Image(systemName: block.taskItemIsCompleted ? "checkmark.circle.fill" : "circle")
        }
        .buttonStyle(.plain)
        .font(.system(size: CGFloat(EditorBlockChrome.taskControlIconSize), weight: .regular))
        .foregroundStyle(block.taskItemIsCompleted ? .green : .secondary)
        .contentShape(Rectangle())
        .help(block.taskItemIsCompleted ? "标记未完成" : "标记完成")
        .accessibilityLabel(block.taskItemIsCompleted ? "标记任务未完成" : "标记任务完成")
        .accessibilityValue(block.taskItemIsCompleted ? "已完成" : "未完成")
        .accessibilityIdentifier("editor.block.\(block.id).task-toggle")
    }

    private var toggleBlockExpansionButton: some View {
        Button {
            onToggleBlockExpansion()
        } label: {
            Image(systemName: isToggleBlockExpanded ? "chevron.down" : "chevron.right")
        }
        .buttonStyle(.plain)
        .font(.system(size: 16, weight: .regular))
        .foregroundStyle(.secondary)
        .contentShape(Rectangle())
        .help(isToggleBlockExpanded ? "折叠" : "展开")
        .accessibilityLabel(isToggleBlockExpanded ? "折叠块" : "展开块")
        .accessibilityValue(isToggleBlockExpanded ? "已展开" : "已折叠")
        .accessibilityIdentifier("editor.block.\(block.id).toggle-expansion")
    }

    private var codeBlockWrapButton: some View {
        Button {
            onCodeBlockLineWrappingChange(!block.codeBlockLineWrapping)
        } label: {
            Image(systemName: "text.alignleft")
        }
        .buttonStyle(.borderless)
        .foregroundStyle(block.codeBlockLineWrapping ? .primary : .secondary)
        .help(block.codeBlockLineWrapping ? "关闭自动换行" : "开启自动换行")
        .accessibilityLabel(block.codeBlockLineWrapping ? "关闭代码自动换行" : "开启代码自动换行")
        .accessibilityValue(block.codeBlockLineWrapping ? "已开启自动换行" : "已关闭自动换行")
        .accessibilityIdentifier("editor.block.\(block.id).code-wrap")
    }

    private var codeBlockAccessibilityLabel: String {
        block.codeBlockLineWrapping ? "代码块，已开启自动换行" : "代码块，已关闭自动换行"
    }

    private var toggleBlockAccessibilityLabel: String {
        isToggleBlockExpanded ? "折叠块，已展开" : "折叠块，已折叠"
    }

    private var taskBlockAccessibilityLabel: String {
        block.taskItemIsCompleted ? "任务块，已完成" : "任务块，未完成"
    }

    private var nativeTextBlockEditor: some View {
        NativeTextBlockEditor(
            blockID: block.id,
            text: block.textPlain,
            blockType: block.type,
            contentFont: contentFont,
            session: editorSession,
            lineWrapping: block.type == .codeBlock ? block.codeBlockLineWrapping : true,
            focusRequestID: effectiveFocusRequestID,
            focusSelection: effectiveFocusSelection,
            onFocusRequestHandled: handleFocusRequestHandled,
            onMoveByKeyboard: onMoveByKeyboard,
            onIndentationByKeyboard: handleKeyboardIndentation,
            onMoveFocusByKeyboard: onMoveFocusByKeyboard,
            onExtendBlockSelectionByKeyboard: onExtendBlockSelectionByKeyboard,
            onApplyInlineFormatByKeyboard: onApplyInlineFormatByKeyboard,
            onInsertLinkByKeyboard: onInsertLinkByKeyboard,
            onInsertBlockAfter: onInsertBlockAfter,
            onReplaceTextAtSelection: onReplaceTextAtSelection,
            onPasteTextAtSelection: onPasteTextAtSelection,
            onMergeBlockWithPrevious: onMergeBlockWithPrevious,
            onMergeBlockWithNext: onMergeBlockWithNext,
            onSlashCommandNavigationByKeyboard: handleSlashCommandNavigation,
            onSlashCommandSelectionByKeyboard: selectCurrentSlashCommand,
            onPasteAttachmentURLs: onPasteAttachmentURLs,
            onSelectAllBlocksByKeyboard: onSelectAllBlocksByKeyboard,
            onCancelSelectionByKeyboard: {
                let hadBlockSelection = !editorSession.selectedBlockIDs.isEmpty
                editorSession.clearBlockSelection()
                return hadBlockSelection
            },
            onPromoteBlockToPageByKeyboard: {
                onConvertToPage()
                return true
            },
            onHorizontalSwipe: { translationWidth in
#if os(iOS)
                handleMobileHorizontalSwipe(translation: CGSize(width: translationWidth, height: 0))
                return true
#else
                return false
#endif
            },
            dragPayloadText: dragPayloadText,
            keyboardAccessory: keyboardAccessoryView,
            keyboardAccessoryHeight: keyboardAccessoryHeight,
            keyboardAccessoryReplacesKeyboard: keyboardAccessoryReplacesKeyboard,
            onTextChange: { text in
                onClearDropTarget()
                onTextChange(text)
            }
        )
        .accessibilityIdentifier("editor.text.\(block.id)")
#if os(iOS)
        .highPriorityGesture(mobileHorizontalSwipeGesture)
#endif
    }

    private var keyboardAccessoryView: AnyView? {
#if os(iOS)
        AnyView(mobileKeyboardAccessory)
#else
        nil
#endif
    }

    private var keyboardAccessoryHeight: CGFloat? {
#if os(iOS)
        isMobileFormatPanelPresented
            ? NativeTextEditorLayout.keyboardFormatPanelHeight
            : NativeTextEditorLayout.keyboardToolbarHeight
#else
        nil
#endif
    }

    private var keyboardAccessoryReplacesKeyboard: Bool {
#if os(iOS)
        isMobileFormatPanelPresented
#else
        false
#endif
    }

#if os(iOS)
    @ViewBuilder
    private var mobileKeyboardAccessory: some View {
        if isMobileFormatPanelPresented {
            mobileKeyboardFormatPalette
                .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            MobileKeyboardInputBar(
                isOutlinePresented: isMobileOutlinePresented,
                selectedBlockType: block.type,
                canUndo: canUndoTextEdit,
                onPaste: {
                    pasteMobileKeyboardContents()
                },
                onUndo: {
                    let refocusSelection = mobileInlineFormatSelection
                    onUndoTextEdit()
                    requestMobileRefocusAfterFormatMutation(selection: refocusSelection)
                },
                onDismissKeyboard: {
                    dismissMobileKeyboard()
                },
                onApplyUnorderedList: {
                    applyMobileKeyboardBlockType(.unorderedListItem)
                },
                onApplyOrderedList: {
                    applyMobileKeyboardBlockType(.orderedListItem)
                },
                onShowHeadingPanel: {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
                        mobileFormatPaletteTab = .heading
                        isMobileFormatPanelPresented = true
                    }
                },
                onToggleOutline: {
                    if isMobileOutlinePresented {
                        onCloseOutline()
                    } else {
                        onRevealOutline()
                    }
                },
                onShowMoreFormatPanel: {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
                        mobileFormatPaletteTab = .more
                        isMobileFormatPanelPresented = true
                    }
                }
            )
            .transition(.opacity)
        }
    }

    private var mobileKeyboardFormatPalette: some View {
        MobileFormatPalette(
            selectedBlockType: block.type,
            canIndent: canMoveUp,
            canOutdent: nestingLevel > 0,
            canApplyInlineFormat: mobileInlineFormatSelection != nil,
            onChangeType: { type in
                let refocusSelection = mobileInlineFormatSelection
                if type.isTextEditable && type != .table {
                    requestMobileRefocusAfterFormatMutation(selection: refocusSelection)
                }
                onChangeType(type)
                if type.isTextEditable && type != .table {
                    requestMobileRefocusAfterFormatMutation(selection: refocusSelection)
                }
                collapseMobileFormatPanelToKeyboard()
            },
            onIndent: {
                let refocusSelection = mobileInlineFormatSelection
                if onIndent() {
                    requestMobileRefocusAfterFormatMutation(selection: refocusSelection)
                    collapseMobileFormatPanelToKeyboard()
                }
            },
            onOutdent: {
                let refocusSelection = mobileInlineFormatSelection
                if onOutdent() {
                    requestMobileRefocusAfterFormatMutation(selection: refocusSelection)
                    collapseMobileFormatPanelToKeyboard()
                }
            },
            onApplyInlineFormat: { format in
                guard let selection = mobileInlineFormatSelection else {
                    return
                }
                if onApplyInlineFormatByKeyboard(format, selection) {
                    collapseMobileFormatPanelToKeyboard()
                }
            },
            onInsertLink: {
                guard let selection = mobileInlineFormatSelection else {
                    return
                }
                _ = onInsertLinkByKeyboard(selection)
            },
            onReturnToKeyboard: {
                collapseMobileFormatPanelToKeyboard()
            },
            onDismissKeyboard: {
                dismissMobileKeyboard()
            }
        )
    }

    private var mobileInlineFormatSelection: EditorTextSelection? {
        guard block.type.supportsInlineMarkdownStyling else {
            return nil
        }

        if let selection = editorSession.textSelection,
           selection.blockID == block.id,
           isValidMobileSelection(selection) {
            return selection
        }

        return blockEndSelection
    }

    private func isValidMobileSelection(_ selection: EditorTextSelection) -> Bool {
        let textLength = (block.textPlain as NSString).length
        return selection.location >= 0 &&
            selection.length >= 0 &&
            selection.location <= textLength &&
            selection.length <= textLength - selection.location
    }

    @discardableResult
    private func pasteMobileKeyboardContents() -> Bool {
        let attachmentURLs = IOSPasteboardAttachmentResolver.attachmentURLs(from: .general)
        if !attachmentURLs.isEmpty {
            return onPasteAttachmentURLs(attachmentURLs)
        }

        guard let pasteText = UIPasteboard.general.string,
              !pasteText.isEmpty else {
            return false
        }

        return pasteMobileKeyboardText(pasteText)
    }

    @discardableResult
    private func pasteMobileKeyboardText(_ pasteText: String) -> Bool {
        guard block.type.isTextEditable else {
            return false
        }

        let selection = mobileInlineFormatSelection ?? blockEndSelection
        guard isValidMobileSelection(selection) else {
            return false
        }

        if NativeTextPasteSplitPolicy.shouldRouteToBlockPaste(text: pasteText, blockType: block.type),
           let nextSelection = onPasteTextAtSelection(selection, pasteText) {
            requestMobileRefocusAfterFormatMutation(selection: nextSelection)
            return true
        }

        let range = NSRange(location: selection.location, length: selection.length)
        let updatedText = (block.textPlain as NSString).replacingCharacters(
            in: range,
            with: pasteText
        )
        onTextChange(updatedText)

        let nextSelection = EditorTextSelection(
            blockID: block.id,
            location: selection.location + (pasteText as NSString).length,
            length: 0
        )
        requestMobileRefocusAfterFormatMutation(selection: nextSelection)
        return true
    }

    private func applyMobileKeyboardBlockType(_ type: BlockType) {
        let refocusSelection = mobileInlineFormatSelection
        let nextType: BlockType = block.type == type ? .paragraph : type
        onChangeType(nextType)
        if nextType.isTextEditable && nextType != .table {
            requestMobileRefocusAfterFormatMutation(selection: refocusSelection)
        }
    }

    private func collapseMobileFormatPanelToKeyboard() {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.92)) {
            isMobileFormatPanelPresented = false
        }
    }

    private func dismissMobileKeyboard() {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.92)) {
            isMobileFormatPanelPresented = false
            mobileFormatPaletteTab = .more
        }
        rowFocusRequest = nil
        dismissActiveIOSKeyboard()
        editorSession.endEditing(blockID: block.id)
    }

    private func dismissActiveIOSKeyboard() {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .forEach { window in
                window.endEditing(true)
            }
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    private func requestMobileRefocusAfterFormatMutation(selection: EditorTextSelection?) {
        let focusSelection = selection ?? blockEndSelection
        DispatchQueue.main.async {
            rowFocusRequest = BlockFocusRequest(blockID: block.id, selection: focusSelection)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            rowFocusRequest = BlockFocusRequest(blockID: block.id, selection: focusSelection)
        }
    }

    private func resetMobileFormatPanelForInactiveRow() {
        guard isMobileFormatPanelPresented || mobileFormatPaletteTab != .more else {
            return
        }

        isMobileFormatPanelPresented = false
        mobileFormatPaletteTab = .more
    }
#endif

    private func controlAvailabilityValue(_ isAvailable: Bool) -> String {
        isAvailable ? "可用" : "不可用"
    }

    private func handleKeyboardIndentation(_ direction: BlockKeyboardIndentationDirection) -> Bool {
        switch direction {
        case .indent:
            return onIndent()
        case .outdent:
            return onOutdent()
        }
    }

#if os(iOS)
    private var mobileHorizontalSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 24, coordinateSpace: .local)
            .onEnded { value in
                handleMobileHorizontalSwipe(translation: value.translation)
            }
    }

    private func handleMobileHorizontalSwipe(translation: CGSize) {
        guard let action = MobileBlockSwipeActionResolver.action(
            translation: translation,
            isEditingBlock: editorSession.focusedBlockID == block.id,
            nestingLevel: nestingLevel,
            isOutlinePresented: isMobileOutlinePresented
        ) else {
            return
        }

        switch action {
        case .indent:
            if onIndent() {
                rowFocusRequest = BlockFocusRequest(blockID: block.id)
            }
        case .outdent:
            if onOutdent() {
                rowFocusRequest = BlockFocusRequest(blockID: block.id)
            }
        case .selectBlock:
            onSelectCurrentBlock()
        case .closeOutline:
            onCloseOutline()
        }
    }
#endif

    private static let textBlockMenuTypes: [BlockType] = [
        .paragraph,
        .heading1,
        .heading2,
        .heading3,
        .heading4,
        .heading5,
        .heading6,
        .unorderedListItem,
        .orderedListItem,
        .taskItem,
        .quote,
        .codeBlock,
        .divider,
        .table,
        .callout,
        .toggle
    ]

    private func applySlashCommand(_ command: SlashCommandDescriptor) {
        slashCommandSelectionIndex = 0
        slashCommandSelectionSource = .keyboard
        switch command.type {
        case .pageReference:
            onTextChange("")
            onConvertToPage()
        case .attachmentFile, .attachmentImage, .attachmentVideo:
            onClearTransientSelections(nil)
            onTextChange("")
            onRequestAttachmentImport(command.type)
        case .drawing:
            onClearTransientSelections(nil)
            onTextChange("")
            onCreateDrawingBlock()
        default:
            onClearTransientSelections(nil)
            onTextChange("")
            onChangeType(command.type)
            rowFocusRequest = BlockFocusRequest(blockID: block.id)
        }
    }

    private func handleSlashCommandNavigation(_ direction: BlockKeyboardMoveDirection) -> Bool {
        let commands = SlashCommandResolver.matchingCommands(for: block.textPlain)
        guard editorSession.focusedBlockID == block.id,
              block.textPlain.hasPrefix("/"),
              !commands.isEmpty else {
            return false
        }

        let currentIndex = clampedSlashCommandSelectionIndex(for: commands)
        slashCommandSelectionSource = .keyboard
        switch direction {
        case .up:
            slashCommandSelectionIndex = max(0, currentIndex - 1)
        case .down:
            slashCommandSelectionIndex = min(commands.count - 1, currentIndex + 1)
        }
        return true
    }

    private func selectCurrentSlashCommand() -> Bool {
        let commands = SlashCommandResolver.matchingCommands(for: block.textPlain)
        guard editorSession.focusedBlockID == block.id,
              block.textPlain.hasPrefix("/"),
              !commands.isEmpty else {
            return false
        }

        applySlashCommand(commands[clampedSlashCommandSelectionIndex(for: commands)])
        return true
    }

    private func clampedSlashCommandSelectionIndex(for commands: [SlashCommandDescriptor]) -> Int {
        guard !commands.isEmpty else {
            return 0
        }
        return min(max(slashCommandSelectionIndex, 0), commands.count - 1)
    }

    private func handleRowTap() {
#if os(iOS)
        switch MobileBlockTapActionResolver.action(isSelectionModeActive: isMobileSelectionModeActive) {
        case .focusCursor:
            requestRowFocus()
        case .toggleBlockSelection:
            onToggleBlockSelection()
        }
#else
        requestRowFocus()
#endif
    }

    private func requestRowFocus() {
        onClearDropTarget()
        guard block.type != .table else {
            return
        }
        onClearTransientSelections(nil)
        guard usesNativeTextEditor else {
            if NonEditableBlockSelectionPolicy.selectsBlockOnFocusRequest(blockType: block.type) {
                onSelectCurrentBlock()
            }
            return
        }

        DispatchQueue.main.async {
            let selection = editorSession.textSelection?.blockID == block.id ? editorSession.textSelection : nil
            rowFocusRequest = BlockFocusRequest(blockID: block.id, selection: selection)
            EditorLog.focus.debug(
                "editor_focus_request_scheduled block_id=\(block.id, privacy: .public) source=row_tap"
            )
        }
    }

    private func handleFocusRequestHandled() {
        onClearDropTarget()
        if rowFocusRequest?.blockID == block.id {
            rowFocusRequest = nil
        }
        onFocusRequestHandled()
    }

    private func handleNonEditableFocusRequestIfNeeded(_ requestID: UUID?) {
        guard requestID != nil,
              !usesNativeTextEditor else {
            return
        }

        if NonEditableBlockSelectionPolicy.selectsBlockOnFocusRequest(blockType: block.type) {
            onSelectCurrentBlock()
        }
        handleFocusRequestHandled()
    }
}

private enum BlockDropSlotKind: Equatable {
    case before
    case after
    case body
}

private struct BlockDropSlot: View {
    let destinationBlockID: String
    let slotKind: BlockDropSlotKind
    @Binding var activeDropTarget: BlockDropTarget?
    let destinationLevel: Int
    let moveDroppedBlocks: ([String], String, BlockDropPlacement, Int?) -> Bool

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: CGFloat(EditorBlockChrome.dropSlotHeight))
            .contentShape(Rectangle())
            .overlay(alignment: .center) {
                if let activeTarget {
                    BlockDropIndicator(
                        placement: activeTarget.placement,
                        targetLevel: activeTarget.targetLevel
                    )
                    .padding(.leading, dropIndicatorLeadingPadding(for: activeTarget.targetLevel))
                }
            }
            .onDrop(
                of: [UTType.plainText.identifier, UTType.text.identifier],
                delegate: EditorBlockDropDelegate(
                    destinationBlockID: destinationBlockID,
                    slotKind: slotKind,
                    activeDropTarget: $activeDropTarget,
                    destinationLevel: destinationLevel,
                    moveDroppedBlocks: moveDroppedBlocks
                )
            )
            .accessibilityHidden(true)
    }

    private var activeTarget: BlockDropTarget? {
        guard let activeDropTarget,
              activeDropTarget.blockID == destinationBlockID else {
            return nil
        }

        switch (slotKind, activeDropTarget.placement) {
        case (.before, .before):
            return activeDropTarget
        case (.after, .after):
            return activeDropTarget
        case (.after, .childAfter):
            return activeDropTarget
        case (.after, .outdentAfter):
            return activeDropTarget
        default:
            return nil
        }
    }

    private func dropIndicatorLeadingPadding(for targetLevel: Int?) -> CGFloat {
        CGFloat(max(0, targetLevel ?? destinationLevel)) * BlockDropPlacementResolver.levelIndentWidth
    }
}

private struct CanvasTrailingInsertRegion: View {
    let onInsert: () -> Void

    var body: some View {
        Button(action: onInsert) {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: CGFloat(EditorBlockChrome.trailingInsertHitHeight))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("在末尾继续编辑")
        .accessibilityValue("点击后创建或聚焦末尾文本块")
        .accessibilityIdentifier("editor.canvas-trailing-insert-region")
    }
}

private struct CanvasTailFocusRegion: View {
    let isEmpty: Bool
    let onFocus: () -> Void
    let onMoveDroppedBlocksToEnd: ([String]) -> Bool

    var body: some View {
        Button(action: onFocus) {
            Rectangle()
                .fill(Color.primary.opacity(0.001))
                .frame(maxWidth: .infinity, minHeight: CGFloat(EditorBlockChrome.canvasTrailingFocusHitHeight))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .dropDestination(for: String.self) { draggedBlockIDs, _ in
            onMoveDroppedBlocksToEnd(draggedBlockIDs)
        }
        .accessibilityLabel("在末尾继续编辑")
        .accessibilityValue("点击后将光标移动到最后一个文本块末尾")
        .accessibilityIdentifier(isEmpty ? "editor.empty-canvas-edit-region" : "editor.canvas-edit-region")
    }
}

private struct EditorBlockDropDelegate: DropDelegate {
    let destinationBlockID: String
    let slotKind: BlockDropSlotKind
    @Binding var activeDropTarget: BlockDropTarget?
    let destinationLevel: Int
    let moveDroppedBlocks: ([String], String, BlockDropPlacement, Int?) -> Bool

    func validateDrop(info: DropInfo) -> Bool {
        !info.itemProviders(for: [UTType.plainText.identifier, UTType.text.identifier]).isEmpty
    }

    func dropEntered(info: DropInfo) {
        updateTarget(for: info)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        updateTarget(for: info)
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        clearTargetIfNeeded()
    }

    func performDrop(info: DropInfo) -> Bool {
        let resolution = updateTarget(for: info)
        guard let provider = info.itemProviders(for: [UTType.plainText.identifier, UTType.text.identifier]).first,
              let typeIdentifier = provider.registeredTypeIdentifiers.first(where: { identifier in
                  UTType(identifier)?.conforms(to: .text) == true
              }) else {
            clearTargetIfNeeded()
            return false
        }

        activeDropTarget = nil
        provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
            let blockIDs = Self.blockIDs(from: item)
            DispatchQueue.main.async {
                guard !blockIDs.isEmpty else {
                    return
                }
                _ = moveDroppedBlocks(
                    blockIDs,
                    destinationBlockID,
                    resolution.placement,
                    resolution.targetLevel
                )
            }
        }
        return true
    }

    @discardableResult
    private func updateTarget(for info: DropInfo) -> BlockDropPlacementResolution {
        let resolution = placementResolution(for: info)
        let target = BlockDropTarget(
            blockID: destinationBlockID,
            placement: resolution.placement,
            targetLevel: resolution.targetLevel
        )
        if activeDropTarget != target {
            activeDropTarget = target
        }
        return resolution
    }

    private func placementResolution(for info: DropInfo) -> BlockDropPlacementResolution {
        switch slotKind {
        case .before:
            return BlockDropPlacementResolution(placement: .before, targetLevel: nil)
        case .after:
            return BlockDropPlacementResolver.afterResolution(
                locationX: info.location.x,
                destinationLevel: destinationLevel
            )
        case .body:
            return MobileBlockDropTargetPolicy.resolution(
                location: info.location,
                destinationLevel: destinationLevel
            )
        }
    }

    private func clearTargetIfNeeded() {
        guard activeDropTarget?.blockID == destinationBlockID else {
            return
        }
        activeDropTarget = nil
    }

    nonisolated private static func blockIDs(from item: NSSecureCoding?) -> [String] {
        let text: String?
        if let string = item as? String {
            text = string
        } else if let string = item as? NSString {
            text = string as String
        } else if let data = item as? Data {
            text = String(data: data, encoding: .utf8)
        } else {
            text = nil
        }

        return text?
            .split(whereSeparator: { $0 == "\n" || $0 == "," })
            .map(String.init)
            .filter { !$0.isEmpty } ?? []
    }
}

private struct BlockDropIndicator: View {
    let placement: BlockDropPlacement
    let targetLevel: Int?

    private var descriptor: BlockDropIndicatorDescriptor {
        BlockDropIndicatorDescriptor(placement: placement, targetLevel: targetLevel)
    }

    var body: some View {
        HStack(spacing: 7) {
            BlockDropLevelRail(
                dotCount: descriptor.levelDotCount,
                color: indicatorColor
            )

            Capsule()
                .fill(indicatorColor)
                .frame(maxWidth: 340)
                .frame(height: CGFloat(BlockDropIndicatorChrome.lineHeight))

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier("editor.block-drop-indicator")
    }

    private var indicatorColor: Color {
        (placement == .childAfter || placement == .outdentAfter)
            ? EditorDesignTokens.Colors.accent.color.opacity(BlockDropIndicatorChrome.emphasizedOpacity)
            : EditorDesignTokens.Colors.accent.color.opacity(BlockDropIndicatorChrome.standardOpacity)
    }

    private var accessibilityLabel: String {
        switch placement {
        case .before:
            return "拖拽到块上方"
        case .after:
            return "拖拽到块下方"
        case .childAfter:
            return "拖拽为下级块"
        case .outdentAfter:
            return "拖拽为上级块"
        }
    }
}

struct BlockDropIndicatorDescriptor: Equatable, Sendable {
    let placement: BlockDropPlacement
    let targetLevel: Int?

    var levelDotCount: Int {
        guard placement != .before else {
            return 1
        }
        return max(1, (targetLevel ?? 0) + 1)
    }

    var visibleText: String? {
        nil
    }
}

private struct BlockDropLevelRail: View {
    let dotCount: Int
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<min(max(dotCount, 1), 7), id: \.self) { index in
                Circle()
                    .fill(color.opacity(index == dotCount - 1 ? 1 : 0.42))
                    .frame(width: 4, height: 4)
            }
        }
        .frame(width: 48, alignment: .leading)
    }
}

private struct DragPreviewBlock: View {
    let block: BlockSnapshot
    private let layout = DragPreviewLayoutDescriptor()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            invisibleSpacer
                .frame(height: CGFloat(layout.pointerVerticalOffset))

            HStack(spacing: 0) {
                invisibleSpacer
                    .frame(width: CGFloat(layout.pointerHorizontalOffset))

                HStack(spacing: 9) {
                    Image(systemName: block.type.editorMenuSystemImage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 18)
                    Text(previewText)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .frame(width: 260, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .shadow(
                    color: EditorDesignTokens.Shadows.popoverSmall.swiftUIColor,
                    radius: CGFloat(EditorDesignTokens.Shadows.popoverSmall.radius),
                    x: CGFloat(EditorDesignTokens.Shadows.popoverSmall.x),
                    y: CGFloat(EditorDesignTokens.Shadows.popoverSmall.y)
                )

                invisibleSpacer
                    .frame(width: CGFloat(layout.trailingInset))
            }

            invisibleSpacer
                .frame(height: CGFloat(layout.bottomInset))
        }
        .frame(
            width: CGFloat(layout.previewWidth),
            height: CGFloat(layout.previewHeight),
            alignment: .topLeading
        )
    }

    private var invisibleSpacer: some View {
        EditorDesignTokens.Colors.editorBackground.color.opacity(layout.invisibleSpacerOpacity)
    }

    private var previewText: String {
        let trimmed = block.textPlain.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? block.type.editorMenuTitle : trimmed
    }
}

private struct SlashCommandMenu: View {
    let commands: [SlashCommandDescriptor]
    let selectedIndex: Int
    let scrollsSelectionIntoView: Bool
    let onHover: (Int) -> Void
    let onSelect: (SlashCommandDescriptor) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(commands.enumerated()), id: \.element.id) { index, command in
                        Button {
                            onSelect(command)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: command.type.editorMenuSystemImage)
                                    .font(.callout)
                                    .foregroundStyle(index == selectedIndex ? EditorDesignTokens.Colors.accent.color : .secondary)
                                    .frame(width: 22)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(command.title)
                                        .font(.callout.weight(.medium))
                                        .foregroundStyle(.primary)
                                    Text(command.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer(minLength: 12)
                            }
                            .frame(minHeight: CGFloat(EditorDesignTokens.Layout.slashMenuRowHeight), alignment: .leading)
                            .padding(.horizontal, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(index == selectedIndex ? EditorDesignTokens.Colors.accent.color.opacity(0.08) : Color.clear)
                            )
                            .contentShape(Rectangle())
                        }
                        .id(command.id)
                        .buttonStyle(.plain)
                        .onHover { hovering in
                            if hovering {
                                onHover(index)
                            }
                        }
                        .accessibilityIdentifier("editor.slash-command.\(command.id)")
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 8)
            }
            .frame(maxHeight: 342)
            .onChange(of: selectedIndex) { _, index in
                guard scrollsSelectionIntoView else {
                    return
                }
                guard commands.indices.contains(index) else {
                    return
                }
                withAnimation(.easeOut(duration: 0.06)) {
                    proxy.scrollTo(commands[index].id, anchor: .center)
                }
            }
        }
        .frame(width: CGFloat(EditorDesignTokens.Layout.slashMenuWidth), alignment: .leading)
        .background(EditorDesignTokens.Colors.editorBackground.color)
        .overlay(
            RoundedRectangle(cornerRadius: CGFloat(EditorDesignTokens.Layout.slashMenuCornerRadius), style: .continuous)
                .stroke(EditorDesignTokens.Colors.border.color, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: CGFloat(EditorDesignTokens.Layout.slashMenuCornerRadius), style: .continuous))
        .shadow(
            color: EditorDesignTokens.Shadows.popoverLarge.swiftUIColor,
            radius: CGFloat(EditorDesignTokens.Shadows.popoverLarge.radius),
            x: CGFloat(EditorDesignTokens.Shadows.popoverLarge.x),
            y: CGFloat(EditorDesignTokens.Shadows.popoverLarge.y)
        )
        .shadow(
            color: EditorDesignTokens.Shadows.popoverSmall.swiftUIColor,
            radius: CGFloat(EditorDesignTokens.Shadows.popoverSmall.radius),
            x: CGFloat(EditorDesignTokens.Shadows.popoverSmall.x),
            y: CGFloat(EditorDesignTokens.Shadows.popoverSmall.y)
        )
        .accessibilityValue("可滚动，\(commands.count) 项")
        .accessibilityIdentifier("editor.slash-command-menu")
    }
}

private struct StructuredTableBlockEditor: View {
    let blockID: String
    let text: String
    let rows: [[String]]
    let focusedBlockID: String?
    let selectionResetRequest: TransientSelectionResetRequest
    let onClearExternalSelections: () -> Void
    let onRowsChange: ([[String]]) -> Void
    let onMoveFocusByKeyboard: (BlockKeyboardFocusDirection) -> Bool
    @State private var isTableHovered = false
    @State private var selection = TableSelection.empty

    private var table: MarkdownTableDocument {
        MarkdownTableDocument(rows: editableRows)
    }

    var body: some View {
        let rows = editableRows
        let tableDimensions = tableDimensionAccessibilityValue(rows: rows)
        let viewportWidth = tableViewportWidth(rows: rows)
        let contentHeight = tableContentHeight(rows: rows)
        let columnCount = tableColumnCount(rows: rows)

        ZStack(alignment: .topLeading) {
            ScrollView(.horizontal, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    tableGrid(rows: rows, columnCount: columnCount)
                    tableSelectionHitLayer(rows: rows, columnCount: columnCount)
                }
                .fixedSize()
            }
            .frame(
                width: viewportWidth,
                height: contentHeight
            )
            .background(EditorDesignTokens.Colors.editorBackground.color)
            .overlay(
                RoundedRectangle(cornerRadius: CGFloat(TableBlockChrome.cornerRadius), style: .continuous)
                    .stroke(Color.secondary.opacity(TableBlockChrome.outerBorderOpacity), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: CGFloat(TableBlockChrome.cornerRadius), style: .continuous))
        }
        .overlay(alignment: .bottom) {
            tablePrimaryControl(
                systemImage: "plus",
                help: "新增行",
                accessibilityLabel: "新增表格行",
                accessibilityValue: tableDimensions,
                accessibilityIdentifier: "editor.table.\(blockID).add-row",
                action: appendRow
            )
            .offset(y: CGFloat(TableBlockChrome.insertControlEdgeOffset))
        }
        .overlay(alignment: .trailing) {
            tablePrimaryControl(
                systemImage: "plus",
                help: "新增列",
                accessibilityLabel: "新增表格列",
                accessibilityValue: tableDimensions,
                accessibilityIdentifier: "editor.table.\(blockID).add-column",
                action: appendColumn
            )
            .offset(x: CGFloat(TableBlockChrome.insertControlEdgeOffset))
        }
        .padding(.vertical, 4)
        .onHover { hovering in
            isTableHovered = hovering
        }
#if os(macOS)
        .onDeleteCommand {
            deleteSelection()
        }
        .background(
            TableDeleteKeyBridge(isEnabled: !selection.isEmpty) {
                deleteSelection()
            } onCancelSelection: {
                selection = .empty
            } onMoveFocus: { direction in
                onMoveFocusByKeyboard(direction)
            }
            .frame(width: 0, height: 0)
        )
#elseif os(iOS)
        .background(
            IOSTableKeyboardShortcutBridge(isEnabled: !selection.isEmpty) {
                deleteSelection()
            } onCancelSelection: {
                selection = .empty
            } onMoveFocus: { direction in
                onMoveFocusByKeyboard(direction)
            }
            .frame(width: 0, height: 0)
        )
#endif
        .accessibilityElement(children: .contain)
        .accessibilityLabel("表格块，\(tableDimensions)")
        .accessibilityValue(tableDimensions)
        .accessibilityIdentifier("editor.table.\(blockID)")
        .onChange(of: selectionResetRequest) { _, request in
            guard request.excludingBlockID != blockID else {
                return
            }
            selection = TableSelectionReducer.selectionAfterExternalInteraction(selection)
        }
        .onChange(of: focusedBlockID) { _, focusedBlockID in
            if focusedBlockID != blockID {
                selection = .empty
            }
        }
    }

    private var editableRows: [[String]] {
        TableBlockDefaultGridResolver.editableRows(text: text, rows: rows)
    }

    private func tableDimensionAccessibilityValue(rows: [[String]]) -> String {
        let rowCount = rows.count
        let columnCount = rows.map(\.count).max() ?? 0
        return "\(rowCount) 行，\(columnCount) 列"
    }

    private func tableViewportWidth(rows: [[String]]) -> CGFloat {
        let columnCount = tableColumnCount(rows: rows)
        let contentWidth = CGFloat(columnCount) * CGFloat(TableBlockChrome.cellWidth)
        return min(contentWidth, CGFloat(TableBlockChrome.maxViewportWidth))
    }

    private func tableContentHeight(rows: [[String]]) -> CGFloat {
        CGFloat(max(rows.count, 1)) * CGFloat(TableBlockChrome.cellHeight)
    }

    private func tableColumnCount(rows: [[String]]) -> Int {
        max(rows.map(\.count).max() ?? 1, 1)
    }

    private func tableContentWidth(columnCount: Int) -> CGFloat {
        CGFloat(columnCount) * CGFloat(TableBlockChrome.cellWidth)
    }

    private func tableGrid(rows: [[String]], columnCount: Int) -> some View {
        Grid(alignment: .topLeading, horizontalSpacing: 0, verticalSpacing: 0) {
            ForEach(rows.indices, id: \.self) { rowIndex in
                GridRow(alignment: .top) {
                    ForEach(0..<columnCount, id: \.self) { columnIndex in
                        tableCell(
                            row: rowIndex,
                            column: columnIndex,
                            rowCount: rows.count,
                            columnCount: columnCount
                        )
                    }
                }
            }
        }
    }

    private func tableSelectionHitLayer(rows: [[String]], columnCount: Int) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(rows.indices, id: \.self) { rowIndex in
                rowSelector(rowIndex, columnCount: columnCount)
            }

            ForEach(0..<columnCount, id: \.self) { columnIndex in
                columnSelector(columnIndex)
            }
        }
        .frame(
            width: tableContentWidth(columnCount: columnCount),
            height: tableContentHeight(rows: rows),
            alignment: .topLeading
        )
        .zIndex(2)
    }

    private func cellBinding(row rowIndex: Int, column columnIndex: Int) -> Binding<String> {
        Binding {
            let rows = editableRows
            guard rows.indices.contains(rowIndex),
                  rows[rowIndex].indices.contains(columnIndex) else {
                return ""
            }
            return rows[rowIndex][columnIndex]
        } set: { value in
            var updatedTable = table
            updatedTable.updateCell(row: rowIndex, column: columnIndex, text: value)
            onRowsChange(updatedTable.rows)
        }
    }

    private func tableCell(
        row rowIndex: Int,
        column columnIndex: Int,
        rowCount: Int,
        columnCount: Int
    ) -> some View {
        TextField(
            "",
            text: cellBinding(row: rowIndex, column: columnIndex)
        )
        .textFieldStyle(.plain)
        .font(.system(size: 15, weight: rowIndex == 0 ? .semibold : .regular))
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .frame(
            width: CGFloat(TableBlockChrome.cellWidth),
            height: CGFloat(TableBlockChrome.cellHeight),
            alignment: .topLeading
        )
        .background(cellBackgroundColor(row: rowIndex, column: columnIndex))
        .overlay {
            if selection.rows.contains(rowIndex) || selection.columns.contains(columnIndex) {
                RoundedRectangle(cornerRadius: 0)
                    .stroke(MobileActionChrome.accentColor.opacity(0.14), lineWidth: 1)
            }
        }
        .overlay(alignment: .trailing) {
            if columnIndex < columnCount - 1 {
                Rectangle()
                    .fill(Color.secondary.opacity(TableBlockChrome.gridLineOpacity))
                    .frame(width: 1)
            }
        }
        .overlay(alignment: .bottom) {
            if rowIndex < rowCount - 1 {
                Rectangle()
                    .fill(Color.secondary.opacity(TableBlockChrome.gridLineOpacity))
                    .frame(height: 1)
            }
        }
        .onTapGesture {
            onClearExternalSelections()
            selection = .empty
        }
        .accessibilityIdentifier("editor.table.\(blockID).cell.\(rowIndex).\(columnIndex)")
    }

    private func cellBackgroundColor(row rowIndex: Int, column columnIndex: Int) -> Color {
        if selection.rows.contains(rowIndex) || selection.columns.contains(columnIndex) {
            return MobileActionChrome.accentColor.opacity(0.045)
        }
        return rowIndex == 0
            ? TableBlockChrome.headerBackgroundToken.color
            : EditorDesignTokens.Colors.editorBackground.color
    }

    private func rowSelector(_ rowIndex: Int, columnCount: Int) -> some View {
        Button {
            onClearExternalSelections()
            selection = TableSelectionReducer.selectionAfterSelectingRow(
                rowIndex,
                current: selection,
                extend: isShiftPressed
            )
        } label: {
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(MobileActionChrome.accentColor.opacity(TableBlockChrome.selectorHitOpacity))
                    .frame(
                        width: CGFloat(TableBlockChrome.selectorWidth),
                        height: CGFloat(TableBlockChrome.cellHeight)
                    )

                if selection.rows.contains(rowIndex) {
                    Capsule()
                        .fill(MobileActionChrome.accentColor.opacity(TableBlockChrome.selectorSelectedIndicatorOpacity))
                        .frame(
                            width: CGFloat(TableBlockChrome.selectorSelectedIndicatorThickness),
                            height: CGFloat(TableBlockChrome.cellHeight - TableBlockChrome.selectorSelectedIndicatorInset * 2)
                        )
                        .padding(.vertical, CGFloat(TableBlockChrome.selectorSelectedIndicatorInset))
                }
            }
        }
        .buttonStyle(.borderless)
        .contentShape(Rectangle())
        .offset(
            x: 0,
            y: CGFloat(rowIndex) * CGFloat(TableBlockChrome.cellHeight)
        )
        .help("选择第 \(rowIndex + 1) 行")
        .accessibilityLabel("选择第 \(rowIndex + 1) 行")
        .accessibilityValue(selection.rows.contains(rowIndex) ? "已选择" : "未选择")
        .accessibilityIdentifier("editor.table.\(blockID).row-selector.\(rowIndex)")
    }

    private func columnSelector(_ columnIndex: Int) -> some View {
        Button {
            onClearExternalSelections()
            selection = TableSelectionReducer.selectionAfterSelectingColumn(
                columnIndex,
                current: selection,
                extend: isShiftPressed
            )
        } label: {
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(MobileActionChrome.accentColor.opacity(TableBlockChrome.selectorHitOpacity))
                    .frame(
                        width: CGFloat(TableBlockChrome.cellWidth),
                        height: CGFloat(TableBlockChrome.selectorHeight)
                    )

                if selection.columns.contains(columnIndex) {
                    Capsule()
                        .fill(MobileActionChrome.accentColor.opacity(TableBlockChrome.selectorSelectedIndicatorOpacity))
                        .frame(
                            width: CGFloat(TableBlockChrome.cellWidth - TableBlockChrome.selectorSelectedIndicatorInset * 2),
                            height: CGFloat(TableBlockChrome.selectorSelectedIndicatorThickness)
                        )
                        .padding(.horizontal, CGFloat(TableBlockChrome.selectorSelectedIndicatorInset))
                }
            }
        }
        .buttonStyle(.borderless)
        .contentShape(Rectangle())
        .offset(
            x: CGFloat(columnIndex) * CGFloat(TableBlockChrome.cellWidth),
            y: 0
        )
        .help("选择第 \(columnIndex + 1) 列")
        .accessibilityLabel("选择第 \(columnIndex + 1) 列")
        .accessibilityValue(selection.columns.contains(columnIndex) ? "已选择" : "未选择")
        .accessibilityIdentifier("editor.table.\(blockID).column-selector.\(columnIndex)")
    }

    private func tablePrimaryControl(
        systemImage: String,
        help: String,
        accessibilityLabel: String,
        accessibilityValue: String,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        TableInsertControl(
            systemImage: systemImage,
            help: help,
            accessibilityLabel: accessibilityLabel,
            accessibilityValue: accessibilityValue,
            accessibilityIdentifier: accessibilityIdentifier,
            action: action
        )
    }

    private func appendRow() {
        var updatedTable = normalizedTable()
        updatedTable.appendRow()
        onRowsChange(updatedTable.rows)
    }

    private func appendColumn() {
        var updatedTable = normalizedTable()
        updatedTable.appendColumn()
        onRowsChange(updatedTable.rows)
    }

    private func removeLastRow() {
        var updatedTable = normalizedTable()
        updatedTable.removeLastRow()
        onRowsChange(updatedTable.rows)
    }

    private func removeLastColumn() {
        var updatedTable = normalizedTable()
        updatedTable.removeLastColumn()
        onRowsChange(updatedTable.rows)
    }

    private func deleteSelection() {
        guard !selection.isEmpty else {
            return
        }
        let updatedRows = TableSelectionReducer.rowsAfterDeletingSelection(selection, from: editableRows)
        selection = .empty
        onRowsChange(updatedRows)
    }

    private var isShiftPressed: Bool {
#if os(macOS)
        NSEvent.modifierFlags.contains(.shift)
#else
        false
#endif
    }

    private func normalizedTable() -> MarkdownTableDocument {
        table
    }
}

private struct TableInsertControl: View {
    let systemImage: String
    let help: String
    let accessibilityLabel: String
    let accessibilityValue: String
    let accessibilityIdentifier: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(insertControlColor)
                    .frame(
                        width: isHovered
                            ? CGFloat(TableBlockChrome.insertControlExpandedDiameter)
                            : CGFloat(TableBlockChrome.insertControlVisibleDiameter),
                        height: isHovered
                            ? CGFloat(TableBlockChrome.insertControlExpandedDiameter)
                            : CGFloat(TableBlockChrome.insertControlVisibleDiameter)
                    )

                if isHovered {
                    Image(systemName: systemImage)
                        .font(.system(size: CGFloat(TableBlockChrome.insertControlIconFontSize), weight: .bold))
                        .foregroundStyle(Color.white)
                }
            }
            .frame(
                width: CGFloat(TableBlockChrome.primaryControlDiameter),
                height: CGFloat(TableBlockChrome.primaryControlDiameter)
            )
            .background(EditorDesignTokens.Colors.editorBackground.color.opacity(0.01))
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(help)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityIdentifier(accessibilityIdentifier)
#if os(macOS)
        .onHover { hovering in
            isHovered = hovering
        }
#endif
    }

    private var insertControlColor: Color {
        if isHovered {
            return MobileActionChrome.accentColor.opacity(TableBlockChrome.insertControlHoverOpacity)
        }
        return Color.secondary.opacity(TableBlockChrome.insertControlIdleOpacity)
    }
}

#if os(iOS)
private struct IOSTableKeyboardShortcutBridge: UIViewRepresentable {
    let isEnabled: Bool
    let onDelete: () -> Void
    let onCancelSelection: () -> Void
    let onMoveFocus: (BlockKeyboardFocusDirection) -> Bool

    func makeUIView(context: Context) -> TableKeyCaptureView {
        let view = TableKeyCaptureView(frame: .zero)
        view.isEnabled = isEnabled
        view.onDelete = onDelete
        view.onCancelSelection = onCancelSelection
        view.onMoveFocus = onMoveFocus
        return view
    }

    func updateUIView(_ uiView: TableKeyCaptureView, context: Context) {
        uiView.isEnabled = isEnabled
        uiView.onDelete = onDelete
        uiView.onCancelSelection = onCancelSelection
        uiView.onMoveFocus = onMoveFocus
        uiView.updateFirstResponderIfNeeded()
    }

    final class TableKeyCaptureView: UIView {
        var isEnabled = false
        var onDelete: () -> Void = {}
        var onCancelSelection: () -> Void = {}
        var onMoveFocus: (BlockKeyboardFocusDirection) -> Bool = { _ in false }
        private var isCapturingKeyboard = false

        override var canBecomeFirstResponder: Bool {
            isEnabled
        }

        override var keyCommands: [UIKeyCommand]? {
            guard isEnabled else {
                return []
            }

            return [
                UIKeyCommand(
                    input: UIKeyCommand.inputUpArrow,
                    modifierFlags: [],
                    action: #selector(moveFocusUp)
                ),
                UIKeyCommand(
                    input: UIKeyCommand.inputDownArrow,
                    modifierFlags: [],
                    action: #selector(moveFocusDown)
                ),
                UIKeyCommand(
                    input: IOSTableBlockKeyboardActionResolver.deleteBackwardInput,
                    modifierFlags: [],
                    action: #selector(deleteSelectionCommand)
                ),
                UIKeyCommand(
                    input: IOSTableBlockKeyboardActionResolver.deleteForwardInput,
                    modifierFlags: [],
                    action: #selector(deleteSelectionCommand)
                ),
                UIKeyCommand(
                    input: IOSTableBlockKeyboardActionResolver.escapeInput,
                    modifierFlags: [],
                    action: #selector(cancelSelectionCommand)
                )
            ]
        }

        func updateFirstResponderIfNeeded() {
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                if self.isEnabled {
                    self.becomeFirstResponder()
                    self.isCapturingKeyboard = self.isFirstResponder
                } else if self.isCapturingKeyboard {
                    self.resignFirstResponder()
                    self.isCapturingKeyboard = false
                }
            }
        }

        @objc private func moveFocusUp(_ sender: Any?) {
            performShortcut(input: IOSEditorKeyboardShortcutActionResolver.upArrowInput)
        }

        @objc private func moveFocusDown(_ sender: Any?) {
            performShortcut(input: IOSEditorKeyboardShortcutActionResolver.downArrowInput)
        }

        @objc private func deleteSelectionCommand(_ sender: Any?) {
            performShortcut(input: IOSTableBlockKeyboardActionResolver.deleteBackwardInput)
        }

        @objc private func cancelSelectionCommand(_ sender: Any?) {
            performShortcut(input: IOSTableBlockKeyboardActionResolver.escapeInput)
        }

        private func performShortcut(input: String?) {
            switch IOSTableBlockKeyboardActionResolver.action(
                input: input,
                modifiers: [],
                hasSelection: isEnabled
            ) {
            case .deleteSelection:
                onDelete()
            case .cancelSelection:
                onCancelSelection()
            case .moveFocus(let direction):
                _ = onMoveFocus(direction)
            case nil:
                break
            }
        }
    }
}
#endif

#if os(macOS)
private struct NonEditableBlockKeyboardFocusBridge: NSViewRepresentable {
    let isEnabled: Bool
    let onMoveFocus: (BlockKeyboardFocusDirection) -> Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(onMoveFocus: onMoveFocus)
    }

    func makeNSView(context: Context) -> NSView {
        context.coordinator.install()
        return NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.isEnabled = isEnabled
        context.coordinator.onMoveFocus = onMoveFocus
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    @MainActor
    final class Coordinator {
        var isEnabled = false
        var onMoveFocus: (BlockKeyboardFocusDirection) -> Bool
        private var monitor: Any?

        init(onMoveFocus: @escaping (BlockKeyboardFocusDirection) -> Bool) {
            self.onMoveFocus = onMoveFocus
        }

        func install() {
            guard monitor == nil else {
                return
            }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else {
                    return event
                }
                guard isEnabled,
                      let direction = NonEditableBlockKeyboardFocusResolver.focusDirection(
                        keyCode: event.keyCode,
                        modifiers: event.blockKeyboardShortcutModifiers
                      ) else {
                    return event
                }

                return onMoveFocus(direction) ? nil : event
            }
        }

        func uninstall() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
        }
    }
}

private struct TableDeleteKeyBridge: NSViewRepresentable {
    let isEnabled: Bool
    let onDelete: () -> Void
    let onCancelSelection: () -> Void
    let onMoveFocus: (BlockKeyboardFocusDirection) -> Bool

    func makeNSView(context: Context) -> TableDeleteKeyCaptureView {
        let view = TableDeleteKeyCaptureView(frame: .zero)
        view.isEnabled = isEnabled
        view.onDelete = onDelete
        view.onCancelSelection = onCancelSelection
        view.onMoveFocus = onMoveFocus
        return view
    }

    func updateNSView(_ nsView: TableDeleteKeyCaptureView, context: Context) {
        nsView.isEnabled = isEnabled
        nsView.onDelete = onDelete
        nsView.onCancelSelection = onCancelSelection
        nsView.onMoveFocus = onMoveFocus

        guard isEnabled else {
            DispatchQueue.main.async {
                if nsView.window?.firstResponder === nsView {
                    nsView.window?.makeFirstResponder(nil)
                }
            }
            return
        }

        DispatchQueue.main.async {
            guard nsView.window?.firstResponder !== nsView else {
                return
            }
            nsView.window?.makeFirstResponder(nsView)
        }
    }

    final class TableDeleteKeyCaptureView: NSView {
        var isEnabled = false
        var onDelete: () -> Void
        var onCancelSelection: () -> Void
        var onMoveFocus: (BlockKeyboardFocusDirection) -> Bool

        override init(frame frameRect: NSRect) {
            self.onDelete = {}
            self.onCancelSelection = {}
            self.onMoveFocus = { _ in false }
            super.init(frame: frameRect)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override var acceptsFirstResponder: Bool {
            true
        }

        override func keyDown(with event: NSEvent) {
            guard let action = TableBlockKeyboardActionResolver.action(
                keyCode: event.keyCode,
                modifiers: event.blockKeyboardShortcutModifiers,
                hasSelection: isEnabled
            ) else {
                if isEnabled,
                   event.blockKeyboardShortcutModifiers.isEmpty,
                   !(event.charactersIgnoringModifiers ?? "").isEmpty {
                    onCancelSelection()
                }
                nextResponder?.keyDown(with: event)
                return
            }

            switch action {
            case .deleteSelection:
                onDelete()
            case .cancelSelection:
                onCancelSelection()
            case .moveFocus(let direction):
                if !onMoveFocus(direction) {
                    nextResponder?.keyDown(with: event)
                }
            }
        }

        override func deleteBackward(_ sender: Any?) {
            if isEnabled {
                onDelete()
            } else {
                nextResponder?.tryToPerform(#selector(deleteBackward(_:)), with: sender)
            }
        }

        override func deleteForward(_ sender: Any?) {
            if isEnabled {
                onDelete()
            } else {
                nextResponder?.tryToPerform(#selector(deleteForward(_:)), with: sender)
            }
        }
    }
}

private struct DropTargetCleanupEventBridge: NSViewRepresentable {
    let isEnabled: Bool
    let onClear: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onClear: onClear)
    }

    func makeNSView(context: Context) -> NSView {
        context.coordinator.install()
        return NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.isEnabled = isEnabled
        context.coordinator.onClear = onClear
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    @MainActor
    final class Coordinator {
        var isEnabled = false
        var onClear: () -> Void
        private var eventMonitor: Any?
        private var globalMouseUpMonitor: Any?
        private var resignObserver: NSObjectProtocol?

        init(onClear: @escaping () -> Void) {
            self.onClear = onClear
        }

        func install() {
            if eventMonitor == nil {
                eventMonitor = NSEvent.addLocalMonitorForEvents(
                    matching: [.leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .keyDown]
                ) { [weak self] event in
                    self?.clearIfNeeded()
                    return event
                }
            }
            if globalMouseUpMonitor == nil {
                globalMouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
                    Task { @MainActor in
                        self?.clearIfNeeded()
                    }
                }
            }
            if resignObserver == nil {
                resignObserver = NotificationCenter.default.addObserver(
                    forName: NSApplication.didResignActiveNotification,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    Task { @MainActor in
                        self?.clearIfNeeded()
                    }
                }
            }
        }

        func uninstall() {
            if let eventMonitor {
                NSEvent.removeMonitor(eventMonitor)
            }
            if let globalMouseUpMonitor {
                NSEvent.removeMonitor(globalMouseUpMonitor)
            }
            if let resignObserver {
                NotificationCenter.default.removeObserver(resignObserver)
            }
            eventMonitor = nil
            globalMouseUpMonitor = nil
            resignObserver = nil
        }

        private func clearIfNeeded() {
            guard isEnabled else {
                return
            }
            onClear()
        }
    }
}
#endif

private struct PageReferenceBlockRow: View {
    let block: BlockSnapshot
    let previewText: String?
    let onOpenPageReference: (String) -> Void

    private var titleText: String {
        block.textPlain.isEmpty ? "未命名" : block.textPlain
    }

    private var normalizedPreviewText: String? {
        let trimmed = previewText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    var body: some View {
        Button {
            if let targetPageID = block.pageReferenceTargetPageID {
                onOpenPageReference(targetPageID)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(titleText)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let normalizedPreviewText {
                        Text(normalizedPreviewText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(
                    cornerRadius: CGFloat(EditorDesignTokens.Layout.pageLinkCornerRadius),
                    style: .continuous
                )
                .fill(EditorDesignTokens.Colors.appBackground.color.opacity(0.52))
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: CGFloat(EditorDesignTokens.Layout.pageLinkCornerRadius),
                    style: .continuous
                )
                .stroke(EditorDesignTokens.Colors.border.color.opacity(0.82), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(block.pageReferenceTargetPageID == nil)
        .accessibilityLabel("页面引用：\(titleText)")
        .accessibilityValue(block.pageReferenceTargetPageID == nil ? "不可用" : "打开页面")
        .accessibilityIdentifier("editor.page-reference.\(block.id)")
    }
}

private struct BlockReferenceBlockRow: View {
    let block: BlockSnapshot
    let onOpenBlockReference: (String, String) -> Void

    private var titleText: String {
        block.textPlain.isEmpty ? "引用块" : block.textPlain
    }

    var body: some View {
        Button {
            if let targetPageID = block.pageReferenceTargetPageID,
               let targetBlockID = block.blockReferenceTargetBlockID {
                onOpenBlockReference(targetPageID, targetBlockID)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "text.quote")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text("块")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(titleText)
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Image(systemName: "arrow.down.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 8)
            .background(EditorDesignTokens.Colors.controlBackgroundSubtle.color)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(EditorDesignTokens.Colors.border.color.opacity(0.62), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .disabled(block.pageReferenceTargetPageID == nil || block.blockReferenceTargetBlockID == nil)
        .accessibilityLabel("块引用：\(titleText)")
        .accessibilityValue(
            block.pageReferenceTargetPageID == nil || block.blockReferenceTargetBlockID == nil
                ? "不可用"
                : "打开引用块"
        )
        .accessibilityIdentifier("editor.block-reference.\(block.id)")
    }
}

private struct AttachmentPreviewImage {
    let image: Image
    let size: CGSize
    let sourcePath: String

    func height(forWidth width: CGFloat) -> CGFloat {
        guard size.width > 0 else {
            return width
        }
        return width * max(size.height, 1) / size.width
    }
}

private struct AttachmentImagePreviewPayload: Identifiable {
    let id: String
    let blockID: String
    let title: String
    let image: AttachmentPreviewImage
}

private struct AttachmentImagePreviewOverlay: View {
    let payload: AttachmentImagePreviewPayload
    let onDismiss: () -> Void

    @State private var committedScale: CGFloat = AttachmentImagePreviewZoomPolicy.minimumScale
    @State private var committedOffset: CGSize = .zero
    @GestureState private var gestureScale: CGFloat = AttachmentImagePreviewZoomPolicy.minimumScale
    @GestureState private var gestureOffset: CGSize = .zero

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black
                .ignoresSafeArea()

            payload.image.image
                .resizable()
                .scaledToFit()
                .padding(18)
                .scaleEffect(currentScale)
                .offset(currentOffset)
                .contentShape(Rectangle())
                .simultaneousGesture(zoomGesture)
                .simultaneousGesture(panGesture)
                .onTapGesture(count: 2) {
                    toggleZoom()
                }
                .accessibilityLabel("图片预览：\(payload.title)")
                .accessibilityValue("双指缩放，拖动查看细节")
                .accessibilityIdentifier("editor.attachment.\(payload.blockID).image-preview")

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.94), .black.opacity(0.35))
                    .padding(18)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("关闭图片预览")
            .accessibilityIdentifier("editor.attachment.\(payload.blockID).image-preview-close")
        }
    }

    private var currentScale: CGFloat {
        AttachmentImagePreviewZoomPolicy.clampedScale(committedScale * gestureScale)
    }

    private var currentOffset: CGSize {
        let proposed = CGSize(
            width: committedOffset.width + gestureOffset.width,
            height: committedOffset.height + gestureOffset.height
        )
        return AttachmentImagePreviewZoomPolicy.persistedOffset(
            currentOffset: proposed,
            scale: currentScale
        )
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .updating($gestureScale) { value, state, _ in
                state = value
            }
            .onEnded { value in
                committedScale = AttachmentImagePreviewZoomPolicy.clampedScale(committedScale * value)
                committedOffset = AttachmentImagePreviewZoomPolicy.persistedOffset(
                    currentOffset: committedOffset,
                    scale: committedScale
                )
            }
    }

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .updating($gestureOffset) { value, state, _ in
                guard currentScale > AttachmentImagePreviewZoomPolicy.minimumScale else {
                    state = .zero
                    return
                }
                state = value.translation
            }
            .onEnded { value in
                let proposed = CGSize(
                    width: committedOffset.width + value.translation.width,
                    height: committedOffset.height + value.translation.height
                )
                committedOffset = AttachmentImagePreviewZoomPolicy.persistedOffset(
                    currentOffset: proposed,
                    scale: committedScale
                )
            }
    }

    private func toggleZoom() {
        withAnimation(.easeInOut(duration: 0.16)) {
            if committedScale > AttachmentImagePreviewZoomPolicy.minimumScale {
                committedScale = AttachmentImagePreviewZoomPolicy.minimumScale
                committedOffset = .zero
            } else {
                committedScale = 2
                committedOffset = .zero
            }
        }
    }
}

private extension BlockType {
    var editorMenuTitle: String {
        switch self {
        case .paragraph:
            return "正文"
        case .heading1:
            return "一级标题"
        case .heading2:
            return "二级标题"
        case .heading3:
            return "三级标题"
        case .heading4:
            return "四级标题"
        case .heading5:
            return "五级标题"
        case .heading6:
            return "六级标题"
        case .unorderedListItem:
            return "无序列表"
        case .orderedListItem:
            return "有序列表"
        case .taskItem:
            return "任务"
        case .quote:
            return "引用"
        case .codeBlock:
            return "代码"
        case .callout:
            return "提示"
        case .toggle:
            return "折叠"
        case .table:
            return "表格"
        case .divider:
            return "分割线"
        case .pageReference:
            return "页面引用"
        case .blockReference:
            return "块引用"
        case .attachmentImage:
            return "图片"
        case .attachmentVideo:
            return "视频"
        case .attachmentFile:
            return "文件"
        case .drawing:
            return "画板"
        }
    }

    var editorMenuSystemImage: String {
        switch self {
        case .paragraph:
            return "text.alignleft"
        case .heading1:
            return "textformat.size"
        case .heading2:
            return "textformat.size"
        case .heading3:
            return "textformat.size"
        case .heading4:
            return "textformat.size"
        case .heading5:
            return "textformat.size"
        case .heading6:
            return "textformat.size"
        case .unorderedListItem:
            return "list.bullet"
        case .orderedListItem:
            return "list.number"
        case .taskItem:
            return "checklist"
        case .quote:
            return "quote.opening"
        case .codeBlock:
            return "chevron.left.forwardslash.chevron.right"
        case .callout:
            return "exclamationmark.bubble"
        case .toggle:
            return "chevron.right.square"
        case .table:
            return "tablecells"
        case .divider:
            return "minus"
        case .pageReference:
            return "doc.text"
        case .blockReference:
            return "text.quote"
        case .attachmentImage:
            return "photo"
        case .attachmentVideo:
            return "film"
        case .attachmentFile:
            return "doc"
        case .drawing:
            return "scribble"
        }
    }
}

private struct DrawingBlockRow: View {
    let block: BlockSnapshot
    let attachment: AttachmentSnapshot?
    let onDataChange: (Data) -> Void

    @State private var document = EditorDrawingDocument.empty
    @State private var loadedAttachmentID: String?
    @State private var loadedAttachmentPath: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            EditorDrawingCanvas(document: $document) { nextDocument in
                onDataChange(nextDocument.dataRepresentation())
            }
            .frame(minHeight: 220)
            .background(SpecialBlockSurfaceChrome.drawingCanvasBackgroundToken.color)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .accessibilityLabel("画板")
            .accessibilityValue(drawingTitle)
            .accessibilityIdentifier("editor.drawing.\(block.id).canvas")

            HStack(spacing: 8) {
                Label(drawingTitle, systemImage: "scribble")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Button {
                    document = .empty
                    onDataChange(document.dataRepresentation())
                } label: {
                    Image(systemName: "trash")
                        .accessibilityHidden(true)
                }
                .buttonStyle(.borderless)
                .help("清空画板")
                .accessibilityLabel("清空画板")
                .accessibilityIdentifier("editor.drawing.\(block.id).clear")
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("editor.drawing.\(block.id)")
        .onAppear {
            loadDrawingDocumentIfNeeded(force: true)
        }
        .onChange(of: attachment?.id) { _, _ in
            loadDrawingDocumentIfNeeded(force: true)
        }
        .onChange(of: attachment?.localPath) { _, _ in
            loadDrawingDocumentIfNeeded(force: true)
        }
    }

    private var drawingTitle: String {
        let trimmed = block.textPlain.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        return attachment?.originalFilename ?? "画板"
    }

    private func loadDrawingDocumentIfNeeded(force: Bool = false) {
        let nextAttachmentID = attachment?.id
        let nextAttachmentPath = attachment?.localPath
        guard force
            || nextAttachmentID != loadedAttachmentID
            || nextAttachmentPath != loadedAttachmentPath else {
            return
        }

        loadedAttachmentID = nextAttachmentID
        loadedAttachmentPath = nextAttachmentPath
        document = EditorDrawingDocument(data: drawingData)
    }

    private var drawingData: Data {
        guard let path = attachment?.localPath, !path.isEmpty else {
            return Data()
        }
        return (try? Data(contentsOf: URL(fileURLWithPath: path))) ?? Data()
    }
}

private struct EditorDrawingCanvas: View {
    @Binding var document: EditorDrawingDocument
    let onCommit: (EditorDrawingDocument) -> Void

    @State private var activeStroke: EditorDrawingDocument.Stroke?

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, _ in
                for stroke in document.strokes {
                    draw(stroke, in: &context, opacity: 0.86)
                }
                if let activeStroke {
                    draw(activeStroke, in: &context, opacity: 0.72)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        appendPoint(
                            EditorDrawingDocument.Point(
                                location: value.location,
                                canvasSize: proxy.size
                            )
                        )
                    }
                    .onEnded { _ in
                        commitActiveStroke()
                    }
            )
        }
    }

    private func appendPoint(_ point: EditorDrawingDocument.Point) {
        if var stroke = activeStroke {
            guard stroke.shouldAppend(point) else {
                return
            }
            stroke.points.append(point)
            activeStroke = stroke
        } else {
            activeStroke = EditorDrawingDocument.Stroke(points: [point])
        }
    }

    private func commitActiveStroke() {
        guard let activeStroke else {
            return
        }
        var nextDocument = document
        nextDocument.strokes.append(activeStroke)
        document = nextDocument
        self.activeStroke = nil
        onCommit(nextDocument)
    }

    private func draw(
        _ stroke: EditorDrawingDocument.Stroke,
        in context: inout GraphicsContext,
        opacity: Double
    ) {
        guard let firstPoint = stroke.points.first else {
            return
        }
        guard stroke.points.count > 1 else {
            context.fill(
                Path(ellipseIn: CGRect(
                    x: firstPoint.x - stroke.lineWidth / 2,
                    y: firstPoint.y - stroke.lineWidth / 2,
                    width: stroke.lineWidth,
                    height: stroke.lineWidth
                )),
                with: .color(Color.primary.opacity(opacity))
            )
            return
        }

        var path = Path()
        path.move(to: firstPoint.cgPoint)
        for point in stroke.points.dropFirst() {
            path.addLine(to: point.cgPoint)
        }
        context.stroke(
            path,
            with: .color(Color.primary.opacity(opacity)),
            style: StrokeStyle(
                lineWidth: stroke.lineWidth,
                lineCap: .round,
                lineJoin: .round
            )
        )
    }
}

private struct EditorDrawingDocument: Codable, Equatable {
    var version = 1
    var strokes: [Stroke] = []

    static let empty = EditorDrawingDocument()

    init(strokes: [Stroke] = []) {
        self.strokes = strokes
    }

    init(data: Data) {
        guard !data.isEmpty,
              let decoded = try? JSONDecoder().decode(EditorDrawingDocument.self, from: data) else {
            self = .empty
            return
        }
        self = decoded
    }

    func dataRepresentation() -> Data {
        (try? JSONEncoder().encode(self)) ?? Data()
    }

    struct Stroke: Codable, Equatable, Identifiable {
        var id = UUID()
        var points: [Point]
        var lineWidth: CGFloat = 2.4

        func shouldAppend(_ point: Point) -> Bool {
            guard let lastPoint = points.last else {
                return true
            }
            return lastPoint.distance(to: point) > 0.75
        }
    }

    struct Point: Codable, Equatable {
        var x: CGFloat
        var y: CGFloat

        init(x: CGFloat, y: CGFloat) {
            self.x = x
            self.y = y
        }

        init(location: CGPoint, canvasSize: CGSize) {
            x = min(max(location.x, 0), max(canvasSize.width, 0))
            y = min(max(location.y, 0), max(canvasSize.height, 0))
        }

        var cgPoint: CGPoint {
            CGPoint(x: x, y: y)
        }

        func distance(to point: Point) -> CGFloat {
            hypot(x - point.x, y - point.y)
        }
    }
}

private struct AttachmentBlockRow: View {
    let block: BlockSnapshot
    let attachment: AttachmentSnapshot?
    let generationStatus: AttachmentPreviewGenerationStatus
    let searchHighlight: SearchTransientHighlight?
    let isBlockSelected: Bool
    let onRetryPreview: (String) -> Void
    let onImageResizeActiveChange: (Bool) -> Void
    let onImageDisplayWidthChange: (Double) -> Void

    @State private var transientImageWidth: CGFloat?
    @State private var resizeDragStartWidth: CGFloat?
    @State private var measuredImageAvailableWidth = AttachmentImageDisplayWidthPolicy.defaultWidth
    @State private var presentedImagePreview: AttachmentImagePreviewPayload?

    var body: some View {
        let descriptor = AttachmentBlockChromeDescriptor(
            block: block,
            attachment: attachment,
            generationStatus: generationStatus
        )
        imagePreviewPresentation(
            Group {
                if block.type == .attachmentImage, let thumbnailImage {
                    imageAttachmentBody(thumbnailImage: thumbnailImage, descriptor: descriptor)
                } else {
                    compactAttachmentBody(descriptor: descriptor)
                }
            }
        )
    }

    @ViewBuilder
    private func imagePreviewPresentation<Content: View>(_ content: Content) -> some View {
#if os(iOS)
        content.fullScreenCover(item: $presentedImagePreview) { payload in
            AttachmentImagePreviewOverlay(payload: payload) {
                presentedImagePreview = nil
            }
        }
#else
        content.sheet(item: $presentedImagePreview) { payload in
            AttachmentImagePreviewOverlay(payload: payload) {
                presentedImagePreview = nil
            }
        }
#endif
    }

    private func imageAttachmentBody(
        thumbnailImage: AttachmentPreviewImage,
        descriptor: AttachmentBlockChromeDescriptor
    ) -> some View {
        GeometryReader { proxy in
            let availableWidth = max(1, proxy.size.width)
            let resolvedWidth = transientImageWidth ?? AttachmentImageDisplayWidthPolicy.resolvedWidth(
                storedWidth: block.attachmentDisplayWidth,
                availableWidth: availableWidth
            )
            let imageHeight = thumbnailImage.height(forWidth: resolvedWidth)
            let showsCaption = AttachmentImageCaptionVisibilityPolicy.isVisible(
                blockText: block.textPlain,
                originalFilename: attachment?.originalFilename
            )

            VStack(alignment: .leading, spacing: showsCaption ? 6 : 0) {
                ZStack(alignment: .bottomTrailing) {
                    Button {
                        presentImagePreview(fallbackImage: thumbnailImage)
                    } label: {
                        thumbnailImage.image
                            .resizable()
                            .scaledToFit()
                            .frame(width: resolvedWidth, height: imageHeight, alignment: .leading)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            .overlay(alignment: .topLeading) {
                                imageSearchHighlightOverlay(width: resolvedWidth, height: imageHeight)
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .stroke(
                                        AttachmentImageSelectionChrome.imageBorderColor(isSelected: isBlockSelected),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("查看图片：\(imagePreviewTitle)")
                    .accessibilityValue("打开后可双指缩放")
                    .accessibilityIdentifier("editor.attachment.\(block.id).image-open")

                    imageResizeHandle(
                        currentWidth: resolvedWidth,
                        availableWidth: availableWidth
                    )
                }

                if showsCaption {
                    Text(block.textPlain)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(width: resolvedWidth, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .onAppear {
                measuredImageAvailableWidth = availableWidth
            }
            .onChange(of: availableWidth) { _, newWidth in
                measuredImageAvailableWidth = newWidth
            }
            .onDisappear {
                onImageResizeActiveChange(false)
            }
        }
        .frame(height: imageBodyHeight(for: thumbnailImage))
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier(descriptor.accessibilityIdentifier)
        .accessibilityLabel(descriptor.accessibilityLabel)
        .accessibilityValue(descriptor.accessibilityValue)
    }

    @ViewBuilder
    private func imageSearchHighlightOverlay(width: CGFloat, height: CGFloat) -> some View {
        if let searchHighlight,
           searchHighlight.attachmentID == attachment?.id,
           !searchHighlight.rects.isEmpty {
            let displayRects = SearchHighlightOverlayPolicy.displayRects(
                highlightRects: searchHighlight.rects,
                imageSize: CGSize(width: width, height: height)
            )

            ZStack(alignment: .topLeading) {
                ForEach(Array(displayRects.enumerated()), id: \.offset) { _, rect in
                    RoundedRectangle(cornerRadius: SearchHighlightOverlayPolicy.rectCornerRadius, style: .continuous)
                        .fill(SearchHighlightOverlayPolicy.rectFillColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: SearchHighlightOverlayPolicy.rectCornerRadius, style: .continuous)
                                .stroke(SearchHighlightOverlayPolicy.rectStrokeColor, lineWidth: 1)
                        )
                        .frame(width: rect.width, height: rect.height)
                        .offset(x: rect.minX, y: rect.minY)
                }
            }
            .frame(width: width, height: height, alignment: .topLeading)
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("图片搜索命中高亮")
            .accessibilityIdentifier("editor.attachment.\(block.id).ocr-highlight")
            .transition(.opacity)
        }
    }

    private func imageBodyHeight(for thumbnailImage: AttachmentPreviewImage) -> CGFloat {
        let width = transientImageWidth ?? AttachmentImageDisplayWidthPolicy.resolvedWidth(
            storedWidth: block.attachmentDisplayWidth,
            availableWidth: measuredImageAvailableWidth
        )
        let showsCaption = AttachmentImageCaptionVisibilityPolicy.isVisible(
            blockText: block.textPlain,
            originalFilename: attachment?.originalFilename
        )
        return thumbnailImage.height(forWidth: width)
            + (showsCaption ? 24 : 0)
            + 2
    }

    private func imageResizeHandle(
        currentWidth: CGFloat,
        availableWidth: CGFloat
    ) -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(Color.black.opacity(0.45))
            .frame(
                width: AttachmentImageDisplayWidthPolicy.resizeHandleSize,
                height: AttachmentImageDisplayWidthPolicy.resizeHandleSize
            )
            .overlay(
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
            )
            .padding(6)
            .contentShape(Rectangle())
            .background(imageResizeHandleFrameReporter)
            .gesture(
                DragGesture(
                    minimumDistance: AttachmentImageResizeGesturePolicy.minimumDistance,
                    coordinateSpace: AttachmentImageResizeGesturePolicy.swiftUICoordinateSpace
                )
                    .onChanged { value in
                        let startWidth = resizeDragStartWidth ?? currentWidth
                        if resizeDragStartWidth == nil {
                            onImageResizeActiveChange(true)
                        }
                        resizeDragStartWidth = startWidth
                        setTransientImageWidthDuringResize(
                            AttachmentImageDisplayWidthPolicy.widthAfterDrag(
                                startWidth: startWidth,
                                translation: value.translation,
                                availableWidth: availableWidth
                            )
                        )
                    }
                    .onEnded { value in
                        let startWidth = resizeDragStartWidth ?? currentWidth
                        let finalWidth = AttachmentImageDisplayWidthPolicy.widthAfterDrag(
                            startWidth: startWidth,
                            translation: value.translation,
                            availableWidth: availableWidth
                        )
                        setTransientImageWidthDuringResize(nil)
                        onImageResizeActiveChange(false)
                        onImageDisplayWidthChange(AttachmentImageDisplayWidthPolicy.storedWidth(finalWidth))
                    }
            )
            .accessibilityLabel("调整图片大小")
            .accessibilityIdentifier("editor.attachment.\(block.id).resize-handle")
    }

    private var imageResizeHandleFrameReporter: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: AttachmentResizeHandleFramePreferenceKey.self,
                value: [block.id: proxy.frame(in: .named(EditorCanvasCoordinateSpace.blockSelection))]
            )
        }
    }

    private func setTransientImageWidthDuringResize(_ width: CGFloat?) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            transientImageWidth = width
            if width == nil {
                resizeDragStartWidth = nil
            }
        }
    }

    private func compactAttachmentBody(descriptor: AttachmentBlockChromeDescriptor) -> some View {
        let diagnosticReason = imagePreviewDiagnosticReason
        let diagnosticMessage = diagnosticReason.map(AttachmentImagePreviewDiagnosticResolver.message(for:))
        return HStack(spacing: 10) {
            if let thumbnailImage {
                thumbnailImage.image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 52, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .accessibilityHidden(true)
            } else if diagnosticReason?.showsWarningIcon == true || isPreviewFailed {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title3)
                    .foregroundStyle(StatusChrome.warningTextToken.color)
                    .frame(width: 52, height: 40)
                    .background(StatusChrome.warningFillToken.color)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .accessibilityHidden(true)
            } else if isPreviewPending || diagnosticReason == .waitingForSync {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 52, height: 40)
                    .background(EditorDesignTokens.Colors.elevatedSurface.color.opacity(0.65))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .accessibilityLabel("正在生成附件预览")
                    .accessibilityIdentifier("editor.attachment.\(block.id).preview-pending")
            } else {
                Image(systemName: iconName)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }

            VStack(alignment: .leading, spacing: diagnosticMessage == nil ? 2 : 3) {
                Text(block.textPlain)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(diagnosticMessage?.title ?? kindLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let diagnosticMessage {
                    Text(diagnosticMessage.detail)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("editor.attachment.\(block.id).preview-diagnostic")
                }
            }

            Spacer(minLength: 8)

            if isPreviewFailed, let attachment {
                Button {
                    onRetryPreview(attachment.id)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("重试预览")
                .accessibilityLabel("重试附件预览")
                .accessibilityIdentifier("editor.attachment.\(block.id).preview-retry")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(SpecialBlockSurfaceChrome.attachmentBackgroundToken.color)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .accessibilityIdentifier(descriptor.accessibilityIdentifier)
        .accessibilityLabel(descriptor.accessibilityLabel)
        .accessibilityValue(diagnosticMessage?.title ?? descriptor.accessibilityValue)
        .onAppear {
            logImagePreviewDiagnosticIfNeeded(diagnosticReason)
        }
        .onChange(of: diagnosticReason) { _, newReason in
            logImagePreviewDiagnosticIfNeeded(newReason)
        }
    }

    private var thumbnailImage: AttachmentPreviewImage? {
        attachmentPreviewImage(preferOriginal: false)
    }

    private var fullSizePreviewImage: AttachmentPreviewImage? {
        attachmentPreviewImage(preferOriginal: true)
    }

    private func attachmentPreviewImage(preferOriginal: Bool) -> AttachmentPreviewImage? {
        for path in imageCandidatePaths(preferOriginal: preferOriginal) {
            if let image = loadPreviewImage(at: path) {
                return image
            }
        }
        return nil
    }

    private func loadPreviewImage(at path: String) -> AttachmentPreviewImage? {
#if os(macOS)
        guard let image = NSImage(contentsOfFile: path) else {
            return nil
        }
        return AttachmentPreviewImage(image: Image(nsImage: image), size: image.size, sourcePath: path)
#elseif os(iOS)
        guard let image = UIImage(contentsOfFile: path) else {
            return nil
        }
        return AttachmentPreviewImage(image: Image(uiImage: image), size: image.size, sourcePath: path)
#else
        return nil
#endif
    }

    private func imageCandidatePaths(preferOriginal: Bool) -> [String] {
        guard let attachment else {
            return []
        }

        let candidatePaths = attachment.previewCandidatePaths(for: block)
        guard preferOriginal,
              !attachment.localPath.isEmpty,
              candidatePaths.contains(attachment.localPath) else {
            return candidatePaths
        }

        return [attachment.localPath] + candidatePaths.filter { $0 != attachment.localPath }
    }

    private var imagePreviewDiagnosticReason: AttachmentImagePreviewDiagnosticReason? {
        guard block.type == .attachmentImage else {
            return nil
        }
        return AttachmentImagePreviewDiagnosticResolver.reason(
            attachmentAvailable: attachment != nil,
            candidatePathStates: imageCandidatePathStates,
            isPending: isPreviewPending,
            isGenerationFailed: isPreviewFailed
        )
    }

    private var imageCandidatePathStates: [AttachmentImageCandidatePathState] {
        imageCandidatePaths(preferOriginal: false).map { path in
            guard FileManager.default.fileExists(atPath: path) else {
                return .missing
            }
            return loadPreviewImage(at: path) == nil ? .undecodable : .loadable
        }
    }

    private var imagePreviewTitle: String {
        let trimmed = block.textPlain.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        return attachment?.originalFilename ?? "图片"
    }

    private func presentImagePreview(fallbackImage: AttachmentPreviewImage) {
        let image = fullSizePreviewImage ?? fallbackImage
        presentedImagePreview = AttachmentImagePreviewPayload(
            id: "\(block.id)-\(image.sourcePath)",
            blockID: block.id,
            title: imagePreviewTitle,
            image: image
        )
    }

    private func logImagePreviewDiagnosticIfNeeded(_ reason: AttachmentImagePreviewDiagnosticReason?) {
        guard let reason else {
            return
        }
        EditorLog.attachment.error(
            "attachment_image_preview_unavailable block_id=\(block.id, privacy: .public) attachment_id=\(attachment?.id ?? "nil", privacy: .public) reason=\(reason.rawValue, privacy: .public) candidate_count=\(imageCandidatePathStates.count, privacy: .public)"
        )
    }

    private var previewState: AttachmentPreviewState {
        attachment?.previewState(for: block) ?? .unavailable
    }

    private var isPreviewPending: Bool {
        generationStatus == .generating || previewState == .pending
    }

    private var isPreviewFailed: Bool {
        if case .failed = generationStatus {
            return true
        }
        return false
    }

    private var iconName: String {
        switch block.type {
        case .attachmentImage:
            return "photo"
        case .attachmentVideo:
            return "film"
        case .attachmentFile:
            return "doc"
        default:
            return "doc.text"
        }
    }

    private var kindLabel: String {
        if isPreviewFailed {
            return "预览失败"
        }

        switch block.type {
        case .attachmentImage:
            return isPreviewPending ? "图片，正在生成预览" : "图片"
        case .attachmentVideo:
            return isPreviewPending ? "视频，正在生成预览" : "视频"
        case .attachmentFile:
            return "文件"
        default:
            return "文本"
        }
    }
}

#Preview {
    EditorShellView(
        viewModel: WorkspaceViewModel(
            snapshot: WorkspaceSnapshot(
                workspaces: [WorkspaceSummary(id: "workspace-local", name: "本地")],
                pages: [PageSummary(id: "page-welcome", workspaceID: "workspace-local", title: "欢迎")],
                blocks: [
                    BlockSnapshot(
                        id: "block-welcome-001",
                        pageID: "page-welcome",
                        parentBlockID: nil,
                        orderKey: "000001",
                        type: .paragraph,
                        textPlain: "开始用块写作。"
                    )
                ],
                attachments: [],
                selectedWorkspaceID: "workspace-local",
                selectedPageID: "page-welcome"
            )
        )
    )
}
