import Foundation
import CloudKit

struct CloudKitUploadResult: Equatable, Sendable {
    let recordName: String
    let changeTag: String?
}

protocol CloudKitSyncAdapter {
    func upload(change: SyncChange) throws -> CloudKitUploadResult
}

protocol CloudKitRemoteChangeFetching {
    func fetchRemoteChanges(
        sinceServerChangeTokenData serverChangeTokenData: Data?
    ) throws -> CloudKitRemoteChangeSet
}

struct CloudKitRemoteChangeSet: Equatable, Sendable {
    let workspaceChanges: [RemoteWorkspaceChange]
    let notebookChanges: [RemoteNotebookChange]
    let pageChanges: [RemotePageChange]
    let attachmentChanges: [RemoteAttachmentChange]
    let blockChanges: [RemoteBlockChange]
    let deletedRecords: [RemoteDeletedRecord]
    let serverChangeTokenData: Data?

    init(
        workspaceChanges: [RemoteWorkspaceChange] = [],
        notebookChanges: [RemoteNotebookChange] = [],
        pageChanges: [RemotePageChange] = [],
        attachmentChanges: [RemoteAttachmentChange] = [],
        blockChanges: [RemoteBlockChange] = [],
        deletedRecords: [RemoteDeletedRecord] = [],
        serverChangeTokenData: Data? = nil
    ) {
        self.workspaceChanges = workspaceChanges
        self.notebookChanges = notebookChanges
        self.pageChanges = pageChanges
        self.attachmentChanges = attachmentChanges
        self.blockChanges = blockChanges
        self.deletedRecords = deletedRecords
        self.serverChangeTokenData = serverChangeTokenData
    }
}

protocol CloudKitRecordSaving {
    func save(record: CKRecord) throws -> CKRecord
}

protocol CloudKitRecordFetching {
    func fetchRecords(recordType: String) throws -> [CKRecord]
    func fetchRecordChanges(
        sinceServerChangeTokenData serverChangeTokenData: Data?
    ) throws -> CloudKitFetchedRecordChangeSet
}

struct CloudKitFetchedRecordChangeSet: Equatable {
    let recordsByType: [String: [CKRecord]]
    let deletedRecordIDsByType: [String: [CKRecord.ID]]
    let serverChangeTokenData: Data?

    init(
        recordsByType: [String: [CKRecord]],
        deletedRecordIDsByType: [String: [CKRecord.ID]] = [:],
        serverChangeTokenData: Data?
    ) {
        self.recordsByType = recordsByType
        self.deletedRecordIDsByType = deletedRecordIDsByType
        self.serverChangeTokenData = serverChangeTokenData
    }
}

enum CloudKitServerChangeTokenCodec {
    static func data(from token: CKServerChangeToken) throws -> Data {
        try NSKeyedArchiver.archivedData(
            withRootObject: token,
            requiringSecureCoding: true
        )
    }

    static func serverChangeToken(from data: Data?) throws -> CKServerChangeToken? {
        guard let data else {
            return nil
        }

        return try NSKeyedUnarchiver.unarchivedObject(
            ofClass: CKServerChangeToken.self,
            from: data
        )
    }
}

extension CloudKitRecordFetching {
    func fetchRecordChanges(
        sinceServerChangeTokenData serverChangeTokenData: Data?
    ) throws -> CloudKitFetchedRecordChangeSet {
        let recordsByType = try Dictionary(
            uniqueKeysWithValues: CloudKitPrivateDatabaseAdapter.recordTypes.map { recordType in
                (recordType, try fetchRecords(recordType: recordType))
            }
        )
        return CloudKitFetchedRecordChangeSet(
            recordsByType: recordsByType,
            deletedRecordIDsByType: [:],
            serverChangeTokenData: nil
        )
    }
}

final class LiveCloudKitRecordSaver: CloudKitRecordSaving {
    private let database: CKDatabase

