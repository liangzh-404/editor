import Foundation
import SwiftUI
#if os(macOS)
import AppKit
#endif

enum EditorShortcutCommand: String, CaseIterable, Identifiable {
    case newDocument
    case openToday
    case navigateBack
    case navigateForward
    case convertBlockToPage
    case quickOpen
    case showAllDocuments
    case showFavorites
    case toggleFocusMode
    case insertMarkdownLink

    var id: String {
        rawValue
    }

    static var visibleCommands: [EditorShortcutCommand] {
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
    }

    static var shellCommands: [EditorShortcutCommand] {
        [
            .newDocument,
            .openToday,
            .navigateBack,
            .navigateForward,
            .quickOpen,
            .showAllDocuments,
            .showFavorites,
            .toggleFocusMode
        ]
    }

    var userDefaultsKey: String {
        "editor.shortcuts.\(rawValue)"
    }

    var title: String {
        switch self {
        case .newDocument:
            return "新建文档"
        case .openToday:
            return "跳转到今日笔记"
        case .navigateBack:
            return "后退"
        case .navigateForward:
            return "前进"
        case .convertBlockToPage:
            return "变成页面"
        case .quickOpen:
            return "快速打开"
        case .showAllDocuments:
            return "全部文档"
        case .showFavorites:
            return "收藏"
        case .toggleFocusMode:
            return "专注模式"
        case .insertMarkdownLink:
            return "插入链接"
        }
    }

    var defaultShortcutRawValue: String {
        switch self {
        case .newDocument:
            return "cmd+n"
        case .openToday:
            return "cmd+opt+n"
        case .navigateBack:
            return "cmd+["
        case .navigateForward:
            return "cmd+right"
        case .convertBlockToPage:
            return "cmd+]"
        case .quickOpen:
            return "cmd+o"
        case .showAllDocuments:
            return "cmd+opt+1"
        case .showFavorites:
            return "cmd+opt+2"
        case .toggleFocusMode:
            return "cmd+opt+f"
        case .insertMarkdownLink:
            return "cmd+k"
        }
    }
}

struct EditorKeyboardShortcut: Equatable {
    let rawValue: String
    let keyEquivalent: KeyEquivalent
    let modifiers: EventModifiers

    init?(rawValue: String) {
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let parts = normalized
            .split(separator: "+")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard let keyPart = parts.last, !keyPart.isEmpty else {
            return nil
        }

        var modifiers: EventModifiers = []
        for modifierPart in parts.dropLast() {
            switch modifierPart {
            case "cmd", "command", "⌘":
                modifiers.insert(.command)
            case "shift", "⇧":
                modifiers.insert(.shift)
            case "opt", "option", "alt", "⌥":
                modifiers.insert(.option)
            case "ctrl", "control", "⌃":
                modifiers.insert(.control)
            default:
                return nil
            }
        }

        guard !modifiers.isEmpty else {
            return nil
        }

        self.rawValue = Self.canonicalRawValue(parts: parts)
        switch keyPart {
        case "left":
            self.keyEquivalent = .leftArrow
        case "right":
            self.keyEquivalent = .rightArrow
        case "up":
            self.keyEquivalent = .upArrow
        case "down":
            self.keyEquivalent = .downArrow
        default:
            self.keyEquivalent = KeyEquivalent(Character(keyPart))
        }
        self.modifiers = modifiers
    }

    private static func canonicalRawValue(parts: [String]) -> String {
        var canonicalParts: [String] = []
        if parts.dropLast().contains(where: { ["cmd", "command", "⌘"].contains($0) }) {
            canonicalParts.append("cmd")
        }
        if parts.dropLast().contains(where: { ["ctrl", "control", "⌃"].contains($0) }) {
            canonicalParts.append("ctrl")
        }
        if parts.dropLast().contains(where: { ["opt", "option", "alt", "⌥"].contains($0) }) {
            canonicalParts.append("opt")
        }
        if parts.dropLast().contains(where: { ["shift", "⇧"].contains($0) }) {
            canonicalParts.append("shift")
        }
        canonicalParts.append(parts.last ?? "")
        return canonicalParts.joined(separator: "+")
    }

