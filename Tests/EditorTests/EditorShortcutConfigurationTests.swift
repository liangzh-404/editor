import SwiftUI
import XCTest

final class EditorShortcutConfigurationTests: XCTestCase {
    func testCraftDefaultShortcutsMatchObservedMenuItems() {
        let shortcuts = EditorShortcutConfiguration.craftDefaults

        XCTAssertEqual(shortcuts.shortcut(for: .newDocument)?.rawValue, "cmd+n")
        XCTAssertEqual(shortcuts.shortcut(for: .openToday)?.rawValue, "cmd+opt+n")
        XCTAssertEqual(shortcuts.shortcut(for: .navigateBack)?.rawValue, "cmd+[")
        XCTAssertEqual(shortcuts.shortcut(for: .navigateForward)?.rawValue, "cmd+right")
        XCTAssertEqual(shortcuts.shortcut(for: .convertBlockToPage)?.rawValue, "cmd+]")
        XCTAssertEqual(shortcuts.shortcut(for: .quickOpen)?.rawValue, "cmd+o")
        XCTAssertEqual(shortcuts.shortcut(for: .showAllDocuments)?.rawValue, "cmd+opt+1")
        XCTAssertEqual(shortcuts.shortcut(for: .showFavorites)?.rawValue, "cmd+opt+2")
        XCTAssertEqual(shortcuts.shortcut(for: .toggleFocusMode)?.rawValue, "cmd+opt+f")
        XCTAssertEqual(
            EditorShortcutCommand.visibleCommands,
            [
                .newDocument,
                .openToday,
                .navigateBack,
                .navigateForward,
                .quickOpen,
                .showAllDocuments,
                .showFavorites,
                .toggleFocusMode,
                .insertMarkdownLink,
                .convertBlockToPage
            ]
        )
    }

    func testShortcutParserAcceptsCraftStyleDescriptors() throws {
        let newDocument = try XCTUnwrap(EditorKeyboardShortcut(rawValue: "cmd+n"))
        XCTAssertEqual(newDocument.keyEquivalent, "n")
        XCTAssertEqual(newDocument.modifiers, .command)

        let today = try XCTUnwrap(EditorKeyboardShortcut(rawValue: "cmd+opt+n"))
        XCTAssertEqual(today.keyEquivalent, "n")
        XCTAssertEqual(today.modifiers, [.command, .option])

        let back = try XCTUnwrap(EditorKeyboardShortcut(rawValue: "cmd+["))
        XCTAssertEqual(back.keyEquivalent, "[")
        XCTAssertEqual(back.modifiers, .command)

        let forward = try XCTUnwrap(EditorKeyboardShortcut(rawValue: "cmd+right"))
        XCTAssertEqual(forward.keyEquivalent, .rightArrow)
        XCTAssertEqual(forward.modifiers, .command)
    }

    func testShortcutParserBuildsMacDisplayGlyphsForRecordedShortcuts() throws {
        let shortcut = try XCTUnwrap(EditorKeyboardShortcut(rawValue: "cmd+opt+shift+n"))

        XCTAssertEqual(shortcut.rawValue, "cmd+opt+shift+n")
        XCTAssertEqual(shortcut.displayValue, "⌘⌥⇧N")
    }

    func testGlobalShortcutResolverMatchesRecordedShellCommandsInsideTextFocus() {
        let suiteName = "EditorShortcutConfigurationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        defaults.set("cmd+r", forKey: EditorShortcutCommand.openToday.userDefaultsKey)

        let shortcuts = EditorShortcutConfiguration(userDefaults: defaults)

        XCTAssertEqual(
            EditorGlobalShortcutActionResolver.command(forRawValue: "cmd+r", configuration: shortcuts),
            .openToday
        )
        XCTAssertEqual(
            EditorGlobalShortcutActionResolver.command(forRawValue: "cmd+opt+f", configuration: shortcuts),
            .toggleFocusMode
        )
        XCTAssertNil(
            EditorGlobalShortcutActionResolver.command(forRawValue: "cmd+k", configuration: shortcuts),
            "Inline editor shortcuts should stay on the editor bridge instead of the shell-level shortcut bridge"
        )
    }

    func testShortcutConfigurationUsesUserDefaultsOverrides() {
        let suiteName = "EditorShortcutConfigurationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        defaults.set("cmd+shift+n", forKey: EditorShortcutCommand.newDocument.userDefaultsKey)

        let shortcuts = EditorShortcutConfiguration(userDefaults: defaults)

        XCTAssertEqual(shortcuts.shortcut(for: .newDocument)?.rawValue, "cmd+shift+n")
        XCTAssertEqual(shortcuts.shortcut(for: .openToday)?.rawValue, "cmd+opt+n")
    }

    func testShortcutConfigurationFindsConflictsBeforeSavingOverrides() {
        let suiteName = "EditorShortcutConfigurationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        defaults.set("cmd+shift+n", forKey: EditorShortcutCommand.newDocument.userDefaultsKey)

        let shortcuts = EditorShortcutConfiguration(userDefaults: defaults)

        XCTAssertEqual(
            shortcuts.conflictingCommand(for: "cmd+shift+n", excluding: .openToday),
            .newDocument
        )
        XCTAssertNil(shortcuts.conflictingCommand(for: "cmd+shift+t", excluding: .openToday))
    }
}