    init(database: CKDatabase = CKContainer.default().privateCloudDatabase) {
        self.database = database
    }

    func save(record: CKRecord) throws -> CKRecord {
        let semaphore = DispatchSemaphore(value: 0)
        final class SaveBox: @unchecked Sendable {
            var result: Result<CKRecord, Error>?
        }
        let saveBox = SaveBox()

        database.save(record) { savedRecord, error in
            if let error {
                saveBox.result = .failure(error)
            } else if let savedRecord {
                saveBox.result = .success(savedRecord)
            } else {
                saveBox.result = .failure(CloudKitPrivateDatabaseAdapterError.missingSavedRecord)
            }
            semaphore.signal()
        }
        semaphore.wait()

        return try saveBox.result?.get() ?? {
            throw CloudKitPrivateDatabaseAdapterError.missingSavedRecord
        }()
    }
}

final class LiveCloudKitRecordFetcher: CloudKitRecordFetching {
    private let database: CKDatabase

    init(database: CKDatabase = CKContainer.default().privateCloudDatabase) {
        self.database = database
    }

    func fetchRecords(recordType: String) throws -> [CKRecord] {
        let semaphore = DispatchSemaphore(value: 0)
        final class FetchBox: @unchecked Sendable {
            var result: Result<[CKRecord], Error>?
        }
        let fetchBox = FetchBox()
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))

        database.fetch(withQuery: query, inZoneWith: nil) { result in
            switch result {
            case .success(let response):
                var records: [CKRecord] = []
                for (_, recordResult) in response.matchResults {
                    switch recordResult {
                    case .success(let record):
                        records.append(record)
                    case .failure(let error):
                        fetchBox.result = .failure(error)
                        semaphore.signal()
                        return
                    }
                }
                fetchBox.result = .success(records)
            case .failure(let error):
                fetchBox.result = .failure(error)
            }
            semaphore.signal()
        }
        semaphore.wait()

        return try fetchBox.result?.get() ?? []
    }

    func fetchRecordChanges(
        sinceServerChangeTokenData serverChangeTokenData: Data?
    ) throws -> CloudKitFetchedRecordChangeSet {
        let previousToken = try CloudKitServerChangeTokenCodec.serverChangeToken(
            from: serverChangeTokenData
        )
        let zoneID = CKRecordZone.default().zoneID
        let configuration = CKFetchRecordZoneChangesOperation.ZoneConfiguration(
            previousServerChangeToken: previousToken
        )
        let operation = CKFetchRecordZoneChangesOperation(
            recordZoneIDs: [zoneID],
            configurationsByRecordZoneID: [zoneID: configuration]
        )
        operation.fetchAllChanges = true

        let semaphore = DispatchSemaphore(value: 0)
        final class FetchBox: @unchecked Sendable {
            var records: [CKRecord] = []
            var deletedRecordIDsByType: [String: [CKRecord.ID]] = [:]
            var serverChangeTokenData: Data?
            var error: Error?
        }
        let fetchBox = FetchBox()

        operation.recordWasChangedBlock = { _, recordResult in
            switch recordResult {
            case .success(let record):
                fetchBox.records.append(record)
            case .failure(let error):
                fetchBox.error = error
            }
        }
        operation.recordWithIDWasDeletedBlock = { recordID, recordType in
            fetchBox.deletedRecordIDsByType[recordType, default: []].append(recordID)
        }
        operation.recordZoneFetchResultBlock = { _, result in
            switch result {
            case .success(let response):
                do {
                    fetchBox.serverChangeTokenData = try CloudKitServerChangeTokenCodec
                        .data(from: response.serverChangeToken)
                } catch {
                    fetchBox.error = error
                }
            case .failure(let error):
                fetchBox.error = error
            }
        }
        operation.fetchRecordZoneChangesResultBlock = { result in
            if case .failure(let error) = result {
                fetchBox.error = error
            }
            semaphore.signal()
        }

        database.add(operation)
        semaphore.wait()

        if let error = fetchBox.error {
            throw error
        }

        return CloudKitFetchedRecordChangeSet(
            recordsByType: Dictionary(grouping: fetchBox.records, by: \.recordType),
            deletedRecordIDsByType: fetchBox.deletedRecordIDsByType,
            serverChangeTokenData: fetchBox.serverChangeTokenData
        )
    }
}

