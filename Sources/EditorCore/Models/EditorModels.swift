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
    let isFavorite: Bool
    let isPinned: Bool
    let isEncrypted: Bool
    let createdAt: String?
    let updatedAt: String?

    init(
        id: String,
        workspaceID: String,
        notebookID: String? = nil,
        title: String,
        isFavorite: Bool = false,
        isPinned: Bool = false,
        isEncrypted: Bool = false,
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.workspaceID = workspaceID
        self.notebookID = notebookID
        self.title = title
        self.isFavorite = isFavorite
        self.isPinned = isPinned
        self.isEncrypted = isEncrypted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct TagSummary: Identifiable, Equatable, Sendable {
    let id: String
    let workspaceID: String
    let parentTagID: String?
    let name: String
    let path: String
}

struct PageTagAssignment: Equatable, Sendable {
    let pageID: String
    let tagID: String
}

struct DiaryEntrySnapshot: Identifiable, Equatable, Sendable {
    let id: String
    let workspaceID: String
    let textPlain: String
}

struct DiaryPageSnapshot: Equatable, Sendable {
    let pageID: String
    let workspaceID: String
    let diaryDate: String
}

enum DiaryTitleClassificationPolicy {
    private static let chineseTitlePattern = #"^\s*(\d{4})年(\d{1,2})月(\d{1,2})日\s+(?:星期)?([一二三四五六日天]|Sunday|Monday|Tuesday|Wednesday|Thursday|Friday|Saturday)(?:\s+\d+)?\s*$"#
    private static let isoTitlePattern = #"^\s*(\d{4})[-/](\d{1,2})[-/](\d{1,2})(?:\s+(?:星期)?([一二三四五六日天]|Sunday|Monday|Tuesday|Wednesday|Thursday|Friday|Saturday))?(?:\s+\d+)?\s*$"#

    static func diaryDateString(forPageTitle title: String) -> String? {
        if let chineseDate = diaryDateString(matching: chineseTitlePattern, in: title, requiresWeekday: true) {
            return chineseDate
        }
        return diaryDateString(matching: isoTitlePattern, in: title, requiresWeekday: false)
    }

    private static func diaryDateString(
        matching pattern: String,
        in title: String,
        requiresWeekday: Bool
    ) -> String? {
        let titleRegex = try! NSRegularExpression(pattern: pattern)
        let fullRange = NSRange(title.startIndex..<title.endIndex, in: title)
        guard let match = titleRegex.firstMatch(in: title, range: fullRange),
              match.numberOfRanges == 5,
              let year = Int(capture(1, in: title, match: match) ?? ""),
              let month = Int(capture(2, in: title, match: match) ?? ""),
              let day = Int(capture(3, in: title, match: match) ?? "") else {
            return nil
        }
        let weekdaySymbol = capture(4, in: title, match: match)
        if requiresWeekday, weekdaySymbol == nil {
            return nil
        }
        let expectedWeekday = weekdaySymbol.flatMap(weekdayNumber(for:))
        if weekdaySymbol != nil, expectedWeekday == nil {
            return nil
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day
        )
        guard let date = calendar.date(from: components) else {
            return nil
        }

        let resolved = calendar.dateComponents([.year, .month, .day, .weekday], from: date)
        guard resolved.year == year,
              resolved.month == month,
              resolved.day == day else {
            return nil
        }
        if let expectedWeekday, resolved.weekday != expectedWeekday {
            return nil
        }

        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private static func capture(_ index: Int, in string: String, match: NSTextCheckingResult) -> String? {
        guard index < match.numberOfRanges else {
            return nil
        }
        let nsRange = match.range(at: index)
        guard nsRange.location != NSNotFound,
              let range = Range(nsRange, in: string) else {
            return nil
        }
        return String(string[range])
    }

    private static func weekdayNumber(for symbol: String) -> Int? {
        switch symbol.lowercased() {
        case "日", "天":
            return 1
        case "一", "monday":
            return 2
        case "二", "tuesday":
            return 3
        case "三", "wednesday":
            return 4
        case "四", "thursday":
            return 5
        case "五", "friday":
            return 6
        case "六", "saturday":
            return 7
        case "sunday":
            return 1
        default:
            return nil
        }
    }
}

struct PageParentLink: Equatable, Sendable {
    let parentPageID: String
    let childPageID: String
    let sourceBlockID: String
    let orderKey: String
}

enum BlockType: String, Equatable, Sendable {
    case paragraph
    case heading1
    case heading2
    case heading3
    case heading4
    case heading5
    case heading6
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
    case drawing

    var isTextEditable: Bool {
        switch self {
        case .paragraph,
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
             .table,
             .callout,
             .toggle:
            return true
        case .divider,
             .pageReference,
             .blockReference,
             .attachmentImage,
             .attachmentVideo,
             .attachmentFile,
             .drawing:
            return false
        }
    }

    var supportsInlineMarkdownStyling: Bool {
        switch self {
        case .paragraph,
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
             .attachmentFile,
             .drawing:
            return false
        }
    }

    var isHeading: Bool {
        switch self {
        case .heading1,
             .heading2,
             .heading3,
             .heading4,
             .heading5,
             .heading6:
            return true
        default:
            return false
        }
    }
}

enum AttachmentKind: String, Equatable, Sendable {
    case image
    case video
    case file
    case drawing

    static let drawingUTIType = "com.apple.drawing"

    init(utiType: String) {
        if utiType == Self.drawingUTIType {
            self = .drawing
            return
        }

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
        case .drawing:
            return .drawing
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
    let tableRows: [[String]]
    let attachmentID: String?
    let attachmentDisplayWidth: Double?

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
        blockReferenceTargetBlockID: String? = nil,
        tableRows: [[String]] = [],
        attachmentID: String? = nil,
        attachmentDisplayWidth: Double? = nil
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
        self.tableRows = Self.normalizedTableRows(type: type, text: textPlain, rows: tableRows)
        self.attachmentID = type.isAttachment ? attachmentID : nil
        self.attachmentDisplayWidth = type == .attachmentImage ? attachmentDisplayWidth : nil
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
            pageReferenceTargetPageID: pageReferenceTargetPageID,
            blockReferenceTargetBlockID: type == .blockReference ? blockReferenceTargetBlockID : nil,
            tableRows: type == .table && self.type == .table ? tableRows : [],
            attachmentID: type.isAttachment && type == self.type ? attachmentID : nil,
            attachmentDisplayWidth: type == .attachmentImage && type == self.type ? attachmentDisplayWidth : nil
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
            blockReferenceTargetBlockID: blockReferenceTargetBlockID,
            tableRows: tableRows,
            attachmentID: attachmentID,
            attachmentDisplayWidth: attachmentDisplayWidth
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
            blockReferenceTargetBlockID: blockReferenceTargetBlockID,
            tableRows: tableRows,
            attachmentID: attachmentID,
            attachmentDisplayWidth: attachmentDisplayWidth
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
            blockReferenceTargetBlockID: blockReferenceTargetBlockID,
            tableRows: tableRows,
            attachmentID: attachmentID,
            attachmentDisplayWidth: attachmentDisplayWidth
        )
    }

    func replacingTableRows(_ rows: [[String]], text: String) -> BlockSnapshot {
        BlockSnapshot(
            id: id,
            pageID: pageID,
            parentBlockID: parentBlockID,
            orderKey: orderKey,
            type: type,
            textPlain: text,
            taskItemIsCompleted: taskItemIsCompleted,
            toggleIsExpanded: toggleIsExpanded,
            codeBlockLineWrapping: codeBlockLineWrapping,
            pageReferenceTargetPageID: pageReferenceTargetPageID,
            blockReferenceTargetBlockID: blockReferenceTargetBlockID,
            tableRows: type == .table ? rows : [],
            attachmentID: attachmentID,
            attachmentDisplayWidth: attachmentDisplayWidth
        )
    }

    func replacingAttachmentDisplayWidth(_ displayWidth: Double?) -> BlockSnapshot {
        BlockSnapshot(
            id: id,
            pageID: pageID,
            parentBlockID: parentBlockID,
            orderKey: orderKey,
            type: type,
            textPlain: textPlain,
            taskItemIsCompleted: taskItemIsCompleted,
            toggleIsExpanded: toggleIsExpanded,
            codeBlockLineWrapping: codeBlockLineWrapping,
            pageReferenceTargetPageID: pageReferenceTargetPageID,
            blockReferenceTargetBlockID: blockReferenceTargetBlockID,
            tableRows: tableRows,
            attachmentID: attachmentID,
            attachmentDisplayWidth: displayWidth
        )
    }

    private static func normalizedTableRows(type: BlockType, text: String, rows: [[String]]) -> [[String]] {
        guard type == .table else {
            return []
        }

        if !rows.isEmpty {
            return MarkdownTableDocument(rows: rows).rows
        }

        let parsedRows = MarkdownTableDocument(markdown: text).rows
        if !parsedRows.isEmpty {
            return parsedRows
        }

        return MarkdownTableDocument.defaultGridRows(firstCellText: text)
    }
}

private extension BlockType {
    var isAttachment: Bool {
        switch self {
        case .attachmentImage, .attachmentVideo, .attachmentFile, .drawing:
            return true
        default:
            return false
        }
    }
}

enum AttachmentPreviewState: Equatable, Sendable {
    case thumbnail(String)
    case pending
    case unavailable
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
        if let attachmentID = block.attachmentID {
            return id == attachmentID && block.type == kind.blockType
        }

        return block.type == kind.blockType && block.textPlain == originalFilename
    }

    func previewPath(for block: BlockSnapshot) -> String? {
        previewCandidatePaths(for: block).first
    }

    func previewCandidatePaths(for block: BlockSnapshot) -> [String] {
        guard matches(block: block) else {
            return []
        }

        switch kind {
        case .image:
            var paths: [String] = []
            if !localPath.isEmpty, !paths.contains(localPath) {
                paths.append(localPath)
            }
            if let thumbnailPath, !paths.contains(thumbnailPath) {
                paths.append(thumbnailPath)
            }
            return paths
        case .video:
            if let thumbnailPath {
                return [thumbnailPath]
            }
            return []
        case .file:
            return []
        case .drawing:
            return localPath.isEmpty ? [] : [localPath]
        }
    }

    func previewState(for block: BlockSnapshot) -> AttachmentPreviewState {
        guard matches(block: block) else {
            return .unavailable
        }

        switch kind {
        case .image:
            return localPath.isEmpty ? .pending : .thumbnail(localPath)
        case .video:
            if let thumbnailPath {
                return .thumbnail(thumbnailPath)
            }
            return .pending
        case .file:
            return .unavailable
        case .drawing:
            return .unavailable
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
    let tags: [TagSummary]
    let pageTags: [PageTagAssignment]
    let activeDiaryEntry: DiaryEntrySnapshot?
    let diaryPages: [DiaryPageSnapshot]
    let emptyDiaryPageIDs: Set<String>
    let pageParentLinks: [PageParentLink]
    let selectedWorkspaceID: String?
    let selectedNotebookID: String?
    let selectedPageID: String?

    var favoritePages: [PageSummary] {
        pages.filter(\.isFavorite)
    }

    var diaryPagesIncludingInferredTitles: [DiaryPageSnapshot] {
        let explicitPageIDs = Set(diaryPages.map(\.pageID))
        let inferredPages = pages.compactMap { page -> DiaryPageSnapshot? in
            guard !explicitPageIDs.contains(page.id),
                  let diaryDate = DiaryTitleClassificationPolicy.diaryDateString(forPageTitle: page.title) else {
                return nil
            }
            return DiaryPageSnapshot(pageID: page.id, workspaceID: page.workspaceID, diaryDate: diaryDate)
        }
        return diaryPages + inferredPages
    }

    var diaryDateByPageID: [String: String] {
        Dictionary(uniqueKeysWithValues: diaryPagesIncludingInferredTitles.map { ($0.pageID, $0.diaryDate) })
    }

    var diaryPageIDs: Set<String> {
        Set(diaryPagesIncludingInferredTitles.map(\.pageID))
    }

    var visibleDiaryPageIDs: Set<String> {
        diaryPageIDs.subtracting(emptyDiaryPageIDs)
    }

    func isEmptyDiaryPage(_ pageID: String) -> Bool {
        emptyDiaryPageIDs.contains(pageID)
    }

    init(
        workspaces: [WorkspaceSummary],
        notebooks: [NotebookSummary] = [],
        pages: [PageSummary],
        archivedPages: [PageSummary] = [],
        blocks: [BlockSnapshot],
        attachments: [AttachmentSnapshot],
        tags: [TagSummary] = [],
        pageTags: [PageTagAssignment] = [],
        activeDiaryEntry: DiaryEntrySnapshot? = nil,
        diaryPages: [DiaryPageSnapshot] = [],
        emptyDiaryPageIDs: Set<String> = [],
        pageParentLinks: [PageParentLink] = [],
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
        self.tags = tags
        self.pageTags = pageTags
        self.activeDiaryEntry = activeDiaryEntry
        self.diaryPages = diaryPages
        self.emptyDiaryPageIDs = emptyDiaryPageIDs
        self.pageParentLinks = pageParentLinks
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

    func replacingBlocks(pageID: String, blocks replacementBlocks: [BlockSnapshot]) -> WorkspaceSnapshot {
        WorkspaceSnapshot(
            workspaces: workspaces,
            notebooks: notebooks,
            pages: pages,
            archivedPages: archivedPages,
            blocks: blocks.filter { $0.pageID != pageID } + replacementBlocks,
            attachments: attachments,
            tags: tags,
            pageTags: pageTags,
            activeDiaryEntry: activeDiaryEntry,
            diaryPages: diaryPages,
            emptyDiaryPageIDs: emptyDiaryPageIDs,
            pageParentLinks: pageParentLinks,
            selectedWorkspaceID: selectedWorkspaceID,
            selectedNotebookID: selectedNotebookID,
            selectedPageID: selectedPageID
        )
    }

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
            tags: tags,
            pageTags: pageTags,
            activeDiaryEntry: activeDiaryEntry,
            diaryPages: diaryPages,
            emptyDiaryPageIDs: emptyDiaryPageIDs,
            pageParentLinks: pageParentLinks,
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

    func replacingTableRows(blockID: String, rows: [[String]], text: String) -> WorkspaceSnapshot {
        WorkspaceSnapshot(
            workspaces: workspaces,
            notebooks: notebooks,
            pages: pages,
            archivedPages: archivedPages,
            blocks: blocks.map { block in
                block.id == blockID ? block.replacingTableRows(rows, text: text) : block
            },
            attachments: attachments,
            tags: tags,
            pageTags: pageTags,
            activeDiaryEntry: activeDiaryEntry,
            diaryPages: diaryPages,
            emptyDiaryPageIDs: emptyDiaryPageIDs,
            pageParentLinks: pageParentLinks,
            selectedWorkspaceID: selectedWorkspaceID,
            selectedNotebookID: selectedNotebookID,
            selectedPageID: selectedPageID
        )
    }

    func replacingAttachmentDisplayWidth(blockID: String, displayWidth: Double?) -> WorkspaceSnapshot {
        WorkspaceSnapshot(
            workspaces: workspaces,
            notebooks: notebooks,
            pages: pages,
            archivedPages: archivedPages,
            blocks: blocks.map { block in
                block.id == blockID ? block.replacingAttachmentDisplayWidth(displayWidth) : block
            },
            attachments: attachments,
            tags: tags,
            pageTags: pageTags,
            activeDiaryEntry: activeDiaryEntry,
            diaryPages: diaryPages,
            emptyDiaryPageIDs: emptyDiaryPageIDs,
            pageParentLinks: pageParentLinks,
            selectedWorkspaceID: selectedWorkspaceID,
            selectedNotebookID: selectedNotebookID,
            selectedPageID: selectedPageID
        )
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
            tags: tags,
            pageTags: pageTags,
            activeDiaryEntry: activeDiaryEntry,
            diaryPages: diaryPages,
            emptyDiaryPageIDs: emptyDiaryPageIDs,
            pageParentLinks: pageParentLinks,
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
            tags: tags,
            pageTags: pageTags,
            activeDiaryEntry: activeDiaryEntry,
            diaryPages: diaryPages,
            emptyDiaryPageIDs: emptyDiaryPageIDs,
            pageParentLinks: pageParentLinks,
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
            tags: tags,
            pageTags: pageTags,
            activeDiaryEntry: activeDiaryEntry,
            diaryPages: diaryPages,
            emptyDiaryPageIDs: emptyDiaryPageIDs,
            pageParentLinks: pageParentLinks,
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
                        title: title,
                        isFavorite: page.isFavorite,
                        isPinned: page.isPinned,
                        isEncrypted: page.isEncrypted,
                        createdAt: page.createdAt,
                        updatedAt: page.updatedAt
                    )
                    : page
            },
            archivedPages: archivedPages,
            blocks: blocks,
            attachments: attachments,
            tags: tags,
            pageTags: pageTags,
            activeDiaryEntry: activeDiaryEntry,
            diaryPages: diaryPages,
            emptyDiaryPageIDs: emptyDiaryPageIDs,
            pageParentLinks: pageParentLinks,
            selectedWorkspaceID: selectedWorkspaceID,
            selectedNotebookID: selectedNotebookID,
            selectedPageID: selectedPageID
        )
    }

    func replacingPageFavorite(pageID: String, isFavorite: Bool) -> WorkspaceSnapshot {
        WorkspaceSnapshot(
            workspaces: workspaces,
            notebooks: notebooks,
            pages: pages.map { page in
                page.id == pageID
                    ? PageSummary(
                        id: page.id,
                        workspaceID: page.workspaceID,
                        notebookID: page.notebookID,
                        title: page.title,
                        isFavorite: isFavorite,
                        isPinned: page.isPinned,
                        isEncrypted: page.isEncrypted,
                        createdAt: page.createdAt,
                        updatedAt: page.updatedAt
                    )
                    : page
            },
            archivedPages: archivedPages.map { page in
                page.id == pageID
                    ? PageSummary(
                        id: page.id,
                        workspaceID: page.workspaceID,
                        notebookID: page.notebookID,
                        title: page.title,
                        isFavorite: isFavorite,
                        isPinned: page.isPinned,
                        isEncrypted: page.isEncrypted,
                        createdAt: page.createdAt,
                        updatedAt: page.updatedAt
                    )
                    : page
            },
            blocks: blocks,
            attachments: attachments,
            tags: tags,
            pageTags: pageTags,
            activeDiaryEntry: activeDiaryEntry,
            diaryPages: diaryPages,
            emptyDiaryPageIDs: emptyDiaryPageIDs,
            pageParentLinks: pageParentLinks,
            selectedWorkspaceID: selectedWorkspaceID,
            selectedNotebookID: selectedNotebookID,
            selectedPageID: selectedPageID
        )
    }

    func replacingPagePinned(pageID: String, isPinned: Bool) -> WorkspaceSnapshot {
        WorkspaceSnapshot(
            workspaces: workspaces,
            notebooks: notebooks,
            pages: pages.map { page in
                page.id == pageID
                    ? PageSummary(
                        id: page.id,
                        workspaceID: page.workspaceID,
                        notebookID: page.notebookID,
                        title: page.title,
                        isFavorite: page.isFavorite,
                        isPinned: isPinned,
                        isEncrypted: page.isEncrypted,
                        createdAt: page.createdAt,
                        updatedAt: page.updatedAt
                    )
                    : page
            },
            archivedPages: archivedPages.map { page in
                page.id == pageID
                    ? PageSummary(
                        id: page.id,
                        workspaceID: page.workspaceID,
                        notebookID: page.notebookID,
                        title: page.title,
                        isFavorite: page.isFavorite,
                        isPinned: isPinned,
                        isEncrypted: page.isEncrypted,
                        createdAt: page.createdAt,
                        updatedAt: page.updatedAt
                    )
                    : page
            },
            blocks: blocks,
            attachments: attachments,
            tags: tags,
            pageTags: pageTags,
            activeDiaryEntry: activeDiaryEntry,
            diaryPages: diaryPages,
            emptyDiaryPageIDs: emptyDiaryPageIDs,
            pageParentLinks: pageParentLinks,
            selectedWorkspaceID: selectedWorkspaceID,
            selectedNotebookID: selectedNotebookID,
            selectedPageID: selectedPageID
        )
    }

    func replacingPageEncryption(pageID: String, isEncrypted: Bool) -> WorkspaceSnapshot {
        WorkspaceSnapshot(
            workspaces: workspaces,
            notebooks: notebooks,
            pages: pages.map { page in
                page.id == pageID
                    ? PageSummary(
                        id: page.id,
                        workspaceID: page.workspaceID,
                        notebookID: page.notebookID,
                        title: page.title,
                        isFavorite: page.isFavorite,
                        isPinned: page.isPinned,
                        isEncrypted: isEncrypted,
                        createdAt: page.createdAt,
                        updatedAt: page.updatedAt
                    )
                    : page
            },
            archivedPages: archivedPages.map { page in
                page.id == pageID
                    ? PageSummary(
                        id: page.id,
                        workspaceID: page.workspaceID,
                        notebookID: page.notebookID,
                        title: page.title,
                        isFavorite: page.isFavorite,
                        isPinned: page.isPinned,
                        isEncrypted: isEncrypted,
                        createdAt: page.createdAt,
                        updatedAt: page.updatedAt
                    )
                    : page
            },
            blocks: blocks,
            attachments: attachments,
            tags: tags,
            pageTags: pageTags,
            activeDiaryEntry: activeDiaryEntry,
            diaryPages: diaryPages,
            emptyDiaryPageIDs: emptyDiaryPageIDs,
            pageParentLinks: pageParentLinks,
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
            tags: tags,
            pageTags: pageTags,
            activeDiaryEntry: activeDiaryEntry,
            diaryPages: diaryPages,
            emptyDiaryPageIDs: emptyDiaryPageIDs,
            pageParentLinks: pageParentLinks,
            selectedWorkspaceID: selectedWorkspaceID,
            selectedNotebookID: selectedNotebookID,
            selectedPageID: selectedPageID
        )
    }
}
