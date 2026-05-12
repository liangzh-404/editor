import Foundation
import UniformTypeIdentifiers

struct WorkspaceSummary: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
}

struct NotebookSummary: Identifiable, Equatable, Sendable {
    let id: String
    let workspaceID: String
    let parentNotebookID: String?
    let name: String

    init(id: String, workspaceID: String, parentNotebookID: String? = nil, name: String) {
        self.id = id
        self.workspaceID = workspaceID
        self.parentNotebookID = parentNotebookID
        self.name = name
    }
}

struct PageSummary: Identifiable, Equatable, Sendable {
    let id: String
    let workspaceID: String
    let notebookID: String?
    let title: String

    init(id: String, workspaceID: String, notebookID: String? = nil, title: String) {
        self.id = id
        self.workspaceID = workspaceID
        self.notebookID = notebookID
        self.title = title
    }
}

enum BlockType: String, Equatable, Sendable {
    case paragraph
    case heading1
    case unorderedListItem
    case orderedListItem
    case taskItem
    case quote
    case codeBlock
    case table
    case callout
    case toggle
    case divider
    case pageReference
    case blockReference
    case attachmentImage
    case attachmentVideo
    case attachmentFile

    var isTextEditable: Bool {
        switch self {
        case .paragraph,
             .heading1,
             .unorderedListItem,
             .orderedListItem,
             .taskItem,
             .quote,
             .codeBlock,
             .table,
             .callout,
             .toggle:
            return true
        case .divider,
             .pageReference,
             .blockReference,
             .attachmentImage,
             .attachmentVideo,
             .attachmentFile:
            return false
        }
    }

    var supportsInlineMarkdownStyling: Bool {
        switch self {
        case .paragraph,
             .heading1,
             .unorderedListItem,
             .orderedListItem,
             .taskItem,
             .quote,
             .callout,
             .toggle:
            return true
        case .codeBlock,
             .table,
             .divider,
             .pageReference,
             .blockReference,
             .attachmentImage,
             .attachmentVideo,
             .attachmentFile:
            return false
        }
    }
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
    let taskItemIsCompleted: Bool
    let toggleIsExpanded: Bool
    let codeBlockLineWrapping: Bool
    let pageReferenceTargetPageID: String?
    let blockReferenceTargetBlockID: String?

    init(
        id: String,
        pageID: String,
        parentBlockID: String?,
        orderKey: String,
        type: BlockType,
        textPlain: String,
        taskItemIsCompleted: Bool = false,
        toggleIsExpanded: Bool = true,
        codeBlockLineWrapping: Bool = true,
        pageReferenceTargetPageID: String? = nil,
        blockReferenceTargetBlockID: String? = nil
    ) {
        self.id = id
        self.pageID = pageID
        self.parentBlockID = parentBlockID
        self.orderKey = orderKey
        self.type = type
        self.textPlain = textPlain
        self.taskItemIsCompleted = taskItemIsCompleted
        self.toggleIsExpanded = toggleIsExpanded
        self.codeBlockLineWrapping = codeBlockLineWrapping
        self.pageReferenceTargetPageID = pageReferenceTargetPageID
        self.blockReferenceTargetBlockID = blockReferenceTargetBlockID
    }

    func replacingText(_ text: String) -> BlockSnapshot {
        replacing(type: type, text: text)
    }

    func replacing(type: BlockType, text: String) -> BlockSnapshot {
        BlockSnapshot(
            id: id,
            pageID: pageID,
            parentBlockID: parentBlockID,
            orderKey: orderKey,
            type: type,
            textPlain: text,
            taskItemIsCompleted: type == .taskItem && self.type == .taskItem ? taskItemIsCompleted : false,
            toggleIsExpanded: type == .toggle && self.type == .toggle ? toggleIsExpanded : true,
            codeBlockLineWrapping: type == .codeBlock && self.type == .codeBlock ? codeBlockLineWrapping : true,
            pageReferenceTargetPageID: type == .pageReference || type == .blockReference ? pageReferenceTargetPageID : nil,
            blockReferenceTargetBlockID: type == .blockReference ? blockReferenceTargetBlockID : nil
        )
    }