final class CloudKitPrivateDatabaseAdapter: CloudKitSyncAdapter, CloudKitRemoteChangeFetching {
    static let recordTypes = [
        "WorkspaceRecord",
        "NotebookRecord",
        "PageRecord",
        "AttachmentRecord",
        "BlockRecord"
    ]

    private let database: SQLiteDatabase
    private let recordSaver: CloudKitRecordSaving?
    private let recordFetcher: CloudKitRecordFetching?
    private let attachmentDownloadDirectory: URL?
    private let fileManager: FileManager

    init(
        database: SQLiteDatabase,
        recordSaver: CloudKitRecordSaving? = nil,
        recordFetcher: CloudKitRecordFetching? = nil,
        attachmentDownloadDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.database = database
        self.recordSaver = recordSaver
        self.recordFetcher = recordFetcher
        self.attachmentDownloadDirectory = attachmentDownloadDirectory
        self.fileManager = fileManager
    }

    func upload(change: SyncChange) throws -> CloudKitUploadResult {
        let record = try record(for: change)
        let savedRecord = try (recordSaver ?? LiveCloudKitRecordSaver()).save(record: record)
        return CloudKitUploadResult(
            recordName: savedRecord.recordID.recordName,
            changeTag: savedRecord.recordChangeTag
        )
    }

    func fetchRemoteChanges(
        sinceServerChangeTokenData serverChangeTokenData: Data?
    ) throws -> CloudKitRemoteChangeSet {
        guard let recordFetcher else {
            throw CloudKitPrivateDatabaseAdapterError.remoteFetchUnavailable
        }
        let fetchedChanges = try recordFetcher.fetchRecordChanges(
            sinceServerChangeTokenData: serverChangeTokenData
        )
        let recordsByType = fetchedChanges.recordsByType
        let deletedRecords = Self.recordTypes.flatMap { recordType in
            (fetchedChanges.deletedRecordIDsByType[recordType] ?? []).compactMap { recordID in
                remoteDeletedRecord(recordType: recordType, recordID: recordID)
            }
        }

        return CloudKitRemoteChangeSet(
            workspaceChanges: (recordsByType["WorkspaceRecord"] ?? []).compactMap(remoteWorkspaceChange),
            notebookChanges: (recordsByType["NotebookRecord"] ?? []).compactMap(remoteNotebookChange),
            pageChanges: (recordsByType["PageRecord"] ?? []).compactMap(remotePageChange),
            attachmentChanges: try (recordsByType["AttachmentRecord"] ?? []).compactMap { record in
                try remoteAttachmentChange(record: record)
            },
            blockChanges: (recordsByType["BlockRecord"] ?? []).compactMap(remoteBlockChange),
            deletedRecords: deletedRecords,
            serverChangeTokenData: fetchedChanges.serverChangeTokenData
        )
    }

    private func record(for change: SyncChange) throws -> CKRecord {
        switch change.entityType {
        case "workspace":
            return try workspaceRecord(entityID: change.entityID)
        case "notebook":
            return try notebookRecord(entityID: change.entityID)
        case "page":
            return try pageRecord(entityID: change.entityID)
        case "block":
            return try blockRecord(entityID: change.entityID)
        case "attachment":
            return try attachmentRecord(entityID: change.entityID)
        default:
            throw CloudKitPrivateDatabaseAdapterError.unsupportedEntityType(change.entityType)
        }
    }

