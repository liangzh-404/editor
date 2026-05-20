import Foundation
import SwiftUI

enum EditorShortcutCommand: String, CaseIterable, Identifiable {
    case newDocument
    case openToday
    case navigateBack
    case navigateForward
    case convertBlockToPage
    case quickOpen
    case showAllDocuments
    case showFavorites
    case insertMarkdownLink

    var id: String {
        rawValue
    }

    static var visibleCommands: [EditorShortcutCommand] {
        allCases.filter { $0 != .showFavorites }
    }

    var userDefaultsKey: String {
        "editor.shortcuts.\(rawValue)"
    }

    var title: String {
        switch self {
        case .newDocument:
            return "新建文档"
        case .openToday:
            return "跳到今天"
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
}
