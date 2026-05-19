# Mobile Three-Screen Shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the approved Bear-style iPhone compact shell with library, document list, and editor screens, defaulting to the editor.

**Architecture:** Keep the current compact `NavigationStack` and make the stack represent the three screens explicitly: root library, collection document list, then editor page. Add small route-planning helpers so the default path and reveal transitions are testable without UI automation. Reuse existing compact list/editor/outline components and avoid block chrome, TextKit, storage, and desktop shell changes.

**Tech Stack:** SwiftUI, XCTest, XcodeGen-generated `Editor.xcodeproj`, existing `EditorTests` and `EditorIOSUITests`.

---

## File Structure

- Modify `Sources/EditorCore/Features/Shell/EditorShellView.swift`
  - Add compact shell route helpers near `CompactRoute`.
  - Change `CompactEditorShell` initial and pending navigation paths from direct page routes to collection-plus-page routes.
  - Restyle `CompactHomeView` as the library/sidebar screen.
  - Keep `CompactCollectionPageListView` as the middle document-list screen.
  - Keep `EditorCanvasView` as the editor screen and retain its mobile outline drawer.
- Modify `Tests/EditorTests/EditorBlockChromeTests.swift`
  - Add route-helper tests for screen order, default editor screen, initial route, and reveal transitions.
- Modify `Tests/EditorIOSUITests/EditorIOSEditingUITests.swift`
  - Update existing compact navigation UI tests from old "近期打开" home assumptions to the new library/document-list/editor stack.
  - Add a focused reveal test for editor -> document list -> library.

### Task 1: Compact Route Model

**Files:**
- Modify: `Tests/EditorTests/EditorBlockChromeTests.swift`
- Modify: `Sources/EditorCore/Features/Shell/EditorShellView.swift`

- [ ] **Step 1: Write failing route-model tests**

Add tests in `EditorBlockChromeTests`:

```swift
func testCompactShellScreenOrderDefaultsToEditorAsThirdScreen() {
    XCTAssertEqual(CompactShellScreen.library.rawValue, 1)
    XCTAssertEqual(CompactShellScreen.documentList.rawValue, 2)
    XCTAssertEqual(CompactShellScreen.editor.rawValue, 3)
    XCTAssertEqual(CompactShellRoutePlanner.defaultActiveScreen, .editor)
}

func testCompactShellInitialPathRoutesThroughDocumentListToEditor() {
    let workspaceID = "workspace"
    let page = PageSummary(id: "page-a", workspaceID: workspaceID, title: "A")
    let snapshot = WorkspaceSnapshot(
        workspaces: [WorkspaceSummary(id: workspaceID, name: "空间")],
        pages: [page],
        blocks: [],
        attachments: [],
        selectedWorkspaceID: workspaceID,
        selectedPageID: page.id
    )

    XCTAssertEqual(
        CompactShellRoutePlanner.initialPath(snapshot: snapshot, selectedCollection: .recent),
        [.collection(.allDocuments), .page(page.id)]
    )
}

func testCompactShellRevealPageListUsesCurrentDocumentCollection() {
    XCTAssertEqual(
        CompactShellRoutePlanner.documentListRoute(selectedCollection: .favorites),
        .collection(.favorites)
    )
    XCTAssertEqual(
        CompactShellRoutePlanner.documentListRoute(selectedCollection: .recent),
        .collection(.allDocuments)
    )
}
```

- [ ] **Step 2: Run route-model tests to verify RED**

Run:

```bash
xcodebuild test -project Editor.xcodeproj -scheme EditorTests -only-testing:EditorTests/EditorBlockChromeTests/testCompactShellScreenOrderDefaultsToEditorAsThirdScreen -only-testing:EditorTests/EditorBlockChromeTests/testCompactShellInitialPathRoutesThroughDocumentListToEditor -only-testing:EditorTests/EditorBlockChromeTests/testCompactShellRevealPageListUsesCurrentDocumentCollection
```

Expected: compile failure because `CompactShellScreen` and `CompactShellRoutePlanner` do not exist.

- [ ] **Step 3: Implement minimal compact route model**

Add near `CompactRoute`:

```swift
enum CompactShellScreen: Int, Equatable, Sendable {
    case library = 1
    case documentList = 2
    case editor = 3
}

enum CompactShellRoutePlanner {
    static let defaultActiveScreen = CompactShellScreen.editor

    static func initialPath(
        snapshot: WorkspaceSnapshot,
        selectedCollection: WorkspaceCollection
    ) -> [CompactRoute] {
        guard let pageID = CompactInitialNavigationResolver.initialPageID(
            selectedPageID: snapshot.selectedPageID,
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

    private static func collectionForPage(
        _ pageID: String,
        snapshot: WorkspaceSnapshot,
        selectedCollection: WorkspaceCollection
    ) -> WorkspaceCollection {
        let diaryPageIDs = Set(snapshot.diaryPages.map(\.pageID))
        if selectedCollection != .recent,
           CompactCollectionPageListModel.pages(snapshot: snapshot, collection: selectedCollection)
            .contains(where: { $0.id == pageID }) {
            return selectedCollection
        }
        if diaryPageIDs.contains(pageID) {
            return .diary
        }
        return .allDocuments
    }
}
```

- [ ] **Step 4: Run route-model tests to verify GREEN**

Run the same `xcodebuild test ... -only-testing` command.

Expected: the three route-model tests pass.

### Task 2: Compact Navigation Stack

**Files:**
- Modify: `Tests/EditorIOSUITests/EditorIOSEditingUITests.swift`
- Modify: `Sources/EditorCore/Features/Shell/EditorShellView.swift`

- [ ] **Step 1: Write/update failing UI tests for the three-screen stack**

Update `testIPhoneHomeNewDocumentButtonOpensEditableBlankPage` and `testIPhoneAllDocumentsShowsPreviewCardList` to reveal the library through the middle list. Add:

```swift
@MainActor
func testIPhoneEditorBackRevealsDocumentListThenLibrary() {
    let app = makeApp()
    app.launch()

    let firstTextView = app.textViews.matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "editor.text.")
    ).firstMatch
    XCTAssertTrue(firstTextView.waitForExistence(timeout: 5))

    let documentListBackButton = app.navigationBars.buttons["全部文档"]
    XCTAssertTrue(documentListBackButton.waitForExistence(timeout: 5))
    documentListBackButton.tap()

    XCTAssertTrue(
        app.scrollViews["editor.compact-document-list"].waitForExistence(timeout: 5),
        "Back from the editor should reveal the middle document-list screen"
    )
    XCTAssertTrue(app.buttons["editor.page.page-welcome"].waitForExistence(timeout: 5))

    let libraryBackButton = app.navigationBars.buttons["资料库"]
    XCTAssertTrue(libraryBackButton.waitForExistence(timeout: 5))
    libraryBackButton.tap()

    XCTAssertTrue(
        app.scrollViews["editor.compact-library"].waitForExistence(timeout: 5),
        "Back from the document list should reveal the left library screen"
    )
    XCTAssertTrue(app.buttons["editor.compact.all-documents"].waitForExistence(timeout: 5))
}
```

- [ ] **Step 2: Run iOS UI test to verify RED**

Run:

```bash
xcodebuild test -project Editor.xcodeproj -scheme EditorIOSUITests -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:EditorIOSUITests/EditorIOSEditingUITests/testIPhoneEditorBackRevealsDocumentListThenLibrary
```

Expected: failure because the current compact stack opens editor directly over the old home screen rather than through the document-list screen, and the new accessibility identifiers do not exist.

- [ ] **Step 3: Implement compact stack path routing**

Change `CompactEditorShell` so:

```swift
_path = State(
    initialValue: CompactShellRoutePlanner.initialPath(
        snapshot: viewModel.snapshot,
        selectedCollection: viewModel.selectedCollection
    )
)
_didPushInitialPage = State(initialValue: !initialPath.isEmpty)
```

Change `pushInitialPageIfNeeded` and `pushPageIfNeeded(_:)` to set:

```swift
path = CompactShellRoutePlanner.pathForPage(
    pageID,
    snapshot: viewModel.snapshot,
    selectedCollection: viewModel.selectedCollection
)
```

Change `revealPageList()` to:

```swift
path = [CompactShellRoutePlanner.documentListRoute(selectedCollection: viewModel.selectedCollection)]
```

- [ ] **Step 4: Make diary collections list-like in compact mode**

Simplify `CompactCollectionDestination` so diary uses `CompactCollectionPageListView` too, while retaining `viewModel.selectCollection(collection)` on appear:

```swift
CompactCollectionPageListView(viewModel: viewModel, collection: collection)
```

- [ ] **Step 5: Run updated UI test or document environment blocker**

Run the same iOS UI test. If the named simulator is unavailable, run `xcrun simctl list devices available` and then use an available iPhone simulator. If no simulator can run, keep the RED/GREEN model covered by unit tests and run an iOS build in the final verification.

### Task 3: Library Screen Visual Shell