    private func workspaceRecord(entityID: String) throws -> CKRecord {
        let row = try requiredRow(
            """
            SELECT id, name, updated_at
            FROM workspaces
            WHERE id = ?
            LIMIT 1
            """,
            entityID: entityID
        )
        let record = makeRecord(type: "WorkspaceRecord", entityType: "workspace", entityID: entityID)
        record["name"] = row["name"] as CKRecordValue?
        record["updatedAt"] = row["updated_at"] as CKRecordValue?
        return record
    }

    private func notebookRecord(entityID: String) throws -> CKRecord {
        let row = try requiredRow(
            """
            SELECT id, workspace_id, name, order_key, updated_at
            FROM notebooks
            WHERE id = ?
            LIMIT 1
            """,
            entityID: entityID
        )
        let record = makeRecord(type: "NotebookRecord", entityType: "notebook", entityID: entityID)
        record["workspaceID"] = row["workspace_id"] as CKRecordValue?
        record["name"] = row["name"] as CKRecordValue?
        record["orderKey"] = row["order_key"] as CKRecordValue?
        record["updatedAt"] = row["updated_at"] as CKRecordValue?
        return record
    }

    private func pageRecord(entityID: String) throws -> CKRecord {
        let row = try requiredRow(
            """
            SELECT id, workspace_id, notebook_id, title, order_key, is_archived, updated_at
            FROM pages
            WHERE id = ?
            LIMIT 1
            """,
            entityID: entityID
        )
        let record = makeRecord(type: "PageRecord", entityType: "page", entityID: entityID)
        record["workspaceID"] = row["workspace_id"] as CKRecordValue?
        record["notebookID"] = row["notebook_id"] as CKRecordValue?
        record["title"] = row["title"] as CKRecordValue?
        record["orderKey"] = row["order_key"] as CKRecordValue?
        record["isArchived"] = NSNumber(value: Int(row["is_archived"] ?? "") ?? 0)
        record["updatedAt"] = row["updated_at"] as CKRecordValue?
        return record
    }

    private func blockRecord(entityID: String) throws -> CKRecord {
        let row = try requiredRow(
            """
            SELECT id,
                   page_id,
                   parent_block_id,
                   order_key,
                   type,
                   payload_json,
                   text_plain,
                   revision,
                   is_deleted,
                   updated_at
            FROM blocks
            WHERE id = ?
            LIMIT 1
            """,
            entityID: entityID
        )
        let record = makeRecord(type: "BlockRecord", entityType: "block", entityID: entityID)
        record["pageID"] = row["page_id"] as CKRecordValue?
        record["parentBlockID"] = row["parent_block_id"] as CKRecordValue?
        record["orderKey"] = row["order_key"] as CKRecordValue?
        record["type"] = row["type"] as CKRecordValue?
        record["payloadJSON"] = row["payload_json"] as CKRecordValue?
        record["textPlain"] = row["text_plain"] as CKRecordValue?
        record["revision"] = NSNumber(value: Int(row["revision"] ?? "") ?? 0)
        record["isDeleted"] = NSNumber(value: Int(row["is_deleted"] ?? "") ?? 0)
        record["updatedAt"] = row["updated_at"] as CKRecordValue?
        return record
    }

    private func attachmentRecord(entityID: String) throws -> CKRecord {
        let row = try requiredRow(
            """
            SELECT id,
                   workspace_id,
                   original_filename,
                   uti_type,
                   byte_size,
                   content_hash,
                   local_path,
                   thumbnail_path,
                   updated_at
            FROM attachments
            WHERE id = ?
            LIMIT 1
            """,
            entityID: entityID
        )
        let record = makeRecord(type: "AttachmentRecord", entityType: "attachment", entityID: entityID)
        record["workspaceID"] = row["workspace_id"] as CKRecordValue?
        record["originalFilename"] = row["original_filename"] as CKRecordValue?
        record["utiType"] = row["uti_type"] as CKRecordValue?
        record["byteSize"] = NSNumber(value: Int(row["byte_size"] ?? "") ?? 0)
        record["contentHash"] = row["content_hash"] as CKRecordValue?
        record["localPath"] = row["local_path"] as CKRecordValue?
        record["thumbnailPath"] = row["thumbnail_path"] as CKRecordValue?
        record["updatedAt"] = row["updated_at"] as CKRecordValue?

        if let localPath = row["local_path"] ?? nil,
           FileManager.default.fileExists(atPath: localPath) {
            record["asset"] = CKAsset(fileURL: URL(fileURLWithPath: localPath))
        }
        return record
    }