    var displayValue: String {
        let parts = rawValue.split(separator: "+").map(String.init)
        guard let keyPart = parts.last else {
            return rawValue
        }

        var displayParts: [String] = []
        if modifiers.contains(.command) {
            displayParts.append("⌘")
        }
        if modifiers.contains(.control) {
            displayParts.append("⌃")
        }
        if modifiers.contains(.option) {
            displayParts.append("⌥")
        }
        if modifiers.contains(.shift) {
            displayParts.append("⇧")
        }
        displayParts.append(Self.displayKey(for: keyPart))
        return displayParts.joined()
    }

    private static func displayKey(for key: String) -> String {
        switch key {
        case "left":
            return "←"
        case "right":
            return "→"
        case "up":
            return "↑"
        case "down":
            return "↓"
        default:
            return key.uppercased()
        }
    }
}

struct EditorShortcutConfiguration {
    static var craftDefaults: EditorShortcutConfiguration {
        EditorShortcutConfiguration(userDefaults: nil)
    }

    private let userDefaults: UserDefaults?

    init(userDefaults: UserDefaults? = .standard) {
        self.userDefaults = userDefaults
    }

    func shortcut(for command: EditorShortcutCommand) -> EditorKeyboardShortcut? {
        if let override = userDefaults?.string(forKey: command.userDefaultsKey),
           let shortcut = EditorKeyboardShortcut(rawValue: override) {
            return shortcut
        }

        return EditorKeyboardShortcut(rawValue: command.defaultShortcutRawValue)
    }

    func conflictingCommand(
        for rawValue: String,
        excluding command: EditorShortcutCommand,
        in commands: [EditorShortcutCommand] = EditorShortcutCommand.visibleCommands
    ) -> EditorShortcutCommand? {
        guard let candidate = EditorKeyboardShortcut(rawValue: rawValue) else {
            return nil
        }

        return commands.first { otherCommand in
            guard otherCommand != command else {
                return false
            }
            return shortcut(for: otherCommand)?.rawValue == candidate.rawValue
        }
    }
}

enum EditorGlobalShortcutActionResolver {
    static func command(
        forRawValue rawValue: String,
        configuration: EditorShortcutConfiguration = EditorShortcutConfiguration(),
        commands: [EditorShortcutCommand] = EditorShortcutCommand.shellCommands
    ) -> EditorShortcutCommand? {
        guard let candidate = EditorKeyboardShortcut(rawValue: rawValue) else {
            return nil
        }

        return commands.first { command in
            configuration.shortcut(for: command)?.rawValue == candidate.rawValue
        }
    }
}

#if os(macOS)
extension NSEvent {
    var editorShortcutRawValue: String? {
        let supportedModifiers = modifierFlags.intersection([.command, .control, .option, .shift])
        guard !supportedModifiers.isEmpty,
              let keyPart = editorShortcutKeyPart else {
            return nil
        }

        var parts: [String] = []
        if supportedModifiers.contains(.command) {
            parts.append("cmd")
        }
        if supportedModifiers.contains(.control) {
            parts.append("ctrl")
        }
        if supportedModifiers.contains(.option) {
            parts.append("opt")
        }
        if supportedModifiers.contains(.shift) {
            parts.append("shift")
        }
        parts.append(keyPart)
        return parts.joined(separator: "+")
    }

    private var editorShortcutKeyPart: String? {
        switch specialKey {
        case .leftArrow:
            return "left"
        case .rightArrow:
            return "right"
        case .upArrow:
            return "up"
        case .downArrow:
            return "down"
        default:
            break
        }

        guard let rawKey = charactersIgnoringModifiers?.trimmingCharacters(in: .whitespacesAndNewlines),
              rawKey.count == 1 else {
            return nil
        }
        return rawKey.lowercased()
    }
}
#endif