**Files:**
- Modify: `Tests/EditorTests/EditorBlockChromeTests.swift`
- Modify: `Sources/EditorCore/Features/Shell/EditorShellView.swift`

- [ ] **Step 1: Write failing chrome tests**

Add:

```swift
func testCompactLibraryChromeUsesBearLikeDarkSidebar() {
    assertColor(CompactLibraryChrome.backgroundToken, red: 0x30, green: 0x34, blue: 0x37)
    XCTAssertEqual(CompactLibraryChrome.rowCornerRadius, 13)
    XCTAssertEqual(CompactLibraryChrome.selectedRowOpacity, 0.13)
    XCTAssertEqual(CompactLibraryChrome.mutedForegroundOpacity, 0.58)
}
```

- [ ] **Step 2: Run chrome test to verify RED**

Run:

```bash
xcodebuild test -project Editor.xcodeproj -scheme EditorTests -only-testing:EditorTests/EditorBlockChromeTests/testCompactLibraryChromeUsesBearLikeDarkSidebar
```

Expected: compile failure because `CompactLibraryChrome` does not exist.

- [ ] **Step 3: Implement compact library chrome**

Add:

```swift
enum CompactLibraryChrome {
    static let backgroundToken = EditorColorToken.hex(0x30, 0x34, 0x37)
    static let rowCornerRadius: Double = 13
    static let selectedRowOpacity: Double = 0.13
    static let mutedForegroundOpacity: Double = 0.58

    static var backgroundColor: Color {
        backgroundToken.color
    }
}
```

Update `CompactHomeView` to:

- use `CompactLibraryChrome.backgroundColor`;
- set `.navigationTitle("资料库")`;
- expose `.accessibilityIdentifier("editor.compact-library")`;
- keep `editor.compact.new-document`, `editor.compact.all-documents`, `editor.compact.diary`, and `editor.compact.favorites` identifiers.

- [ ] **Step 4: Run chrome test to verify GREEN**

Run the same `xcodebuild test ... testCompactLibraryChromeUsesBearLikeDarkSidebar` command.

Expected: pass.

### Task 4: Document List Surface And Regression Wiring

**Files:**
- Modify: `Tests/EditorIOSUITests/EditorIOSEditingUITests.swift`
- Modify: `Sources/EditorCore/Features/Shell/EditorShellView.swift`

- [ ] **Step 1: Add document-list accessibility and updated test expectations**

Add `.accessibilityIdentifier("editor.compact-document-list")` to `CompactCollectionPageListView`'s `ScrollView`.

Update existing iOS UI tests so:

- editor back button uses `"全部文档"` instead of `"近期打开"`;
- library back button uses `"资料库"`;
- document-list assertions target `editor.compact-document-list`;
- library assertions target `editor.compact-library`.

- [ ] **Step 2: Verify focused iOS launch/editing behavior**

Run:

```bash
xcodebuild test -project Editor.xcodeproj -scheme EditorIOSUITests -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:EditorIOSUITests/EditorIOSEditingUITests/testIPhoneLaunchOpensEditablePageImmediately
```

Expected: pass if simulator is available; otherwise capture the exact simulator blocker and cover with unit tests plus iOS build.

- [ ] **Step 3: Verify document-list reveal behavior**

Run:

```bash
xcodebuild test -project Editor.xcodeproj -scheme EditorIOSUITests -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:EditorIOSUITests/EditorIOSEditingUITests/testIPhoneEditorBackRevealsDocumentListThenLibrary
```

Expected: pass if simulator is available; otherwise capture the exact simulator blocker.

### Task 5: Final Build And Regression Checks

**Files:**
- Verify only.

- [ ] **Step 1: Run focused unit tests**

Run:

```bash
xcodebuild test -project Editor.xcodeproj -scheme EditorTests -only-testing:EditorTests/EditorBlockChromeTests
```

Expected: pass.

- [ ] **Step 2: Run iOS build**

Run:

```bash
xcodebuild -quiet build -project Editor.xcodeproj -scheme EditorIOS -configuration Debug -destination 'generic/platform=iOS'
```

Expected: build succeeds.

- [ ] **Step 3: Run diff hygiene**

Run:

```bash
git diff --check
```

Expected: no whitespace errors.

- [ ] **Step 4: Commit implementation**

Stage only:

```bash
git add Sources/EditorCore/Features/Shell/EditorShellView.swift Tests/EditorTests/EditorBlockChromeTests.swift Tests/EditorIOSUITests/EditorIOSEditingUITests.swift
git commit -m "Implement mobile three-screen shell"
```