    func replacingTaskItemCompletion(_ isCompleted: Bool) -> BlockSnapshot {
        BlockSnapshot(
            id: id,
            pageID: pageID,
            parentBlockID: parentBlockID,
            orderKey: orderKey,
            type: type,
            textPlain: textPlain,
            taskItemIsCompleted: type == .taskItem ? isCompleted : false,
            toggleIsExpanded: toggleIsExpanded,
            codeBlockLineWrapping: codeBlockLineWrapping,
            pageReferenceTargetPageID: pageReferenceTargetPageID,
            blockReferenceTargetBlockID: blockReferenceTargetBlockID
        )
    }

    func replacingToggleExpansion(_ isExpanded: Bool) -> BlockSnapshot {
        BlockSnapshot(
            id: id,
            pageID: pageID,
            parentBlockID: parentBlockID,
            orderKey: orderKey,
            type: type,
            textPlain: textPlain,
            taskItemIsCompleted: taskItemIsCompleted,
            toggleIsExpanded: type == .toggle ? isExpanded : true,
            codeBlockLineWrapping: codeBlockLineWrapping,
            pageReferenceTargetPageID: pageReferenceTargetPageID,
            blockReferenceTargetBlockID: blockReferenceTargetBlockID
        )
    }

    func replacingCodeBlockLineWrapping(_ isWrapped: Bool) -> BlockSnapshot {
        BlockSnapshot(
            id: id,
            pageID: pageID,
            parentBlockID: parentBlockID,
            orderKey: orderKey,
            type: type,
            textPlain: textPlain,
            taskItemIsCompleted: taskItemIsCompleted,
            toggleIsExpanded: toggleIsExpanded,
            codeBlockLineWrapping: type == .codeBlock ? isWrapped : true,
            pageReferenceTargetPageID: pageReferenceTargetPageID,
            blockReferenceTargetBlockID: blockReferenceTargetBlockID
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

    func matches(block: BlockSnapshot) -> Bool {
        block.type == kind.blockType && block.textPlain == originalFilename
    }

    func previewPath(for block: BlockSnapshot) -> String? {
        guard matches(block: block) else {
            return nil
        }

        switch kind {
        case .image, .video:
            return thumbnailPath ?? localPath
        case .file:
            return nil
        }
    }
}

struct WorkspaceSnapshot: Equatable, Sendable {
    let workspaces: [WorkspaceSummary]
    let notebooks: [NotebookSummary]
    let pages: [PageSummary]
    let archivedPages: [PageSummary]
    let blocks: [BlockSnapshot]
    let attachments: [AttachmentSnapshot]
    let selectedWorkspaceID: String?
    let selectedNotebookID: String?
    let selectedPageID: String?

    init(
        workspaces: [WorkspaceSummary],
        notebooks: [NotebookSummary] = [],
        pages: [PageSummary],
        archivedPages: [PageSummary] = [],
        blocks: [BlockSnapshot],
        attachments: [AttachmentSnapshot],
        selectedWorkspaceID: String?,
        selectedNotebookID: String? = nil,
        selectedPageID: String?
    ) {
        self.workspaces = workspaces
        self.notebooks = notebooks
        self.pages = pages
        self.archivedPages = archivedPages
        self.blocks = blocks
        self.attachments = attachments
        self.selectedWorkspaceID = selectedWorkspaceID
        self.selectedNotebookID = selectedNotebookID
        self.selectedPageID = selectedPageID
    }
}

extension WorkspaceSnapshot {
    static let empty = WorkspaceSnapshot(
        workspaces: [],
        notebooks: [],
        pages: [],
        archivedPages: [],
        blocks: [],
        attachments: [],
        selectedWorkspaceID: nil,
        selectedNotebookID: nil,
        selectedPageID: nil
    )

    func replacingBlock(blockID: String, type: BlockType, text: String) -> WorkspaceSnapshot {
        WorkspaceSnapshot(
            workspaces: workspaces,
            notebooks: notebooks,
            pages: pages,
            archivedPages: archivedPages,
            blocks: blocks.map { block in
                block.id == blockID ? block.replacing(type: type, text: text) : block
            },
            attachments: attachments,
            selectedWorkspaceID: selectedWorkspaceID,
            selectedNotebookID: selectedNotebookID,
            selectedPageID: selectedPageID
        )
    }

    func replacingBlockText(blockID: String, text: String) -> WorkspaceSnapshot {
        guard let block = blocks.first(where: { $0.id == blockID }) else {
            return self
        }

        return replacingBlock(blockID: blockID, type: block.type, text: text)
    }

    func replacingTaskItemCompletion(blockID: String, isCompleted: Bool) -> WorkspaceSnapshot {
        WorkspaceSnapshot(
            workspaces: workspaces,
            notebooks: notebooks,
            pages: pages,
            archivedPages: archivedPages,
            blocks: blocks.map { block in
                block.id == blockID ? block.replacingTaskItemCompletion(isCompleted) : block
            },
            attachments: attachments,
            selectedWorkspaceID: selectedWorkspaceID,
            selectedNotebookID: selectedNotebookID,
            selectedPageID: selectedPageID
        )
    }

    func replacingToggleExpansion(blockID: String, isExpanded: Bool) -> WorkspaceSnapshot {
        WorkspaceSnapshot(
            workspaces: workspaces,
            notebooks: notebooks,
            pages: pages,
            archivedPages: archivedPages,
            blocks: blocks.map { block in
                block.id == blockID ? block.replacingToggleExpansion(isExpanded) : block
            },
            attachments: attachments,
            selectedWorkspaceID: selectedWorkspaceID,
            selectedNotebookID: selectedNotebookID,
            selectedPageID: selectedPageID
        )
    }

    func replacingCodeBlockLineWrapping(blockID: String, isWrapped: Bool) -> WorkspaceSnapshot {
        WorkspaceSnapshot(
            workspaces: workspaces,
            notebooks: notebooks,
            pages: pages,
            archivedPages: archivedPages,
            blocks: blocks.map { block in
                block.id == blockID ? block.replacingCodeBlockLineWrapping(isWrapped) : block
            },
            attachments: attachments,
            selectedWorkspaceID: selectedWorkspaceID,
            selectedNotebookID: selectedNotebookID,
            selectedPageID: selectedPageID
        )
    }

    func replacingPageTitle(pageID: String, title: String) -> WorkspaceSnapshot {
        WorkspaceSnapshot(
            workspaces: workspaces,
            notebooks: notebooks,
            pages: pages.map { page in
                page.id == pageID
                    ? PageSummary(
                        id: page.id,
                        workspaceID: page.workspaceID,
                        notebookID: page.notebookID,
                        title: title
                    )
                    : page
            },
            archivedPages: archivedPages,
            blocks: blocks,
            attachments: attachments,
            selectedWorkspaceID: selectedWorkspaceID,
            selectedNotebookID: selectedNotebookID,
            selectedPageID: selectedPageID
        )
    }

    func replacingNotebookName(notebookID: String, name: String) -> WorkspaceSnapshot {
        WorkspaceSnapshot(
            workspaces: workspaces,
            notebooks: notebooks.map { notebook in
                notebook.id == notebookID
                    ? NotebookSummary(
                        id: notebook.id,
                        workspaceID: notebook.workspaceID,
                        parentNotebookID: notebook.parentNotebookID,
                        name: name
                    )
                    : notebook
            },
            pages: pages,
            archivedPages: archivedPages,
            blocks: blocks,
            attachments: attachments,
            selectedWorkspaceID: selectedWorkspaceID,
            selectedNotebookID: selectedNotebookID,
            selectedPageID: selectedPageID
        )
    }
}
