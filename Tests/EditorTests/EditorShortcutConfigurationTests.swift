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
}