    private func remoteWorkspaceChange(record: CKRecord) -> RemoteWorkspaceChange? {
        guard let workspaceID = record["entityID"] as? String,
              let name = record["name"] as? String else {
            return nil
        }

        return RemoteWorkspaceChange(workspaceID: workspaceID, name: name)
    }

    private func remoteNotebookChange(record: CKRecord) -> RemoteNotebookChange? {
        guard let notebookID = record["entityID"] as? String,
              let workspaceID = record["workspaceID"] as? String,
              let name = record["name"] as? String,
              let orderKey = record["orderKey"] as? String else {
            return nil
        }

        return RemoteNotebookChange(
            notebookID: notebookID,
            workspaceID: workspaceID,
            name: name,
            orderKey: orderKey
        )
    }

    private func remotePageChange(record: CKRecord) -> RemotePageChange? {
        guard let pageID = record["entityID"] as? String,
              let workspaceID = record["workspaceID"] as? String,
              let title = record["title"] as? String,
              let orderKey = record["orderKey"] as? String else {
            return nil
        }

        return RemotePageChange(
            pageID: pageID,
            workspaceID: workspaceID,
            notebookID: record["notebookID"] as? String,
            title: title,
            orderKey: orderKey,
            isArchived: (record["isArchived"] as? NSNumber)?.boolValue ?? false
        )
    }

    private func remoteBlockChange(record: CKRecord) -> RemoteBlockChange? {
        guard let blockID = record["entityID"] as? String,
              let pageID = record["pageID"] as? String,
              let rawType = record["type"] as? String,
              let type = BlockType(rawValue: rawType),
              let textPlain = record["textPlain"] as? String,
              let payloadJSON = record["payloadJSON"] as? String else {
            return nil
        }

        let revision = (record["revision"] as? NSNumber)?.intValue ?? 0
        return RemoteBlockChange(
            blockID: blockID,
            pageID: pageID,
            type: type,
            textPlain: textPlain,
            payloadJSON: payloadJSON,
            revision: revision,
            parentBlockID: record["parentBlockID"] as? String,
            orderKey: record["orderKey"] as? String ?? "000001",
            isDeleted: (record["isDeleted"] as? NSNumber)?.boolValue ?? false
        )
    }

    private func remoteAttachmentChange(record: CKRecord) throws -> RemoteAttachmentChange? {
        guard let attachmentID = record["entityID"] as? String,
              let workspaceID = record["workspaceID"] as? String,
              let originalFilename = record["originalFilename"] as? String,
              let utiType = record["utiType"] as? String,
              let contentHash = record["contentHash"] as? String,
              let localPath = record["localPath"] as? String else {
            return nil
        }

        return RemoteAttachmentChange(
            attachmentID: attachmentID,
            workspaceID: workspaceID,
            originalFilename: originalFilename,
            utiType: utiType,
            byteSize: (record["byteSize"] as? NSNumber)?.intValue ?? 0,
            contentHash: contentHash,
            localPath: try downloadedAttachmentPath(
                record: record,
                workspaceID: workspaceID,
                attachmentID: attachmentID,
                originalFilename: originalFilename
            ) ?? localPath,
            thumbnailPath: record["thumbnailPath"] as? String
        )
    }

