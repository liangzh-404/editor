import Foundation

struct WorkspaceSummary: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
}

struct PageSummary: Identifiable, Equatable, Sendable {
    let id: String
    let workspaceID: String
    let title: String
}

enum BlockType: String, Equatable, Sendable {
    case paragraph
}

struct BlockSnapshot: Identifiable, Equatable, Sendable {
    let id: String
    let pageID: String
    let parentBlockID: String?
    let orderKey: String
    let type: BlockType
    let textPlain: String
}

struct WorkspaceSnapshot: Equatable, Sendable {
    let workspaces: [WorkspaceSummary]
    let pages: [PageSummary]
    let blocks: [BlockSnapshot]
    let selectedWorkspaceID: String?
    let selectedPageID: String?
}

extension WorkspaceSnapshot {
    static let empty = WorkspaceSnapshot(
        workspaces: [],
        pages: [],
        blocks: [],
        selectedWorkspaceID: nil,
        selectedPageID: nil
    )
}

