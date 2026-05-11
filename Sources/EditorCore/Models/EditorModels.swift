import Foundation
import UniformTypeIdentifiers

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
    case attachmentImage
    case attachmentVideo
    case attachmentFile
}

enum AttachmentKind: String, Equatable, Sendable {
    case image
    case video
    case file

    init(utiType: String) {
        guard let type = UTType(utiType) else {
            self = .file
            return
        }

        if type.conforms(to: .image) {
            self = .image
        } else if type.conforms(to: .movie) || type.conforms(to: .video) {
            self = .video
        } else {
            self = .file
        }
    }

    var blockType: BlockType {
        switch self {
        case .image:
            return .attachmentImage
        case .video:
            return .attachmentVideo
        case .file:
            return .attachmentFile
        }
    }
}

struct BlockSnapshot: Identifiable, Equatable, Sendable {
    let id: String
    let pageID: String
    let parentBlockID: String?
    let orderKey: String
    let type: BlockType
    let textPlain: String

    func replacingText(_ text: String) -> BlockSnapshot {
        BlockSnapshot(
            id: id,
            pageID: pageID,
            parentBlockID: parentBlockID,
            orderKey: orderKey,
            type: type,
            textPlain: text
        )
    }
}

struct AttachmentSnapshot: Identifiable, Equatable, Sendable {
    let id: String
    let workspaceID: String
    let originalFilename: String
    let utiType: String
    let byteSize: Int
    let contentHash: String
    let localPath: String
    let thumbnailPath: String?
    let kind: AttachmentKind
}

struct WorkspaceSnapshot: Equatable, Sendable {
    let workspaces: [WorkspaceSummary]
    let pages: [PageSummary]
    let blocks: [BlockSnapshot]
    let attachments: [AttachmentSnapshot]
    let selectedWorkspaceID: String?
    let selectedPageID: String?
}

extension WorkspaceSnapshot {
    static let empty = WorkspaceSnapshot(
        workspaces: [],
        pages: [],
        blocks: [],
        attachments: [],
        selectedWorkspaceID: nil,
        selectedPageID: nil
    )

    func replacingBlockText(blockID: String, text: String) -> WorkspaceSnapshot {
        WorkspaceSnapshot(
            workspaces: workspaces,
            pages: pages,
            blocks: blocks.map { block in
                block.id == blockID ? block.replacingText(text) : block
            },
            attachments: attachments,
            selectedWorkspaceID: selectedWorkspaceID,
            selectedPageID: selectedPageID
        )
    }
}