    private func downloadedAttachmentPath(
        record: CKRecord,
        workspaceID: String,
        attachmentID: String,
        originalFilename: String
    ) throws -> String? {
        guard let attachmentDownloadDirectory,
              let asset = record["asset"] as? CKAsset,
              let sourceURL = asset.fileURL else {
            return nil
        }

        let targetDirectory = attachmentDownloadDirectory
            .appendingPathComponent(workspaceID, isDirectory: true)
            .appendingPathComponent(attachmentID, isDirectory: true)
        let targetURL = targetDirectory.appendingPathComponent(originalFilename)
        try fileManager.createDirectory(
            at: targetDirectory,
            withIntermediateDirectories: true
        )
        if fileManager.fileExists(atPath: targetURL.path) {
            try fileManager.removeItem(at: targetURL)
        }
        try fileManager.copyItem(at: sourceURL, to: targetURL)
        return targetURL.path
    }

    private func remoteDeletedRecord(recordType: String, recordID: CKRecord.ID) -> RemoteDeletedRecord? {
        guard let expectedEntityType = entityType(recordType: recordType),
              let entityReference = Self.entityReference(recordName: recordID.recordName),
              entityReference.entityType == expectedEntityType else {
            return nil
        }

        return RemoteDeletedRecord(
            entityType: entityReference.entityType,
            entityID: entityReference.entityID
        )
    }

    private func entityType(recordType: String) -> String? {
        switch recordType {
        case "WorkspaceRecord":
            return "workspace"
        case "NotebookRecord":
            return "notebook"
        case "PageRecord":
            return "page"
        case "AttachmentRecord":
            return "attachment"
        case "BlockRecord":
            return "block"
        default:
            return nil
        }
    }

    private static func entityReference(recordName: String) -> (entityType: String, entityID: String)? {
        guard let separator = recordName.firstIndex(of: "-") else {
            return nil
        }

        let entityType = String(recordName[..<separator])
        let entityIDStart = recordName.index(after: separator)
        guard entityIDStart < recordName.endIndex else {
            return nil
        }

        return (
            entityType: entityType,
            entityID: String(recordName[entityIDStart...])
        )
    }

    private func makeRecord(type: String, entityType: String, entityID: String) -> CKRecord {
        let recordID = CKRecord.ID(recordName: "\(entityType)-\(entityID)")
        let record = CKRecord(recordType: type, recordID: recordID)
        record["entityID"] = entityID as CKRecordValue
        record["entityType"] = entityType as CKRecordValue
        return record
    }

    private func requiredRow(_ sql: String, entityID: String) throws -> SQLiteRow {
        guard let row = try database.query(sql, bindings: [.text(entityID)]).first else {
            throw CloudKitPrivateDatabaseAdapterError.entityNotFound(entityID)
        }
        return row
    }
}

enum CloudKitPrivateDatabaseAdapterError: Error, Equatable {
    case entityNotFound(String)
    case missingSavedRecord
    case remoteFetchUnavailable
    case unsupportedEntityType(String)
}

struct SyncRetryPolicy: Equatable, Sendable {
    let baseDelay: TimeInterval
    let maximumDelay: TimeInterval

    init(baseDelay: TimeInterval = 30, maximumDelay: TimeInterval = 900) {
        self.baseDelay = baseDelay
        self.maximumDelay = maximumDelay
    }

    func nextAttemptDate(afterFailureCount failureCount: Int, now: Date) -> Date {
        let exponent = max(failureCount - 1, 0)
        let multiplier = pow(2.0, Double(exponent))
        return now.addingTimeInterval(min(baseDelay * multiplier, maximumDelay))
    }
}

struct SyncUploadSummary: Equatable, Sendable {
    let uploadedCount: Int
    let failedCount: Int
}

struct SyncFetchSummary: Equatable, Sendable {
    let appliedCount: Int
}

final class SyncEngine {
    private static let serverChangeTokenScope = "privateDatabase"

    private let syncRepository: SyncRepository
    private let adapter: CloudKitSyncAdapter
    private let remoteChangeFetcher: CloudKitRemoteChangeFetching?
    private let mergeEngine: SyncMergeEngine?
    private let retryPolicy: SyncRetryPolicy
    private let now: () -> Date

    init(
        syncRepository: SyncRepository,
        adapter: CloudKitSyncAdapter,
        remoteChangeFetcher: CloudKitRemoteChangeFetching? = nil,
        mergeEngine: SyncMergeEngine? = nil,
        retryPolicy: SyncRetryPolicy = SyncRetryPolicy(),
        now: @escaping () -> Date = Date.init
    ) {
        self.syncRepository = syncRepository
        self.adapter = adapter
        self.remoteChangeFetcher = remoteChangeFetcher
        self.mergeEngine = mergeEngine
        self.retryPolicy = retryPolicy
        self.now = now
    }

    func fetchRemoteChanges() throws -> SyncFetchSummary {
        guard let remoteChangeFetcher, let mergeEngine else {
            return SyncFetchSummary(appliedCount: 0)
        }

        let changeSet = try remoteChangeFetcher.fetchRemoteChanges(
            sinceServerChangeTokenData: syncRepository.serverChangeTokenData(
                scope: Self.serverChangeTokenScope
            )
        )
        for change in changeSet.workspaceChanges {
            try mergeEngine.applyRemoteWorkspace(change)
        }
        for change in changeSet.notebookChanges {
            try mergeEngine.applyRemoteNotebook(change)
        }
        for change in changeSet.pageChanges {
            try mergeEngine.applyRemotePage(change)
        }
        for change in changeSet.attachmentChanges {
            try mergeEngine.applyRemoteAttachment(change)
        }
        for change in changeSet.blockChanges {
            try mergeEngine.applyRemoteBlock(change)
        }
        for deletion in changeSet.deletedRecords {
            try mergeEngine.applyRemoteDeletion(deletion)
        }
        if let serverChangeTokenData = changeSet.serverChangeTokenData {
            try syncRepository.saveServerChangeTokenData(
                serverChangeTokenData,
                scope: Self.serverChangeTokenScope
            )
        }
        return SyncFetchSummary(
            appliedCount: changeSet.workspaceChanges.count
                + changeSet.notebookChanges.count
                + changeSet.pageChanges.count
                + changeSet.attachmentChanges.count
                + changeSet.blockChanges.count
                + changeSet.deletedRecords.count
        )
    }

    @discardableResult
    func uploadPendingChanges() throws -> SyncUploadSummary {
        let changes = try syncRepository.pendingChanges()
        var uploadedCount = 0
        var failedCount = 0
        for change in changes {
            let retryState = try syncRepository.retryState(change: change)
            let currentDate = now()
            if let nextAttemptAt = retryState.nextAttemptAt,
               nextAttemptAt > currentDate {
                EditorLog.sync.debug(
                    "sync_change_deferred entity_type=\(change.entityType, privacy: .public) entity_id=\(change.entityID, privacy: .public)"
                )
                continue
            }

            do {
                let result = try adapter.upload(change: change)
                try syncRepository.markUploaded(change: change, uploadResult: result)
                uploadedCount += 1
                EditorLog.sync.debug(
                    "sync_change_uploaded entity_type=\(change.entityType, privacy: .public) entity_id=\(change.entityID, privacy: .public)"
                )
            } catch {
                let failureCount = retryState.attemptCount + 1
                try syncRepository.recordFailure(
                    change: change,
                    errorDescription: String(describing: error),
                    nextAttemptAt: retryPolicy.nextAttemptDate(afterFailureCount: failureCount, now: currentDate)
                )
                failedCount += 1
                EditorLog.sync.error(
                    "sync_change_upload_failed entity_type=\(change.entityType, privacy: .public) entity_id=\(change.entityID, privacy: .public) error=\(String(describing: error), privacy: .public)"
                )
            }
        }
        return SyncUploadSummary(uploadedCount: uploadedCount, failedCount: failedCount)
    }
}
