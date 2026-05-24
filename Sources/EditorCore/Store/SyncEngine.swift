import Foundation
import CloudKit

enum CloudKitSyncConfiguration {
    static let containerIdentifier = "iCloud.com.liangzhang.editor.sync"
    static let recordZoneName = "EditorSyncZone"
    static let recordZoneID = CKRecordZone.ID(
        zoneName: recordZoneName,
        ownerName: CKCurrentUserDefaultName
    )

    static var privateDatabase: CKDatabase {
        CKContainer(identifier: containerIdentifier).privateCloudDatabase
    }

    static func recordID(recordName: String) -> CKRecord.ID {
        CKRecord.ID(recordName: recordName, zoneID: recordZoneID)
    }
}

enum CloudKitErrorDiagnostic {
    static func describe(_ error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain != CKErrorDomain, nsError.userInfo.isEmpty {
            return String(describing: error)
        }

        var components = [
            "domain=\(nsError.domain)",
            "code=\(nsError.code)",
            "localizedDescription=\(nsError.localizedDescription)"
        ]
        let userInfoDescription = describeUserInfo(nsError.userInfo)
        if !userInfoDescription.isEmpty {
            components.append("userInfo={\(userInfoDescription)}")
        }
        return components.joined(separator: " ")
    }

    private static func describeUserInfo(_ userInfo: [String: Any]) -> String {
        let prioritizedKeys = [
            "CKHTTPStatus",
            "ContainerID",
            "CKErrorServerDescription",
            "NSDebugDescription",
            NSUnderlyingErrorKey
        ]
        var descriptions = prioritizedKeys.compactMap { key -> String? in
            guard let value = userInfo[key] else {
                return nil
            }
            return "\(key)=\(describeUserInfoValue(value))"
        }

        if let headers = userInfo["CKDHTTPHeaders"],
           let requestUUID = headerValue("x-apple-request-uuid", from: headers) {
            descriptions.append("x-apple-request-uuid=\(describeUserInfoValue(requestUUID))")
        }

        let omittedKeys = Set(prioritizedKeys + ["CKDHTTPHeaders", NSLocalizedDescriptionKey])
        descriptions.append(contentsOf: userInfo
            .filter { key, _ in !omittedKeys.contains(key) }
            .map { key, value in "\(key)=\(describeUserInfoValue(value))" }
            .sorted()
        )
        return descriptions.joined(separator: ", ")
    }

    private static func describeUserInfoValue(_ value: Any) -> String {
        if let error = value as? Error {
            return "[\(describe(error))]"
        }
        if let dictionary = value as? [AnyHashable: Any] {
            return describeDictionary(dictionary)
        }
        if let array = value as? [Any] {
            return "[" + array.map(describeUserInfoValue).joined(separator: ", ") + "]"
        }
        return String(describing: value)
    }

    private static func describeDictionary(_ dictionary: [AnyHashable: Any]) -> String {
        let values = dictionary
            .map { key, value in "\(String(describing: key))=\(describeUserInfoValue(value))" }
            .sorted()
            .joined(separator: ", ")
        return "{\(values)}"
    }

    private static func headerValue(_ key: String, from headers: Any) -> Any? {
        if let dictionary = headers as? [AnyHashable: Any] {
            return dictionary[key] ?? dictionary[key.capitalized]
        }
        if let dictionary = headers as? NSDictionary {
            return dictionary[key] ?? dictionary[key.capitalized]
        }
        return nil
    }
}

enum CloudKitRuntimeProbe {
    static let environmentKey = "EDITOR_CLOUDKIT_PROBE"
    private static let recordType = "EditorRuntimeProbeRecord"

    struct Result: Equatable, Sendable {
        let recordName: String
        let errorDescription: String?

        var isSuccess: Bool {
            errorDescription == nil
        }
    }

    static func isEnabled(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        environment[environmentKey] == "1"
    }

    static func runIfEnabled(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        guard isEnabled(environment: environment) else {
            return
        }

        DispatchQueue.global(qos: .utility).async {
            _ = run(
                accountStatusProvider: LiveCloudKitAccountStatusProvider(),
                zoneEnsurer: LiveCloudKitRecordZoneEnsurer.shared,
                databaseInspector: LiveCloudKitDatabaseInspector(),
                saver: LiveCloudKitRecordSaver(),
                reader: LiveCloudKitRecordFetcher(),
                deleter: LiveCloudKitRecordDeleter()
            )
        }
    }

    @discardableResult
    static func run(
        recordName: String = "runtime-probe-\(UUID().uuidString)",
        accountStatusProvider: CloudKitAccountStatusProviding,
        zoneEnsurer: CloudKitRecordZoneEnsuring,
        databaseInspector: CloudKitDatabaseInspecting,
        saver: CloudKitRecordSaving,
        reader: CloudKitRecordReading,
        deleter: CloudKitRecordDeleting
    ) -> Result {
        let record = makeRecord(recordName: recordName)

        do {
            let accountStatus = try accountStatusProvider.accountStatus()
            EditorLog.sync.debug(
                "cloudkit_runtime_probe_account_status_succeeded status=\(accountStatusDescription(accountStatus), privacy: .public)"
            )
            guard accountStatus == .available else {
                throw CloudKitRuntimeProbeError.accountUnavailable(accountStatus)
            }
        } catch {
            let errorDescription = CloudKitErrorDiagnostic.describe(error)
            EditorLog.sync.error(
                "cloudkit_runtime_probe_account_status_failed error=\(errorDescription, privacy: .public)"
            )
            return Result(recordName: record.recordID.recordName, errorDescription: errorDescription)
        }

        do {
            try zoneEnsurer.ensureRecordZoneExists()
            EditorLog.sync.debug(
                "cloudkit_runtime_probe_zone_ensure_succeeded zone=\(record.recordID.zoneID.zoneName, privacy: .public)"
            )
        } catch {
            let errorDescription = CloudKitErrorDiagnostic.describe(error)
            EditorLog.sync.error(
                "cloudkit_runtime_probe_zone_ensure_failed error=\(errorDescription, privacy: .public)"
            )
            return Result(recordName: record.recordID.recordName, errorDescription: errorDescription)
        }

        do {
            let zones = try databaseInspector.fetchAllRecordZones()
            EditorLog.sync.debug(
                "cloudkit_runtime_probe_zones_succeeded count=\(zones.count, privacy: .public) names=\(zoneNamesDescription(zones), privacy: .public)"
            )
        } catch {
            EditorLog.sync.error(
                "cloudkit_runtime_probe_zones_failed error=\(CloudKitErrorDiagnostic.describe(error), privacy: .public)"
            )
        }

        do {
            let subscriptions = try databaseInspector.fetchAllSubscriptions()
            EditorLog.sync.debug(
                "cloudkit_runtime_probe_subscriptions_succeeded count=\(subscriptions.count, privacy: .public) ids=\(subscriptionIDsDescription(subscriptions), privacy: .public)"
            )
        } catch {
            EditorLog.sync.error(
                "cloudkit_runtime_probe_subscriptions_failed error=\(CloudKitErrorDiagnostic.describe(error), privacy: .public)"
            )
        }

        EditorLog.sync.debug(
            "cloudkit_runtime_probe_save_started container=\(CloudKitSyncConfiguration.containerIdentifier, privacy: .public) zone=\(record.recordID.zoneID.zoneName, privacy: .public) record_type=\(record.recordType, privacy: .public) record_name=\(record.recordID.recordName, privacy: .public)"
        )

        let savedRecord: CKRecord
        do {
            savedRecord = try saver.save(record: record)
            EditorLog.sync.debug(
                "cloudkit_runtime_probe_save_succeeded record_name=\(savedRecord.recordID.recordName, privacy: .public) change_tag=\(savedRecord.recordChangeTag ?? "nil", privacy: .public)"
            )
        } catch {
            let errorDescription = CloudKitErrorDiagnostic.describe(error)
            EditorLog.sync.error(
                "cloudkit_runtime_probe_save_failed error=\(errorDescription, privacy: .public)"
            )
            return Result(recordName: record.recordID.recordName, errorDescription: errorDescription)
        }

        do {
            let fetchedRecord = try reader.fetch(recordID: savedRecord.recordID)
            EditorLog.sync.debug(
                "cloudkit_runtime_probe_fetch_succeeded record_name=\(fetchedRecord.recordID.recordName, privacy: .public)"
            )
        } catch {
            let errorDescription = CloudKitErrorDiagnostic.describe(error)
            EditorLog.sync.error(
                "cloudkit_runtime_probe_fetch_failed record_name=\(savedRecord.recordID.recordName, privacy: .public) error=\(errorDescription, privacy: .public)"
            )
            try? cleanup(savedRecord: savedRecord, deleter: deleter)
            return Result(recordName: savedRecord.recordID.recordName, errorDescription: errorDescription)
        }

        do {
            try cleanup(savedRecord: savedRecord, deleter: deleter)
            return Result(recordName: savedRecord.recordID.recordName, errorDescription: nil)
        } catch {
            let errorDescription = CloudKitErrorDiagnostic.describe(error)
            return Result(recordName: savedRecord.recordID.recordName, errorDescription: errorDescription)
        }
    }

    private static func makeRecord(recordName: String) -> CKRecord {
        let record = CKRecord(
            recordType: recordType,
            recordID: CloudKitSyncConfiguration.recordID(recordName: recordName)
        )
        record["probeVersion"] = "1" as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue
        return record
    }

    private static func cleanup(
        savedRecord: CKRecord,
        deleter: CloudKitRecordDeleting
    ) throws {
        do {
            try deleter.delete(recordID: savedRecord.recordID)
            EditorLog.sync.debug(
                "cloudkit_runtime_probe_cleanup_succeeded record_name=\(savedRecord.recordID.recordName, privacy: .public)"
            )
        } catch {
            EditorLog.sync.error(
                "cloudkit_runtime_probe_cleanup_failed record_name=\(savedRecord.recordID.recordName, privacy: .public) error=\(CloudKitErrorDiagnostic.describe(error), privacy: .public)"
            )
            throw error
        }
    }

    private static func accountStatusDescription(_ status: CKAccountStatus) -> String {
        switch status {
        case .available:
            return "available"
        case .noAccount:
            return "noAccount"
        case .restricted:
            return "restricted"
        case .couldNotDetermine:
            return "couldNotDetermine"
        case .temporarilyUnavailable:
            return "temporarilyUnavailable"
        @unknown default:
            return "unknown(\(status.rawValue))"
        }
    }

    private static func zoneNamesDescription(_ zones: [CKRecordZone]) -> String {
        zones
            .map(\.zoneID.zoneName)
            .sorted()
            .joined(separator: ",")
    }

    private static func subscriptionIDsDescription(_ subscriptions: [CKSubscription]) -> String {
        subscriptions
            .map(\.subscriptionID)
            .sorted()
            .joined(separator: ",")
    }
}

enum CloudKitRuntimeProbeError: Error, CustomStringConvertible {
    case accountUnavailable(CKAccountStatus)

    var description: String {
        switch self {
        case .accountUnavailable(let status):
            return "CloudKit account unavailable: \(status.rawValue)"
        }
    }
}

#if DEBUG
struct CloudKitRuntimeProbeDiagnosticRequest: Equatable {
    static let enabledKey = "EDITOR_CLOUDKIT_RUNTIME_PROBE_DIAGNOSTIC"

    init?(environment: [String: String]) {
        guard environment[Self.enabledKey] == "1" else {
            return nil
        }
    }
}

struct CloudKitSyncDiagnosticRequest: Equatable {
    static let enabledKey = "EDITOR_CLOUDKIT_SYNC_DIAGNOSTIC"
    static let appendTextKey = "EDITOR_CLOUDKIT_SYNC_DIAGNOSTIC_APPEND_TEXT"
    static let pageIDKey = "EDITOR_CLOUDKIT_SYNC_DIAGNOSTIC_PAGE_ID"

    let appendText: String?
    let pageID: String?

    init?(environment: [String: String]) {
        guard environment[Self.enabledKey] == "1" else {
            return nil
        }

        appendText = Self.nonEmptyValue(environment[Self.appendTextKey])
        pageID = Self.nonEmptyValue(environment[Self.pageIDKey])
    }

    private static func nonEmptyValue(_ value: String?) -> String? {
        guard let value, !value.isEmpty else {
            return nil
        }
        return value
    }
}

struct RemoteNotificationSyncDiagnosticRequest: Equatable {
    static let enabledKey = "EDITOR_REMOTE_NOTIFICATION_SYNC_DIAGNOSTIC"

    init?(environment: [String: String]) {
        guard environment[Self.enabledKey] == "1" else {
            return nil
        }
    }
}

struct CloudKitSyncDiagnosticResult: Equatable {
    enum Status: Equatable {
        case skipped
        case completed
        case failed
    }

    let status: Status
    let appendedBlockID: String?
    let uploadedCount: Int
    let failedUploadCount: Int
    let fetchedCount: Int
    let pendingChangeCount: Int
    let errorDescription: String?

    var displayText: String {
        switch status {
        case .skipped:
            return "CloudKit diagnostic skipped"
        case .completed:
            return [
                "CloudKit diagnostic completed",
                "appended=\(appendedBlockID ?? "nil")",
                "uploaded=\(uploadedCount)",
                "failed=\(failedUploadCount)",
                "fetched=\(fetchedCount)",
                "pending=\(pendingChangeCount)"
            ].joined(separator: " ")
        case .failed:
            return "CloudKit diagnostic failed \(errorDescription ?? "unknown")"
        }
    }
}

enum CloudKitSyncDiagnosticError: Error, CustomStringConvertible {
    case missingSyncEngine

    var description: String {
        switch self {
        case .missingSyncEngine:
            return "missing CloudKit sync engine"
        }
    }
}
#endif

struct CloudKitUploadResult: Equatable, Sendable {
    let recordName: String
    let changeTag: String?
}

struct CloudKitUploadBatchResult {
    private(set) var successes: [SyncChange: CloudKitUploadResult] = [:]
    private(set) var failures: [SyncChange: Error] = [:]

    mutating func recordSuccess(change: SyncChange, uploadResult: CloudKitUploadResult) {
        successes[change] = uploadResult
    }

    mutating func recordFailure(change: SyncChange, error: Error) {
        failures[change] = error
    }
}

protocol CloudKitSyncAdapter {
    func upload(change: SyncChange) throws -> CloudKitUploadResult
    func upload(changes: [SyncChange]) throws -> CloudKitUploadBatchResult
}

extension CloudKitSyncAdapter {
    func upload(changes: [SyncChange]) throws -> CloudKitUploadBatchResult {
        var batchResult = CloudKitUploadBatchResult()
        for change in changes {
            do {
                batchResult.recordSuccess(
                    change: change,
                    uploadResult: try upload(change: change)
                )
            } catch {
                batchResult.recordFailure(change: change, error: error)
            }
        }
        return batchResult
    }
}

protocol CloudKitRemoteChangeFetching {
    func fetchRemoteChanges(
        sinceServerChangeTokenData serverChangeTokenData: Data?
    ) throws -> CloudKitRemoteChangeSet
}

protocol CloudKitRemoteSnapshotFetching {
    func fetchCurrentGenerationSnapshot(
        sinceServerChangeTokenData serverChangeTokenData: Data?
    ) throws -> CloudKitRemoteChangeSet
}

struct CloudKitRemoteChangeSet: Equatable, Sendable {
    let workspaceChanges: [RemoteWorkspaceChange]
    let notebookChanges: [RemoteNotebookChange]
    let pageChanges: [RemotePageChange]
    let diaryPageChanges: [RemoteDiaryPageChange]
    let pageVersionChanges: [RemotePageVersionChange]
    let tagChanges: [RemoteTagChange]
    let pageTagChanges: [RemotePageTagChange]
    let attachmentChanges: [RemoteAttachmentChange]
    let blockChanges: [RemoteBlockChange]
    let fullSnapshotPageIDs: Set<String>
    let deletedRecords: [RemoteDeletedRecord]
    let serverChangeTokenData: Data?
    let hasMoreChanges: Bool

    init(
        workspaceChanges: [RemoteWorkspaceChange] = [],
        notebookChanges: [RemoteNotebookChange] = [],
        pageChanges: [RemotePageChange] = [],
        diaryPageChanges: [RemoteDiaryPageChange] = [],
        pageVersionChanges: [RemotePageVersionChange] = [],
        tagChanges: [RemoteTagChange] = [],
        pageTagChanges: [RemotePageTagChange] = [],
        attachmentChanges: [RemoteAttachmentChange] = [],
        blockChanges: [RemoteBlockChange] = [],
        fullSnapshotPageIDs: Set<String> = [],
        deletedRecords: [RemoteDeletedRecord] = [],
        serverChangeTokenData: Data? = nil,
        hasMoreChanges: Bool = false
    ) {
        self.workspaceChanges = workspaceChanges
        self.notebookChanges = notebookChanges
        self.pageChanges = pageChanges
        self.diaryPageChanges = diaryPageChanges
        self.pageVersionChanges = pageVersionChanges
        self.tagChanges = tagChanges
        self.pageTagChanges = pageTagChanges
        self.attachmentChanges = attachmentChanges
        self.blockChanges = blockChanges
        self.fullSnapshotPageIDs = fullSnapshotPageIDs
        self.deletedRecords = deletedRecords
        self.serverChangeTokenData = serverChangeTokenData
        self.hasMoreChanges = hasMoreChanges
    }
}

protocol CloudKitRecordSaving {
    func save(record: CKRecord) throws -> CKRecord
}

protocol CloudKitRecordDeleting {
    func delete(recordID: CKRecord.ID) throws
}

protocol CloudKitRecordZoneEnsuring {
    func ensureRecordZoneExists() throws
}

protocol CloudKitDatabaseInspecting {
    func fetchAllRecordZones() throws -> [CKRecordZone]
    func fetchAllSubscriptions() throws -> [CKSubscription]
}

protocol CloudKitRecordReading {
    func fetch(recordID: CKRecord.ID) throws -> CKRecord
}

protocol CloudKitSubscriptionSaving {
    func save(subscription: CKSubscription) throws -> CKSubscription
}

protocol CloudKitSubscriptionEnsuring {
    func ensureRemoteChangeSubscription() throws
}

protocol CloudKitRecordFetching {
    func fetchRecords(recordType: String) throws -> [CKRecord]
    func fetchCurrentGenerationRecords(recordType: String) throws -> [CKRecord]
    func fetchRecordChanges(
        sinceServerChangeTokenData serverChangeTokenData: Data?
    ) throws -> CloudKitFetchedRecordChangeSet
}

struct CloudKitFetchedRecordChangeSet: Equatable {
    let recordsByType: [String: [CKRecord]]
    let deletedRecordIDsByType: [String: [CKRecord.ID]]
    let serverChangeTokenData: Data?
    let hasMoreChanges: Bool

    init(
        recordsByType: [String: [CKRecord]],
        deletedRecordIDsByType: [String: [CKRecord.ID]] = [:],
        serverChangeTokenData: Data?,
        hasMoreChanges: Bool = false
    ) {
        self.recordsByType = recordsByType
        self.deletedRecordIDsByType = deletedRecordIDsByType
        self.serverChangeTokenData = serverChangeTokenData
        self.hasMoreChanges = hasMoreChanges
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
    func fetchCurrentGenerationRecords(recordType: String) throws -> [CKRecord] {
        try fetchRecords(recordType: recordType).filter { record in
            record["syncGeneration"] as? String == CloudKitSyncGeneration.current
        }
    }

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

final class LiveCloudKitRecordZoneEnsurer: CloudKitRecordZoneEnsuring, @unchecked Sendable {
    static let shared = LiveCloudKitRecordZoneEnsurer()

    private let database: CKDatabase
    private let zoneID: CKRecordZone.ID
    private let lock = NSLock()
    private var didEnsure = false

    init(
        database: CKDatabase = CloudKitSyncConfiguration.privateDatabase,
        zoneID: CKRecordZone.ID = CloudKitSyncConfiguration.recordZoneID
    ) {
        self.database = database
        self.zoneID = zoneID
    }

    func ensureRecordZoneExists() throws {
        lock.lock()
        defer { lock.unlock() }

        guard !didEnsure else {
            return
        }

        do {
            _ = try fetchRecordZone()
            didEnsure = true
            return
        } catch {
            guard Self.isMissingRecordZoneError(error) else {
                throw error
            }
        }

        _ = try saveRecordZone()
        didEnsure = true
        EditorLog.sync.debug(
            "cloudkit_record_zone_created zone=\(self.zoneID.zoneName, privacy: .public)"
        )
    }

    private func fetchRecordZone() throws -> CKRecordZone {
        let semaphore = DispatchSemaphore(value: 0)
        final class ZoneBox: @unchecked Sendable {
            var result: Result<CKRecordZone, Error>?
        }
        let zoneBox = ZoneBox()

        database.fetch(withRecordZoneID: zoneID) { zone, error in
            if let error {
                zoneBox.result = .failure(error)
            } else if let zone {
                zoneBox.result = .success(zone)
            } else {
                zoneBox.result = .failure(CloudKitPrivateDatabaseAdapterError.missingSavedRecord)
            }
            semaphore.signal()
        }
        semaphore.wait()

        return try zoneBox.result?.get() ?? {
            throw CloudKitPrivateDatabaseAdapterError.missingSavedRecord
        }()
    }

    private func saveRecordZone() throws -> CKRecordZone {
        let semaphore = DispatchSemaphore(value: 0)
        final class ZoneBox: @unchecked Sendable {
            var result: Result<CKRecordZone, Error>?
        }
        let zoneBox = ZoneBox()
        let zone = CKRecordZone(zoneID: zoneID)

        database.save(zone) { savedZone, error in
            if let error {
                zoneBox.result = .failure(error)
            } else if let savedZone {
                zoneBox.result = .success(savedZone)
            } else {
                zoneBox.result = .failure(CloudKitPrivateDatabaseAdapterError.missingSavedRecord)
            }
            semaphore.signal()
        }
        semaphore.wait()

        return try zoneBox.result?.get() ?? {
            throw CloudKitPrivateDatabaseAdapterError.missingSavedRecord
        }()
    }

    private static func isMissingRecordZoneError(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == CKErrorDomain
            && nsError.code == CKError.zoneNotFound.rawValue
    }
}

final class LiveCloudKitRecordSaver: CloudKitRecordSaving {
    private let database: CKDatabase
    private let zoneEnsurer: CloudKitRecordZoneEnsuring

    init(
        database: CKDatabase = CloudKitSyncConfiguration.privateDatabase,
        zoneEnsurer: CloudKitRecordZoneEnsuring = LiveCloudKitRecordZoneEnsurer.shared
    ) {
        self.database = database
        self.zoneEnsurer = zoneEnsurer
    }

    static func makeSaveOperation(record: CKRecord) -> CKModifyRecordsOperation {
        let operation = CKModifyRecordsOperation(
            recordsToSave: [record],
            recordIDsToDelete: nil
        )
        operation.savePolicy = .allKeys
        operation.isAtomic = false
        return operation
    }

    func save(record: CKRecord) throws -> CKRecord {
        try zoneEnsurer.ensureRecordZoneExists()

        let semaphore = DispatchSemaphore(value: 0)
        final class SaveBox: @unchecked Sendable {
            var result: Result<CKRecord, Error>?
            var savedRecord: CKRecord?
            var recordError: Error?
        }
        let saveBox = SaveBox()
        let operation = Self.makeSaveOperation(record: record)

        operation.perRecordSaveBlock = { _, recordResult in
            switch recordResult {
            case .success(let savedRecord):
                saveBox.savedRecord = savedRecord
            case .failure(let error):
                saveBox.recordError = error
            }
        }
        operation.modifyRecordsResultBlock = { result in
            if let recordError = saveBox.recordError {
                saveBox.result = .failure(recordError)
            } else if let savedRecord = saveBox.savedRecord {
                saveBox.result = .success(savedRecord)
            } else if case .failure(let error) = result {
                saveBox.result = .failure(error)
            } else {
                saveBox.result = .failure(CloudKitPrivateDatabaseAdapterError.missingSavedRecord)
            }
            semaphore.signal()
        }
        database.add(operation)
        semaphore.wait()

        return try saveBox.result?.get() ?? {
            throw CloudKitPrivateDatabaseAdapterError.missingSavedRecord
        }()
    }
}

final class LiveCloudKitRecordDeleter: CloudKitRecordDeleting {
    private let database: CKDatabase
    private let zoneEnsurer: CloudKitRecordZoneEnsuring

    init(
        database: CKDatabase = CloudKitSyncConfiguration.privateDatabase,
        zoneEnsurer: CloudKitRecordZoneEnsuring = LiveCloudKitRecordZoneEnsurer.shared
    ) {
        self.database = database
        self.zoneEnsurer = zoneEnsurer
    }

    func delete(recordID: CKRecord.ID) throws {
        try zoneEnsurer.ensureRecordZoneExists()

        let semaphore = DispatchSemaphore(value: 0)
        final class DeleteBox: @unchecked Sendable {
            var result: Result<Void, Error>?
        }
        let deleteBox = DeleteBox()

        database.delete(withRecordID: recordID) { _, error in
            if let error {
                deleteBox.result = .failure(error)
            } else {
                deleteBox.result = .success(())
            }
            semaphore.signal()
        }
        semaphore.wait()

        guard let result = deleteBox.result else {
            throw CloudKitPrivateDatabaseAdapterError.missingSavedRecord
        }
        try result.get()
    }
}

final class LiveCloudKitDatabaseInspector: CloudKitDatabaseInspecting {
    private let database: CKDatabase

    init(database: CKDatabase = CloudKitSyncConfiguration.privateDatabase) {
        self.database = database
    }

    func fetchAllRecordZones() throws -> [CKRecordZone] {
        let semaphore = DispatchSemaphore(value: 0)
        final class ZoneBox: @unchecked Sendable {
            var result: Result<[CKRecordZone], Error>?
        }
        let zoneBox = ZoneBox()

        database.fetchAllRecordZones { zones, error in
            if let error {
                zoneBox.result = .failure(error)
            } else {
                zoneBox.result = .success(zones ?? [])
            }
            semaphore.signal()
        }
        semaphore.wait()

        return try zoneBox.result?.get() ?? {
            throw CloudKitPrivateDatabaseAdapterError.missingSavedRecord
        }()
    }

    func fetchAllSubscriptions() throws -> [CKSubscription] {
        let semaphore = DispatchSemaphore(value: 0)
        final class SubscriptionBox: @unchecked Sendable {
            var result: Result<[CKSubscription], Error>?
        }
        let subscriptionBox = SubscriptionBox()

        database.fetchAllSubscriptions { subscriptions, error in
            if let error {
                subscriptionBox.result = .failure(error)
            } else {
                subscriptionBox.result = .success(subscriptions ?? [])
            }
            semaphore.signal()
        }
        semaphore.wait()

        return try subscriptionBox.result?.get() ?? {
            throw CloudKitPrivateDatabaseAdapterError.missingSavedRecord
        }()
    }
}

final class LiveCloudKitSubscriptionSaver: CloudKitSubscriptionSaving {
    private let database: CKDatabase

    init(database: CKDatabase = CloudKitSyncConfiguration.privateDatabase) {
        self.database = database
    }

    func save(subscription: CKSubscription) throws -> CKSubscription {
        let semaphore = DispatchSemaphore(value: 0)
        final class SaveBox: @unchecked Sendable {
            var result: Result<CKSubscription, Error>?
        }
        let saveBox = SaveBox()

        database.save(subscription) { savedSubscription, error in
            if let error {
                saveBox.result = .failure(error)
            } else if let savedSubscription {
                saveBox.result = .success(savedSubscription)
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

final class CloudKitPrivateDatabaseSubscriptionEnsurer: CloudKitSubscriptionEnsuring {
    static let subscriptionID = "editor-private-database-changes"

    private let subscriptionSaver: CloudKitSubscriptionSaving
    private let zoneEnsurer: CloudKitRecordZoneEnsuring

    init(
        subscriptionSaver: CloudKitSubscriptionSaving = LiveCloudKitSubscriptionSaver(),
        zoneEnsurer: CloudKitRecordZoneEnsuring = LiveCloudKitRecordZoneEnsurer.shared
    ) {
        self.subscriptionSaver = subscriptionSaver
        self.zoneEnsurer = zoneEnsurer
    }

    func ensureRemoteChangeSubscription() throws {
        try zoneEnsurer.ensureRecordZoneExists()

        let subscription = CKRecordZoneSubscription(
            zoneID: CloudKitSyncConfiguration.recordZoneID,
            subscriptionID: Self.subscriptionID
        )
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        _ = try subscriptionSaver.save(subscription: subscription)
    }
}

final class LiveCloudKitRecordFetcher: CloudKitRecordFetching, CloudKitRecordReading {
    static let recordZoneChangeBatchLimit = 1_000

    private let database: CKDatabase
    private let zoneEnsurer: CloudKitRecordZoneEnsuring
    private let operationWaiter: CloudKitOperationWaiter

    private typealias QueryFetchResponse = (
        matchResults: [(CKRecord.ID, Result<CKRecord, Error>)],
        queryCursor: CKQueryOperation.Cursor?
    )

    init(
        database: CKDatabase = CloudKitSyncConfiguration.privateDatabase,
        zoneEnsurer: CloudKitRecordZoneEnsuring = LiveCloudKitRecordZoneEnsurer.shared,
        operationWaiter: CloudKitOperationWaiter = CloudKitOperationWaiter(timeout: 75)
    ) {
        self.database = database
        self.zoneEnsurer = zoneEnsurer
        self.operationWaiter = operationWaiter
    }

    func fetch(recordID: CKRecord.ID) throws -> CKRecord {
        try zoneEnsurer.ensureRecordZoneExists()

        let semaphore = DispatchSemaphore(value: 0)
        final class FetchRecordBox: @unchecked Sendable {
            var result: Result<CKRecord, Error>?
        }
        let fetchBox = FetchRecordBox()

        database.fetch(withRecordID: recordID) { record, error in
            if let error {
                fetchBox.result = .failure(error)
            } else if let record {
                fetchBox.result = .success(record)
            } else {
                fetchBox.result = .failure(CloudKitPrivateDatabaseAdapterError.missingSavedRecord)
            }
            semaphore.signal()
        }
        try operationWaiter.wait(
            for: semaphore,
            operationName: "fetchRecord",
            cancel: {}
        )

        return try fetchBox.result?.get() ?? {
            throw CloudKitPrivateDatabaseAdapterError.missingSavedRecord
        }()
    }

    func fetchRecords(recordType: String) throws -> [CKRecord] {
        try zoneEnsurer.ensureRecordZoneExists()

        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        var response = try fetch(query: query, operationName: "fetchRecords:\(recordType)")
        var records = try Self.records(from: response.matchResults)

        while let cursor = response.queryCursor {
            response = try fetch(cursor: cursor, operationName: "fetchRecords:\(recordType):cursor")
            records.append(contentsOf: try Self.records(from: response.matchResults))
        }

        return records
    }

    func fetchCurrentGenerationRecords(recordType: String) throws -> [CKRecord] {
        do {
            let query = CKQuery(
                recordType: recordType,
                predicate: NSPredicate(
                    format: "syncGeneration == %@",
                    CloudKitSyncGeneration.current
                )
            )
            var response = try fetch(
                query: query,
                operationName: "fetchCurrentGenerationRecords:\(recordType)"
            )
            var records = try Self.records(from: response.matchResults)

            while let cursor = response.queryCursor {
                response = try fetch(
                    cursor: cursor,
                    operationName: "fetchCurrentGenerationRecords:\(recordType):cursor"
                )
                records.append(contentsOf: try Self.records(from: response.matchResults))
            }

            return records
        } catch {
            EditorLog.sync.error(
                "cloudkit_current_generation_query_failed record_type=\(recordType, privacy: .public) error=\(CloudKitErrorDiagnostic.describe(error), privacy: .public) fallback=unfiltered_query"
            )
            return try fetchRecords(recordType: recordType).filter { record in
                record["syncGeneration"] as? String == CloudKitSyncGeneration.current
            }
        }
    }

    private func fetch(query: CKQuery, operationName: String) throws -> QueryFetchResponse {
        let semaphore = DispatchSemaphore(value: 0)
        final class FetchBox: @unchecked Sendable {
            var result: Result<QueryFetchResponse, Error>?
        }
        let fetchBox = FetchBox()

        database.fetch(withQuery: query, inZoneWith: CloudKitSyncConfiguration.recordZoneID) { result in
            fetchBox.result = result
            semaphore.signal()
        }
        try operationWaiter.wait(
            for: semaphore,
            operationName: operationName,
            cancel: {}
        )

        return try fetchBox.result?.get() ?? (matchResults: [], queryCursor: nil)
    }

    private func fetch(cursor: CKQueryOperation.Cursor, operationName: String) throws -> QueryFetchResponse {
        let semaphore = DispatchSemaphore(value: 0)
        final class FetchBox: @unchecked Sendable {
            var result: Result<QueryFetchResponse, Error>?
        }
        let fetchBox = FetchBox()

        database.fetch(withCursor: cursor) { result in
            fetchBox.result = result
            semaphore.signal()
        }
        try operationWaiter.wait(
            for: semaphore,
            operationName: operationName,
            cancel: {}
        )

        return try fetchBox.result?.get() ?? (matchResults: [], queryCursor: nil)
    }

    private static func records(
        from matchResults: [(CKRecord.ID, Result<CKRecord, Error>)]
    ) throws -> [CKRecord] {
        var records: [CKRecord] = []
        for (_, recordResult) in matchResults {
            records.append(try recordResult.get())
        }
        return records
    }

    func fetchRecordChanges(
        sinceServerChangeTokenData serverChangeTokenData: Data?
    ) throws -> CloudKitFetchedRecordChangeSet {
        try zoneEnsurer.ensureRecordZoneExists()

        let previousToken = try CloudKitServerChangeTokenCodec.serverChangeToken(
            from: serverChangeTokenData
        )
        let zoneID = CloudKitSyncConfiguration.recordZoneID
        let configuration = CKFetchRecordZoneChangesOperation.ZoneConfiguration(
            previousServerChangeToken: previousToken
        )
        configuration.resultsLimit = Self.recordZoneChangeBatchLimit
        let operation = CKFetchRecordZoneChangesOperation(
            recordZoneIDs: [zoneID],
            configurationsByRecordZoneID: [zoneID: configuration]
        )
        operation.fetchAllChanges = false
        let operationConfiguration = CKOperation.Configuration()
        operationConfiguration.timeoutIntervalForResource = operationWaiter.timeout
        operation.configuration = operationConfiguration

        let semaphore = DispatchSemaphore(value: 0)
        final class FetchBox: @unchecked Sendable {
            var records: [CKRecord] = []
            var deletedRecordIDsByType: [String: [CKRecord.ID]] = [:]
            var serverChangeTokenData: Data?
            var hasMoreChanges = false
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
                    fetchBox.hasMoreChanges = response.moreComing
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
        try operationWaiter.wait(
            for: semaphore,
            operationName: "fetchRecordChanges",
            cancel: { operation.cancel() }
        )

        if let error = fetchBox.error {
            throw error
        }

        return CloudKitFetchedRecordChangeSet(
            recordsByType: Dictionary(grouping: fetchBox.records, by: \.recordType),
            deletedRecordIDsByType: fetchBox.deletedRecordIDsByType,
            serverChangeTokenData: fetchBox.serverChangeTokenData,
            hasMoreChanges: fetchBox.hasMoreChanges
        )
    }
}

final class CloudKitPrivateDatabaseAdapter: CloudKitSyncAdapter, CloudKitRemoteChangeFetching, CloudKitRemoteSnapshotFetching {
    static let recordTypes = [
        "WorkspaceRecord",
        "NotebookRecord",
        "PageRecord",
        "DiaryPageRecord",
        "PageVersionRecord",
        "TagRecord",
        "PageTagRecord",
        "AttachmentRecord",
        "BlockRecord"
    ]

    private let database: SQLiteDatabase
    private let recordSaver: CloudKitRecordSaving?
    private let recordDeleter: CloudKitRecordDeleting?
    private let recordFetcher: CloudKitRecordFetching?
    private let attachmentDownloadDirectory: URL?
    private let fileManager: FileManager

    init(
        database: SQLiteDatabase,
        recordSaver: CloudKitRecordSaving? = nil,
        recordDeleter: CloudKitRecordDeleting? = nil,
        recordFetcher: CloudKitRecordFetching? = nil,
        attachmentDownloadDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.database = database
        self.recordSaver = recordSaver
        self.recordDeleter = recordDeleter
        self.recordFetcher = recordFetcher
        self.attachmentDownloadDirectory = attachmentDownloadDirectory
        self.fileManager = fileManager
    }

    func upload(change: SyncChange) throws -> CloudKitUploadResult {
        if change.changeType == "delete" {
            let recordName = Self.recordName(entityType: change.entityType, entityID: change.entityID)
            do {
                try (recordDeleter ?? LiveCloudKitRecordDeleter()).delete(
                    recordID: CloudKitSyncConfiguration.recordID(recordName: recordName)
                )
            } catch {
                guard Self.isMissingRemoteRecordError(error) else {
                    throw error
                }
                EditorLog.sync.debug(
                    "cloudkit_delete_missing_remote_record_treated_as_synced record_name=\(recordName, privacy: .public)"
                )
            }
            return CloudKitUploadResult(recordName: recordName, changeTag: nil)
        }

        let record = try record(for: change)
        let savedRecord = try (recordSaver ?? LiveCloudKitRecordSaver()).save(record: record)
        return CloudKitUploadResult(
            recordName: savedRecord.recordID.recordName,
            changeTag: savedRecord.recordChangeTag
        )
    }

    func upload(changes: [SyncChange]) throws -> CloudKitUploadBatchResult {
        guard changes.count > 1,
              recordSaver == nil,
              recordDeleter == nil,
              changes.allSatisfy({ $0.changeType != "delete" }) else {
            return try uploadChangesOneByOne(changes)
        }

        try LiveCloudKitRecordZoneEnsurer.shared.ensureRecordZoneExists()

        var batchResult = CloudKitUploadBatchResult()
        var recordsToSave: [CKRecord] = []
        var changesByRecordName: [String: SyncChange] = [:]
        for change in changes {
            do {
                let record = try record(for: change)
                recordsToSave.append(record)
                changesByRecordName[record.recordID.recordName] = change
            } catch {
                batchResult.recordFailure(change: change, error: error)
            }
        }

        guard !recordsToSave.isEmpty else {
            return batchResult
        }

        let operation = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: nil)
        operation.savePolicy = .allKeys
        operation.isAtomic = false

        final class BatchSaveBox: @unchecked Sendable {
            var savedRecordsByName: [String: CKRecord] = [:]
            var errorsByName: [String: Error] = [:]
            var operationError: Error?
        }
        let saveBox = BatchSaveBox()
        let semaphore = DispatchSemaphore(value: 0)

        operation.perRecordSaveBlock = { recordID, recordResult in
            switch recordResult {
            case .success(let savedRecord):
                saveBox.savedRecordsByName[recordID.recordName] = savedRecord
            case .failure(let error):
                saveBox.errorsByName[recordID.recordName] = error
            }
        }
        operation.modifyRecordsResultBlock = { result in
            if case .failure(let error) = result {
                saveBox.operationError = error
            }
            semaphore.signal()
        }
        CloudKitSyncConfiguration.privateDatabase.add(operation)
        semaphore.wait()

        for (recordName, change) in changesByRecordName {
            if let savedRecord = saveBox.savedRecordsByName[recordName] {
                batchResult.recordSuccess(
                    change: change,
                    uploadResult: CloudKitUploadResult(
                        recordName: savedRecord.recordID.recordName,
                        changeTag: savedRecord.recordChangeTag
                    )
                )
            } else if let error = saveBox.errorsByName[recordName] ?? saveBox.operationError {
                batchResult.recordFailure(change: change, error: error)
            } else {
                batchResult.recordFailure(
                    change: change,
                    error: CloudKitPrivateDatabaseAdapterError.missingSavedRecord
                )
            }
        }

        return batchResult
    }

    private func uploadChangesOneByOne(_ changes: [SyncChange]) throws -> CloudKitUploadBatchResult {
        var batchResult = CloudKitUploadBatchResult()
        for change in changes {
            do {
                batchResult.recordSuccess(change: change, uploadResult: try upload(change: change))
            } catch {
                batchResult.recordFailure(change: change, error: error)
            }
        }
        return batchResult
    }

    func fetchRemoteChanges(
        sinceServerChangeTokenData serverChangeTokenData: Data?
    ) throws -> CloudKitRemoteChangeSet {
        guard let recordFetcher else {
            throw CloudKitPrivateDatabaseAdapterError.remoteFetchUnavailable
        }
        let fetchedChanges: CloudKitFetchedRecordChangeSet
        do {
            fetchedChanges = try recordFetcher.fetchRecordChanges(
                sinceServerChangeTokenData: serverChangeTokenData
            )
        } catch let timeout as CloudKitOperationTimeoutError {
            EditorLog.sync.error(
                "cloudkit_incremental_fetch_timed_out operation=\(timeout.operationName, privacy: .public) timeout=\(timeout.timeout, privacy: .public) action=retry_from_scratch"
            )
            fetchedChanges = try recordFetcher.fetchRecordChanges(
                sinceServerChangeTokenData: nil
            )
        }
        return try remoteChangeSet(from: fetchedChanges)
    }

    func fetchCurrentGenerationSnapshot(
        sinceServerChangeTokenData serverChangeTokenData: Data?
    ) throws -> CloudKitRemoteChangeSet {
        guard let recordFetcher else {
            throw CloudKitPrivateDatabaseAdapterError.remoteFetchUnavailable
        }
        return try remoteChangeSet(
            from: recordFetcher.fetchRecordChanges(
                sinceServerChangeTokenData: serverChangeTokenData
            )
        )
    }

    private func remoteChangeSet(from fetchedChanges: CloudKitFetchedRecordChangeSet) throws -> CloudKitRemoteChangeSet {
        let recordsByType = fetchedChanges.recordsByType
        let pageRecords = currentGenerationRecords(recordsByType["PageRecord"] ?? [])
        let pageChanges = pageRecords.compactMap(remotePageChange)
        let blockRecords = currentGenerationRecords(recordsByType["BlockRecord"] ?? [])
        let fullSnapshotPageIDs = Set<String>()
        let deletedRecords = Self.recordTypes.flatMap { recordType in
            (fetchedChanges.deletedRecordIDsByType[recordType] ?? []).compactMap { recordID in
                remoteDeletedRecord(recordType: recordType, recordID: recordID)
            }
        }

        return CloudKitRemoteChangeSet(
            workspaceChanges: currentGenerationRecords(recordsByType["WorkspaceRecord"] ?? []).compactMap(remoteWorkspaceChange),
            notebookChanges: currentGenerationRecords(recordsByType["NotebookRecord"] ?? []).compactMap(remoteNotebookChange),
            pageChanges: pageChanges,
            diaryPageChanges: currentGenerationRecords(recordsByType["DiaryPageRecord"] ?? []).compactMap(remoteDiaryPageChange),
            pageVersionChanges: currentGenerationRecords(recordsByType["PageVersionRecord"] ?? []).compactMap(remotePageVersionChange),
            tagChanges: currentGenerationRecords(recordsByType["TagRecord"] ?? []).compactMap(remoteTagChange),
            pageTagChanges: currentGenerationRecords(recordsByType["PageTagRecord"] ?? []).compactMap(remotePageTagChange),
            attachmentChanges: try currentGenerationRecords(recordsByType["AttachmentRecord"] ?? []).compactMap { record in
                try remoteAttachmentChange(record: record)
            },
            blockChanges: blockRecords.compactMap(remoteBlockChange),
            fullSnapshotPageIDs: fullSnapshotPageIDs,
            deletedRecords: deletedRecords,
            serverChangeTokenData: fetchedChanges.serverChangeTokenData,
            hasMoreChanges: fetchedChanges.hasMoreChanges
        )
    }

    func resetRemoteDataForFreshStart() throws -> Int {
        let fetcher = recordFetcher ?? LiveCloudKitRecordFetcher()
        let deleter = recordDeleter ?? LiveCloudKitRecordDeleter()
        var deletedCount = 0

        for recordType in Self.recordTypes {
            for record in try fetcher.fetchRecords(recordType: recordType) {
                try deleter.delete(recordID: record.recordID)
                deletedCount += 1
            }
        }

        EditorLog.sync.debug(
            "cloudkit_remote_reset_completed deleted_count=\(deletedCount, privacy: .public)"
        )
        return deletedCount
    }

    private func record(for change: SyncChange) throws -> CKRecord {
        switch change.entityType {
        case "workspace":
            return try workspaceRecord(entityID: change.entityID)
        case "notebook":
            return try notebookRecord(entityID: change.entityID)
        case "page":
            return try pageRecord(entityID: change.entityID)
        case "diaryPage":
            return try diaryPageRecord(entityID: change.entityID)
        case "pageVersion":
            return try pageVersionRecord(entityID: change.entityID)
        case "tag":
            return try tagRecord(entityID: change.entityID)
        case "pageTag":
            return try pageTagRecord(entityID: change.entityID)
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
            SELECT id, workspace_id, parent_notebook_id, name, order_key, updated_at
            FROM notebooks
            WHERE id = ?
            LIMIT 1
            """,
            entityID: entityID
        )
        let record = makeRecord(type: "NotebookRecord", entityType: "notebook", entityID: entityID)
        record["workspaceID"] = row["workspace_id"] as CKRecordValue?
        record["parentNotebookID"] = row["parent_notebook_id"] as CKRecordValue?
        record["name"] = row["name"] as CKRecordValue?
        record["orderKey"] = row["order_key"] as CKRecordValue?
        record["updatedAt"] = row["updated_at"] as CKRecordValue?
        return record
    }

    private func pageRecord(entityID: String) throws -> CKRecord {
        let row = try requiredRow(
            """
            SELECT id, workspace_id, notebook_id, title, order_key, is_archived, is_favorite, is_pinned, is_encrypted, created_at, updated_at
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
        record["isFavorite"] = NSNumber(value: Int(row["is_favorite"] ?? "") ?? 0)
        record["isPinned"] = NSNumber(value: Int(row["is_pinned"] ?? "") ?? 0)
        record["isEncrypted"] = NSNumber(value: Int(row["is_encrypted"] ?? "") ?? 0)
        record["createdAt"] = row["created_at"] as CKRecordValue?
        record["updatedAt"] = row["updated_at"] as CKRecordValue?
        return record
    }

    private func diaryPageRecord(entityID: String) throws -> CKRecord {
        let row = try requiredRow(
            """
            SELECT page_id, workspace_id, diary_date, updated_at
            FROM diary_pages
            WHERE page_id = ?
            LIMIT 1
            """,
            entityID: entityID
        )
        let record = makeRecord(type: "DiaryPageRecord", entityType: "diaryPage", entityID: entityID)
        record["workspaceID"] = row["workspace_id"] as CKRecordValue?
        record["diaryDate"] = row["diary_date"] as CKRecordValue?
        record["updatedAt"] = row["updated_at"] as CKRecordValue?
        return record
    }

    private func pageVersionRecord(entityID: String) throws -> CKRecord {
        let row = try requiredRow(
            """
            SELECT id,
                   page_id,
                   title,
                   snapshot_json,
                   content_hash,
                   block_count,
                   created_at,
                   updated_at
            FROM page_versions
            WHERE id = ?
            LIMIT 1
            """,
            entityID: entityID
        )
        let record = makeRecord(type: "PageVersionRecord", entityType: "pageVersion", entityID: entityID)
        record["pageID"] = row["page_id"] as CKRecordValue?
        record["title"] = row["title"] as CKRecordValue?
        record["snapshotJSON"] = row["snapshot_json"] as CKRecordValue?
        record["contentHash"] = row["content_hash"] as CKRecordValue?
        record["blockCount"] = NSNumber(value: Int(row["block_count"] ?? "") ?? 0)
        record["createdAt"] = row["created_at"] as CKRecordValue?
        record["updatedAt"] = row["updated_at"] as CKRecordValue?
        return record
    }

    private func tagRecord(entityID: String) throws -> CKRecord {
        let row = try requiredRow(
            """
            SELECT id, workspace_id, parent_tag_id, name, order_key, updated_at
            FROM tags
            WHERE id = ?
            LIMIT 1
            """,
            entityID: entityID
        )
        let record = makeRecord(type: "TagRecord", entityType: "tag", entityID: entityID)
        record["workspaceID"] = row["workspace_id"] as CKRecordValue?
        record["parentTagID"] = row["parent_tag_id"] as CKRecordValue?
        record["name"] = row["name"] as CKRecordValue?
        record["orderKey"] = row["order_key"] as CKRecordValue?
        record["updatedAt"] = row["updated_at"] as CKRecordValue?
        return record
    }

    private func pageTagRecord(entityID: String) throws -> CKRecord {
        guard let components = PageTagSyncIdentity.components(entityID: entityID) else {
            throw CloudKitPrivateDatabaseAdapterError.entityNotFound(entityID)
        }

        let row = try database.query(
            """
            SELECT page_id, tag_id, created_at
            FROM page_tags
            WHERE page_id = ? AND tag_id = ?
            LIMIT 1
            """,
            bindings: [
                .text(components.pageID),
                .text(components.tagID)
            ]
        ).first
        guard let row else {
            throw CloudKitPrivateDatabaseAdapterError.entityNotFound(entityID)
        }

        let record = makeRecord(type: "PageTagRecord", entityType: "pageTag", entityID: entityID)
        record["pageID"] = row["page_id"] as CKRecordValue?
        record["tagID"] = row["tag_id"] as CKRecordValue?
        record["createdAt"] = row["created_at"] as CKRecordValue?
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
           fileManager.fileExists(atPath: localPath) {
            record["asset"] = CKAsset(fileURL: URL(fileURLWithPath: localPath))
        }
        if let thumbnailPath = row["thumbnail_path"] ?? nil,
           fileManager.fileExists(atPath: thumbnailPath) {
            record["thumbnailAsset"] = CKAsset(fileURL: URL(fileURLWithPath: thumbnailPath))
        }
        return record
    }

    private func remoteWorkspaceChange(record: CKRecord) -> RemoteWorkspaceChange? {
        guard let workspaceID = record["entityID"] as? String,
              let name = record["name"] as? String else {
            return nil
        }

        return RemoteWorkspaceChange(
            workspaceID: workspaceID,
            name: name,
            updatedAt: record["updatedAt"] as? String
        )
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
            parentNotebookID: record["parentNotebookID"] as? String,
            name: name,
            orderKey: orderKey,
            updatedAt: record["updatedAt"] as? String
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
            isArchived: (record["isArchived"] as? NSNumber)?.boolValue ?? false,
            isFavorite: (record["isFavorite"] as? NSNumber)?.boolValue ?? false,
            isPinned: (record["isPinned"] as? NSNumber)?.boolValue ?? false,
            isEncrypted: (record["isEncrypted"] as? NSNumber)?.boolValue ?? false,
            createdAt: record["createdAt"] as? String,
            updatedAt: record["updatedAt"] as? String
        )
    }

    private func remoteDiaryPageChange(record: CKRecord) -> RemoteDiaryPageChange? {
        guard let pageID = record["entityID"] as? String,
              let workspaceID = record["workspaceID"] as? String,
              let diaryDate = record["diaryDate"] as? String else {
            return nil
        }

        return RemoteDiaryPageChange(
            pageID: pageID,
            workspaceID: workspaceID,
            diaryDate: diaryDate,
            updatedAt: record["updatedAt"] as? String
        )
    }

    private func remotePageVersionChange(record: CKRecord) -> RemotePageVersionChange? {
        guard let versionID = record["entityID"] as? String,
              let pageID = record["pageID"] as? String,
              let title = record["title"] as? String,
              let snapshotJSON = record["snapshotJSON"] as? String,
              let contentHash = record["contentHash"] as? String,
              let createdAt = record["createdAt"] as? String else {
            return nil
        }

        return RemotePageVersionChange(
            versionID: versionID,
            pageID: pageID,
            title: title,
            snapshotJSON: snapshotJSON,
            contentHash: contentHash,
            blockCount: (record["blockCount"] as? NSNumber)?.intValue ?? 0,
            createdAt: createdAt,
            updatedAt: record["updatedAt"] as? String
        )
    }

    private func remoteTagChange(record: CKRecord) -> RemoteTagChange? {
        guard let tagID = record["entityID"] as? String,
              let workspaceID = record["workspaceID"] as? String,
              let name = record["name"] as? String,
              let orderKey = record["orderKey"] as? String else {
            return nil
        }

        return RemoteTagChange(
            tagID: tagID,
            workspaceID: workspaceID,
            parentTagID: record["parentTagID"] as? String,
            name: name,
            orderKey: orderKey,
            updatedAt: record["updatedAt"] as? String
        )
    }

    private func remotePageTagChange(record: CKRecord) -> RemotePageTagChange? {
        guard let pageID = record["pageID"] as? String,
              let tagID = record["tagID"] as? String else {
            return nil
        }

        return RemotePageTagChange(
            pageID: pageID,
            tagID: tagID,
            createdAt: record["createdAt"] as? String
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
            isDeleted: (record["isDeleted"] as? NSNumber)?.boolValue ?? false,
            updatedAt: record["updatedAt"] as? String
        )
    }

    private func remoteAttachmentChange(record: CKRecord) throws -> RemoteAttachmentChange? {
        guard let attachmentID = record["entityID"] as? String,
              let workspaceID = record["workspaceID"] as? String,
              let originalFilename = record["originalFilename"] as? String,
              let utiType = record["utiType"] as? String,
              let contentHash = record["contentHash"] as? String else {
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
            ) ?? "",
            thumbnailPath: try downloadedAttachmentThumbnailPath(
                record: record,
                workspaceID: workspaceID,
                attachmentID: attachmentID
            ) ?? (record["thumbnailPath"] as? String),
            updatedAt: record["updatedAt"] as? String
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

    private func downloadedAttachmentThumbnailPath(
        record: CKRecord,
        workspaceID: String,
        attachmentID: String
    ) throws -> String? {
        guard let attachmentDownloadDirectory,
              let asset = record["thumbnailAsset"] as? CKAsset,
              let sourceURL = asset.fileURL else {
            return nil
        }

        let remoteThumbnailPath = record["thumbnailPath"] as? String
        let thumbnailFilename = remoteThumbnailPath.map {
            URL(fileURLWithPath: $0).lastPathComponent
        } ?? "thumbnail.jpg"
        let targetDirectory = attachmentDownloadDirectory
            .appendingPathComponent(workspaceID, isDirectory: true)
            .appendingPathComponent(attachmentID, isDirectory: true)
        let targetURL = targetDirectory.appendingPathComponent(thumbnailFilename)
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
        case "DiaryPageRecord":
            return "diaryPage"
        case "PageVersionRecord":
            return "pageVersion"
        case "TagRecord":
            return "tag"
        case "PageTagRecord":
            return "pageTag"
        case "AttachmentRecord":
            return "attachment"
        case "BlockRecord":
            return "block"
        default:
            return nil
        }
    }

    private static func entityReference(recordName: String) -> (entityType: String, entityID: String)? {
        let prefix = "\(CloudKitSyncGeneration.current)."
        guard recordName.hasPrefix(prefix) else {
            return nil
        }

        let reference = String(recordName.dropFirst(prefix.count))
        guard let separator = reference.firstIndex(of: ".") else {
            return nil
        }

        let entityType = String(reference[..<separator])
        let entityIDStart = reference.index(after: separator)
        guard entityIDStart < reference.endIndex else {
            return nil
        }

        return (
            entityType: entityType,
            entityID: String(reference[entityIDStart...])
        )
    }

    private func makeRecord(type: String, entityType: String, entityID: String) -> CKRecord {
        let recordID = CloudKitSyncConfiguration.recordID(
            recordName: Self.recordName(entityType: entityType, entityID: entityID)
        )
        let record = CKRecord(recordType: type, recordID: recordID)
        record["entityID"] = entityID as CKRecordValue
        record["entityType"] = entityType as CKRecordValue
        record["syncGeneration"] = CloudKitSyncGeneration.current as CKRecordValue
        return record
    }

    private static func recordName(entityType: String, entityID: String) -> String {
        "\(CloudKitSyncGeneration.current).\(entityType).\(entityID)"
    }

    private static func isMissingRemoteRecordError(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == CKErrorDomain
            && nsError.code == CKError.unknownItem.rawValue
    }

    private func currentGenerationRecords(_ records: [CKRecord]) -> [CKRecord] {
        records.filter { record in
            record["syncGeneration"] as? String == CloudKitSyncGeneration.current
        }
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

struct CloudKitOperationTimeoutError: Error, Equatable, CustomStringConvertible {
    let operationName: String
    let timeout: TimeInterval

    var description: String {
        "\(operationName) timed out after \(timeout) seconds"
    }
}

struct CloudKitOperationWaiter: Sendable {
    let timeout: TimeInterval

    func wait(
        for semaphore: DispatchSemaphore,
        operationName: String,
        cancel: () -> Void
    ) throws {
        let timeoutNanoseconds = max(0, Int(timeout * 1_000_000_000))
        let result = semaphore.wait(timeout: .now() + .nanoseconds(timeoutNanoseconds))
        if result == .timedOut {
            cancel()
            throw CloudKitOperationTimeoutError(
                operationName: operationName,
                timeout: timeout
            )
        }
    }
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
    let hasMoreChanges: Bool

    init(appliedCount: Int, hasMoreChanges: Bool = false) {
        self.appliedCount = appliedCount
        self.hasMoreChanges = hasMoreChanges
    }
}

enum RemoteBlockChangeDependencySorter {
    static func sorted(_ changes: [RemoteBlockChange]) -> [RemoteBlockChange] {
        let changesByID = Dictionary(uniqueKeysWithValues: changes.map { ($0.blockID, $0) })
        var ordered: [RemoteBlockChange] = []
        var visiting = Set<String>()
        var visited = Set<String>()

        for change in changes {
            visit(
                change,
                changesByID: changesByID,
                visiting: &visiting,
                visited: &visited,
                ordered: &ordered
            )
        }
        return ordered
    }

    private static func visit(
        _ change: RemoteBlockChange,
        changesByID: [String: RemoteBlockChange],
        visiting: inout Set<String>,
        visited: inout Set<String>,
        ordered: inout [RemoteBlockChange]
    ) {
        guard !visited.contains(change.blockID) else {
            return
        }
        guard !visiting.contains(change.blockID) else {
            ordered.append(change)
            visited.insert(change.blockID)
            return
        }

        visiting.insert(change.blockID)
        if let parentBlockID = change.parentBlockID,
           let parent = changesByID[parentBlockID] {
            visit(
                parent,
                changesByID: changesByID,
                visiting: &visiting,
                visited: &visited,
                ordered: &ordered
            )
        }
        visiting.remove(change.blockID)

        if !visited.contains(change.blockID) {
            ordered.append(change)
            visited.insert(change.blockID)
        }
    }
}

enum RemoteTagChangeDependencySorter {
    static func sorted(_ changes: [RemoteTagChange]) -> [RemoteTagChange] {
        let changesByID = Dictionary(uniqueKeysWithValues: changes.map { ($0.tagID, $0) })
        var ordered: [RemoteTagChange] = []
        var visiting = Set<String>()
        var visited = Set<String>()

        for change in changes {
            visit(
                change,
                changesByID: changesByID,
                visiting: &visiting,
                visited: &visited,
                ordered: &ordered
            )
        }
        return ordered
    }

    private static func visit(
        _ change: RemoteTagChange,
        changesByID: [String: RemoteTagChange],
        visiting: inout Set<String>,
        visited: inout Set<String>,
        ordered: inout [RemoteTagChange]
    ) {
        guard !visited.contains(change.tagID) else {
            return
        }
        guard !visiting.contains(change.tagID) else {
            ordered.append(change)
            visited.insert(change.tagID)
            return
        }

        visiting.insert(change.tagID)
        if let parentTagID = change.parentTagID,
           let parent = changesByID[parentTagID] {
            visit(
                parent,
                changesByID: changesByID,
                visiting: &visiting,
                visited: &visited,
                ordered: &ordered
            )
        }
        visiting.remove(change.tagID)

        if !visited.contains(change.tagID) {
            ordered.append(change)
            visited.insert(change.tagID)
        }
    }
}

struct SyncRemoteApplyError: Error, Equatable, CustomStringConvertible {
    let entityType: String
    let entityID: String
    let details: String?
    let underlyingDescription: String

    var description: String {
        var components = [
            "remote_apply_failed",
            "entity_type=\(entityType)",
            "entity_id=\(entityID)"
        ]
        if let details, !details.isEmpty {
            components.append(details)
        }
        components.append("error=\(underlyingDescription)")
        return components.joined(separator: " ")
    }
}

@MainActor
protocol RemoteNotificationRegistering: AnyObject {
    func registerForRemoteNotifications()
}

@MainActor
enum RemoteNotificationRegistrationPolicy {
    static func registerIfNeeded(
        hasCloudKitContainers: Bool,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        registrar: RemoteNotificationRegistering
    ) {
        guard hasCloudKitContainers else {
            EditorLog.sync.debug("remote_notification_registration_skipped reason=missing_cloudkit_entitlement")
            return
        }

#if DEBUG
        guard CloudKitSyncDiagnosticRequest(environment: environment) == nil else {
            EditorLog.sync.debug("remote_notification_registration_skipped reason=headless_sync_diagnostic")
            return
        }

        guard RemoteNotificationSyncDiagnosticRequest(environment: environment) == nil else {
            EditorLog.sync.debug("remote_notification_registration_skipped reason=remote_notification_sync_diagnostic")
            return
        }
#endif

        registrar.registerForRemoteNotifications()
        EditorLog.sync.debug("remote_notification_registration_requested")
    }
}

protocol RemoteNotificationSyncing {
    func ensureRemoteChangeSubscription() throws
    func uploadPendingChanges() throws -> SyncUploadSummary
    func fetchRemoteChanges() throws -> SyncFetchSummary
}

enum RemoteNotificationSyncResult: Equatable, Sendable {
    case newData
    case noData
    case failed
}

struct RemoteNotificationSyncReport: Equatable, Sendable {
    let result: RemoteNotificationSyncResult
    let uploadedCount: Int
    let failedUploadCount: Int
    let fetchedCount: Int
    let errorDescription: String?
}

struct RemoteNotificationSyncHandler {
    let syncer: RemoteNotificationSyncing?

    func handleRemoteNotification() -> RemoteNotificationSyncResult {
        handleRemoteNotificationReport().result
    }

    func handleRemoteNotificationReport() -> RemoteNotificationSyncReport {
        guard let syncer else {
            EditorLog.sync.debug("remote_notification_sync_unavailable")
            return RemoteNotificationSyncReport(
                result: .noData,
                uploadedCount: 0,
                failedUploadCount: 0,
                fetchedCount: 0,
                errorDescription: nil
            )
        }

        var uploadSummary = SyncUploadSummary(uploadedCount: 0, failedCount: 0)
        var fetchSummary = SyncFetchSummary(appliedCount: 0)
        do {
            try syncer.ensureRemoteChangeSubscription()
            fetchSummary = try syncer.fetchRemoteChanges()
            uploadSummary = try syncer.uploadPendingChanges()
            if uploadSummary.failedCount > 0 {
                EditorLog.sync.error(
                    "remote_notification_sync_failed failed_uploads=\(uploadSummary.failedCount, privacy: .public)"
                )
            }

            if uploadSummary.failedCount > 0 {
                return RemoteNotificationSyncReport(
                    result: fetchSummary.appliedCount > 0 ? .newData : .failed,
                    uploadedCount: uploadSummary.uploadedCount,
                    failedUploadCount: uploadSummary.failedCount,
                    fetchedCount: fetchSummary.appliedCount,
                    errorDescription: nil
                )
            }

            let hasChanges = uploadSummary.uploadedCount > 0 || fetchSummary.appliedCount > 0
            EditorLog.sync.debug(
                "remote_notification_sync_completed uploaded=\(uploadSummary.uploadedCount, privacy: .public) fetched=\(fetchSummary.appliedCount, privacy: .public)"
            )
            return RemoteNotificationSyncReport(
                result: hasChanges ? .newData : .noData,
                uploadedCount: uploadSummary.uploadedCount,
                failedUploadCount: uploadSummary.failedCount,
                fetchedCount: fetchSummary.appliedCount,
                errorDescription: nil
            )
        } catch {
            let errorDescription = String(describing: error)
            EditorLog.sync.error(
                "remote_notification_sync_failed error=\(errorDescription, privacy: .public)"
            )
            return RemoteNotificationSyncReport(
                result: .failed,
                uploadedCount: uploadSummary.uploadedCount,
                failedUploadCount: uploadSummary.failedCount,
                fetchedCount: fetchSummary.appliedCount,
                errorDescription: errorDescription
            )
        }
    }
}

final class SyncEngine {
    private static let serverChangeTokenScope = "privateDatabase"
    private static let legacyCurrentGenerationSnapshotBackfillScope = "currentGenerationSnapshotBackfill.\(CloudKitSyncGeneration.current)"
    private static let currentGenerationSnapshotBackfillCompletedScope = "currentGenerationSnapshotBackfill.completed.\(CloudKitSyncGeneration.current)"
    private static let currentGenerationSnapshotBackfillTokenScope = "currentGenerationSnapshotBackfill.token.\(CloudKitSyncGeneration.current)"
    private static let snapshotBackfillPageThreshold = 50

    private let syncRepository: SyncRepository
    private let adapter: CloudKitSyncAdapter
    private let remoteChangeFetcher: CloudKitRemoteChangeFetching?
    private let remoteSnapshotFetcher: CloudKitRemoteSnapshotFetching?
    private let mergeEngine: SyncMergeEngine?
    private let subscriptionEnsurer: CloudKitSubscriptionEnsuring?
    private let retryPolicy: SyncRetryPolicy
    private let uploadBatchSize: Int
    private let maximumUploadsPerRun: Int
    private let now: () -> Date

    init(
        syncRepository: SyncRepository,
        adapter: CloudKitSyncAdapter,
        remoteChangeFetcher: CloudKitRemoteChangeFetching? = nil,
        remoteSnapshotFetcher: CloudKitRemoteSnapshotFetching? = nil,
        mergeEngine: SyncMergeEngine? = nil,
        subscriptionEnsurer: CloudKitSubscriptionEnsuring? = nil,
        retryPolicy: SyncRetryPolicy = SyncRetryPolicy(),
        uploadBatchSize: Int = 200,
        maximumUploadsPerRun: Int = .max,
        now: @escaping () -> Date = Date.init
    ) {
        self.syncRepository = syncRepository
        self.adapter = adapter
        self.remoteChangeFetcher = remoteChangeFetcher
        self.remoteSnapshotFetcher = remoteSnapshotFetcher
        self.mergeEngine = mergeEngine
        self.subscriptionEnsurer = subscriptionEnsurer
        self.retryPolicy = retryPolicy
        self.uploadBatchSize = max(1, uploadBatchSize)
        self.maximumUploadsPerRun = max(1, maximumUploadsPerRun)
        self.now = now
    }

    func ensureRemoteChangeSubscription() throws {
        try subscriptionEnsurer?.ensureRemoteChangeSubscription()
    }

    func recordRuntimeDiagnostic(eventName: String, payloadJSON: String) {
        do {
            try syncRepository.recordRuntimeDiagnostic(
                eventName: eventName,
                payloadJSON: payloadJSON
            )
        } catch {
            EditorLog.sync.error(
                "sync_runtime_diagnostic_record_failed event_name=\(eventName, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
        }
    }

    func pendingChangeCount() throws -> Int {
        try syncRepository.pendingChanges().count
    }

    func fetchRemoteChanges() throws -> SyncFetchSummary {
        guard let mergeEngine else {
            return SyncFetchSummary(appliedCount: 0)
        }

        if let remoteSnapshotFetcher,
           try shouldRunCurrentGenerationSnapshotBackfill() {
            let pageCount = try syncRepository.pageRecordCount()
            let snapshotTokenData = try syncRepository.serverChangeTokenData(
                scope: Self.currentGenerationSnapshotBackfillTokenScope
            )
            recordRuntimeDiagnostic(
                eventName: "foreground_sync_snapshot_backfill_started",
                payloadJSON: Self.diagnosticPayloadJSON([
                    "page_count": "\(pageCount)",
                    "has_token": snapshotTokenData == nil ? "false" : "true",
                    "generation": CloudKitSyncGeneration.current
                ])
            )
            let snapshotChangeSet = try remoteSnapshotFetcher.fetchCurrentGenerationSnapshot(
                sinceServerChangeTokenData: snapshotTokenData
            )
            let snapshotSummary = try applyRemoteChangeSet(snapshotChangeSet, mergeEngine: mergeEngine)
            if let serverChangeTokenData = snapshotChangeSet.serverChangeTokenData {
                try syncRepository.saveServerChangeTokenData(
                    serverChangeTokenData,
                    scope: Self.currentGenerationSnapshotBackfillTokenScope
                )
            }
            if !snapshotSummary.hasMoreChanges {
                try syncRepository.markRemoteSnapshotBackfillCompleted(
                    scope: Self.currentGenerationSnapshotBackfillCompletedScope
                )
                try syncRepository.clearServerChangeTokenData(
                    scope: Self.currentGenerationSnapshotBackfillTokenScope
                )
            }
            recordRuntimeDiagnostic(
                eventName: "foreground_sync_snapshot_backfill_completed",
                payloadJSON: "{\"fetched_count\":\(snapshotSummary.appliedCount),\"has_more_changes\":\(snapshotSummary.hasMoreChanges)}"
            )
            if snapshotSummary.appliedCount > 0 || snapshotSummary.hasMoreChanges {
                return SyncFetchSummary(
                    appliedCount: snapshotSummary.appliedCount,
                    hasMoreChanges: snapshotSummary.hasMoreChanges
                )
            }
        }

        guard let remoteChangeFetcher else {
            return SyncFetchSummary(appliedCount: 0)
        }

        let previousServerChangeTokenData = try syncRepository.serverChangeTokenData(
            scope: Self.serverChangeTokenScope
        )
        let changeSet: CloudKitRemoteChangeSet
        do {
            changeSet = try remoteChangeFetcher.fetchRemoteChanges(
                sinceServerChangeTokenData: previousServerChangeTokenData
            )
        } catch {
            guard previousServerChangeTokenData != nil,
                  Self.isServerChangeTokenExpiredError(error) else {
                throw error
            }

            try syncRepository.clearServerChangeTokenData(scope: Self.serverChangeTokenScope)
            EditorLog.sync.error("cloudkit_server_change_token_expired action=retry_from_scratch")
            changeSet = try remoteChangeFetcher.fetchRemoteChanges(sinceServerChangeTokenData: nil)
        }
        let summary = try applyRemoteChangeSet(changeSet, mergeEngine: mergeEngine)
        if let serverChangeTokenData = changeSet.serverChangeTokenData {
            try syncRepository.saveServerChangeTokenData(
                serverChangeTokenData,
                scope: Self.serverChangeTokenScope
            )
        }
        return summary
    }

    private func shouldRunCurrentGenerationSnapshotBackfill() throws -> Bool {
        guard try !syncRepository.hasCompletedRemoteSnapshotBackfill(
            scope: Self.currentGenerationSnapshotBackfillCompletedScope
        ) else {
            return false
        }
        if try syncRepository.serverChangeTokenData(
            scope: Self.currentGenerationSnapshotBackfillTokenScope
        ) != nil {
            return true
        }
        guard try syncRepository.pageRecordCount() <= Self.snapshotBackfillPageThreshold else {
            return false
        }
        return true
    }

    private func applyRemoteChangeSet(
        _ changeSet: CloudKitRemoteChangeSet,
        mergeEngine: SyncMergeEngine
    ) throws -> SyncFetchSummary {
        for change in changeSet.workspaceChanges {
            try applyRemoteUpsert(entityType: "workspace", entityID: change.workspaceID) {
                try mergeEngine.applyRemoteWorkspace(change)
            }
        }
        for change in changeSet.notebookChanges {
            try applyRemoteUpsert(entityType: "notebook", entityID: change.notebookID) {
                try mergeEngine.applyRemoteNotebook(change)
            }
        }
        for change in changeSet.pageChanges {
            try applyRemoteUpsert(entityType: "page", entityID: change.pageID) {
                try mergeEngine.applyRemotePage(change)
            }
        }
        var skippedRemoteDiaryPageCount = 0
        for change in changeSet.diaryPageChanges {
            guard try syncRepository.pageRecordExists(pageID: change.pageID) else {
                skippedRemoteDiaryPageCount += 1
                recordRuntimeDiagnostic(
                    eventName: "remote_diary_page_skipped_missing_page",
                    payloadJSON: Self.diagnosticPayloadJSON([
                        "page_id": change.pageID,
                        "workspace_id": change.workspaceID,
                        "diary_date": change.diaryDate
                    ])
                )
                EditorLog.sync.error(
                    "sync_remote_diary_page_skipped_missing_page page_id=\(change.pageID, privacy: .public) workspace_id=\(change.workspaceID, privacy: .public) diary_date=\(change.diaryDate, privacy: .public)"
                )
                continue
            }
            try applyRemoteUpsert(entityType: "diaryPage", entityID: change.pageID) {
                try mergeEngine.applyRemoteDiaryPage(change)
            }
        }
        var skippedRemotePageVersionCount = 0
        for change in changeSet.pageVersionChanges {
            guard try syncRepository.pageRecordExists(pageID: change.pageID) else {
                skippedRemotePageVersionCount += 1
                recordRuntimeDiagnostic(
                    eventName: "remote_page_version_skipped_missing_page",
                    payloadJSON: Self.diagnosticPayloadJSON([
                        "version_id": change.versionID,
                        "page_id": change.pageID
                    ])
                )
                EditorLog.sync.error(
                    "sync_remote_page_version_skipped_missing_page version_id=\(change.versionID, privacy: .public) page_id=\(change.pageID, privacy: .public)"
                )
                continue
            }
            try applyRemoteUpsert(entityType: "pageVersion", entityID: change.versionID) {
                try mergeEngine.applyRemotePageVersion(change)
            }
        }
        var skippedRemoteTagCount = 0
        for change in RemoteTagChangeDependencySorter.sorted(changeSet.tagChanges) {
            guard try syncRepository.workspaceRecordExists(workspaceID: change.workspaceID) else {
                skippedRemoteTagCount += 1
                recordRuntimeDiagnostic(
                    eventName: "remote_tag_skipped_missing_workspace",
                    payloadJSON: Self.diagnosticPayloadJSON([
                        "tag_id": change.tagID,
                        "workspace_id": change.workspaceID
                    ])
                )
                EditorLog.sync.error(
                    "sync_remote_tag_skipped_missing_workspace tag_id=\(change.tagID, privacy: .public) workspace_id=\(change.workspaceID, privacy: .public)"
                )
                continue
            }
            if let parentTagID = change.parentTagID,
               try !syncRepository.tagRecordExists(tagID: parentTagID) {
                skippedRemoteTagCount += 1
                recordRuntimeDiagnostic(
                    eventName: "remote_tag_skipped_missing_parent",
                    payloadJSON: Self.diagnosticPayloadJSON([
                        "tag_id": change.tagID,
                        "parent_tag_id": parentTagID,
                        "workspace_id": change.workspaceID
                    ])
                )
                EditorLog.sync.error(
                    "sync_remote_tag_skipped_missing_parent tag_id=\(change.tagID, privacy: .public) parent_tag_id=\(parentTagID, privacy: .public) workspace_id=\(change.workspaceID, privacy: .public)"
                )
                continue
            }
            try applyRemoteUpsert(entityType: "tag", entityID: change.tagID) {
                try mergeEngine.applyRemoteTag(change)
            }
        }
        for change in changeSet.pageTagChanges {
            try applyRemoteUpsert(entityType: "pageTag", entityID: change.entityID) {
                try mergeEngine.applyRemotePageTag(change)
            }
        }
        for change in changeSet.attachmentChanges {
            try applyRemoteUpsert(entityType: "attachment", entityID: change.attachmentID) {
                try mergeEngine.applyRemoteAttachment(change)
            }
        }
        var remotePageUpdatedAtByID: [String: String] = [:]
        for change in changeSet.pageChanges {
            if let updatedAt = change.updatedAt {
                remotePageUpdatedAtByID[change.pageID] = updatedAt
            }
        }
        var pageOrder: [String] = []
        var blockChangesByPageID: [String: [RemoteBlockChange]] = [:]
        for change in RemoteBlockChangeDependencySorter.sorted(changeSet.blockChanges) {
            if blockChangesByPageID[change.pageID] == nil {
                pageOrder.append(change.pageID)
            }
            blockChangesByPageID[change.pageID, default: []].append(change)
        }
        for pageID in changeSet.fullSnapshotPageIDs.sorted()
            where blockChangesByPageID[pageID] == nil {
            pageOrder.append(pageID)
            blockChangesByPageID[pageID] = []
        }
        var skippedRemoteBlockCount = 0
        for pageID in pageOrder {
            let pageBlockChanges = blockChangesByPageID[pageID] ?? []
            guard try syncRepository.pageExists(pageID: pageID) else {
                skippedRemoteBlockCount += pageBlockChanges.count
                EditorLog.sync.error(
                    "sync_remote_blocks_skipped_missing_page page_id=\(pageID, privacy: .public) remote_blocks=\(pageBlockChanges.count, privacy: .public) full_snapshot=\(changeSet.fullSnapshotPageIDs.contains(pageID), privacy: .public)"
                )
                continue
            }

            if changeSet.fullSnapshotPageIDs.contains(pageID) {
                try applyRemoteChange(
                    entityType: "pageSnapshot",
                    entityID: pageID,
                    details: "blocks=\(pageBlockChanges.count)"
                ) {
                    try mergeEngine.applyRemoteBlockPageSnapshot(
                        pageID: pageID,
                        changes: pageBlockChanges,
                        remoteUpdatedAt: remotePageUpdatedAtByID[pageID] ?? Self.latestUpdatedAt(in: pageBlockChanges)
                    )
                }
                for change in pageBlockChanges {
                    try syncRepository.markRemoteApplied(
                        entityType: "block",
                        entityID: change.blockID,
                        recordName: Self.remoteRecordName(entityType: "block", entityID: change.blockID)
                    )
                }
                continue
            }

            for change in pageBlockChanges {
                try applyRemoteUpsert(
                    entityType: "block",
                    entityID: change.blockID,
                    details: "page_id=\(change.pageID) parent_block_id=\(change.parentBlockID ?? "nil")"
                ) {
                    try mergeEngine.applyRemoteBlock(change)
                }
            }
        }
        for deletion in changeSet.deletedRecords {
            try applyRemoteDeletion(entityType: deletion.entityType, entityID: deletion.entityID) {
                try mergeEngine.applyRemoteDeletion(deletion)
            }
        }
        return SyncFetchSummary(
            appliedCount: changeSet.workspaceChanges.count
                + changeSet.notebookChanges.count
                + changeSet.pageChanges.count
                + changeSet.diaryPageChanges.count
                - skippedRemoteDiaryPageCount
                + changeSet.pageVersionChanges.count
                - skippedRemotePageVersionCount
                + changeSet.tagChanges.count
                - skippedRemoteTagCount
                + changeSet.pageTagChanges.count
                + changeSet.attachmentChanges.count
                + changeSet.blockChanges.count
                - skippedRemoteBlockCount
                + changeSet.deletedRecords.count,
            hasMoreChanges: changeSet.hasMoreChanges
        )
    }

    private func applyRemoteUpsert(
        entityType: String,
        entityID: String,
        details: String? = nil,
        apply: () throws -> Void
    ) throws {
        try applyRemoteChange(
            entityType: entityType,
            entityID: entityID,
            details: details,
            apply: apply
        )
        try syncRepository.markRemoteApplied(
            entityType: entityType,
            entityID: entityID,
            recordName: Self.remoteRecordName(entityType: entityType, entityID: entityID)
        )
    }

    private func applyRemoteDeletion(
        entityType: String,
        entityID: String,
        apply: () throws -> Void
    ) throws {
        try applyRemoteChange(entityType: entityType, entityID: entityID, apply: apply)
        try syncRepository.forgetRemoteApplied(entityType: entityType, entityID: entityID)
    }

    private func applyRemoteChange(
        entityType: String,
        entityID: String,
        details: String? = nil,
        apply: () throws -> Void
    ) throws {
        do {
            try apply()
        } catch {
            let applyError = SyncRemoteApplyError(
                entityType: entityType,
                entityID: entityID,
                details: details,
                underlyingDescription: String(describing: error)
            )
            EditorLog.sync.error("\(applyError.description, privacy: .public)")
            throw applyError
        }
    }

    private static func isServerChangeTokenExpiredError(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == CKErrorDomain
            && nsError.code == CKError.changeTokenExpired.rawValue
    }

    private static func latestUpdatedAt(in changes: [RemoteBlockChange]) -> String? {
        changes.compactMap(\.updatedAt).max()
    }

    private static func remoteRecordName(entityType: String, entityID: String) -> String {
        "\(CloudKitSyncGeneration.current).\(entityType).\(entityID)"
    }

    private static func diagnosticPayloadJSON(_ payload: [String: Any]) -> String {
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    @discardableResult
    func uploadPendingChanges() throws -> SyncUploadSummary {
        let repairedLegacyCreateCount = try syncRepository.repairLegacySnapshotBackfillCreateBacklog(
            legacyScope: Self.legacyCurrentGenerationSnapshotBackfillScope,
            recordNamePrefix: "\(CloudKitSyncGeneration.current)."
        )
        if repairedLegacyCreateCount > 0 {
            recordRuntimeDiagnostic(
                eventName: "foreground_sync_legacy_snapshot_backlog_repaired",
                payloadJSON: "{\"repaired_count\":\(repairedLegacyCreateCount)}"
            )
        }
        try syncRepository.enqueueUnsyncedLocalRecords()
        let changes = prioritizedUploadChanges(try syncRepository.pendingChanges())
        var uploadedCount = 0
        var failedCount = 0
        var attemptedCount = 0
        struct PendingUpload {
            let change: SyncChange
            let currentDate: Date
            let retryState: SyncRetryState
        }
        var readyBatch: [PendingUpload] = []

        func handleUploadedChange(_ change: SyncChange, uploadResult: CloudKitUploadResult) throws -> String? {
            try syncRepository.markUploaded(change: change, uploadResult: uploadResult)
            uploadedCount += 1
            EditorLog.sync.debug(
                "sync_change_uploaded entity_type=\(change.entityType, privacy: .public) entity_id=\(change.entityID, privacy: .public)"
            )
            if change.entityType == "block" {
                return try syncRepository.pageIDForBlock(blockID: change.entityID)
            }
            return nil
        }

        func handleFailedChange(_ pendingUpload: PendingUpload, error: Error) throws -> String? {
            let change = pendingUpload.change
            if case CloudKitPrivateDatabaseAdapterError.entityNotFound = error {
                try syncRepository.discard(change: change)
                EditorLog.sync.error(
                    "sync_change_discarded_missing_local_entity entity_type=\(change.entityType, privacy: .public) entity_id=\(change.entityID, privacy: .public) change_type=\(change.changeType, privacy: .public)"
                )
                if change.entityType == "block" {
                    return try syncRepository.pageIDForBlock(blockID: change.entityID)
                }
                return nil
            } else {
                let failureCount = pendingUpload.retryState.attemptCount + 1
                let errorDescription = CloudKitErrorDiagnostic.describe(error)
                try syncRepository.recordFailure(
                    change: change,
                    errorDescription: errorDescription,
                    nextAttemptAt: retryPolicy.nextAttemptDate(afterFailureCount: failureCount, now: pendingUpload.currentDate)
                )
                failedCount += 1
                EditorLog.sync.error(
                    "sync_change_upload_failed entity_type=\(change.entityType, privacy: .public) entity_id=\(change.entityID, privacy: .public) error=\(errorDescription, privacy: .public)"
                )
                return nil
            }
        }

        @discardableResult
        func flushReadyBatch() throws -> Set<String> {
            guard !readyBatch.isEmpty else {
                return []
            }
            let pendingUploads = readyBatch
            readyBatch.removeAll(keepingCapacity: true)
            let batchResult: CloudKitUploadBatchResult
            do {
                batchResult = try adapter.upload(changes: pendingUploads.map(\.change))
            } catch {
                var affectedPageIDs = Set<String>()
                for pendingUpload in pendingUploads {
                    if let pageID = try handleFailedChange(pendingUpload, error: error) {
                        affectedPageIDs.insert(pageID)
                    }
                }
                return affectedPageIDs
            }

            var affectedPageIDs = Set<String>()
            for pendingUpload in pendingUploads {
                let change = pendingUpload.change
                if let uploadResult = batchResult.successes[change] {
                    if let pageID = try handleUploadedChange(change, uploadResult: uploadResult) {
                        affectedPageIDs.insert(pageID)
                    }
                } else if let error = batchResult.failures[change] {
                    if let pageID = try handleFailedChange(pendingUpload, error: error) {
                        affectedPageIDs.insert(pageID)
                    }
                } else if let pageID = try handleFailedChange(
                    pendingUpload,
                    error: CloudKitPrivateDatabaseAdapterError.missingSavedRecord
                ) {
                    affectedPageIDs.insert(pageID)
                }
            }
            return affectedPageIDs
        }

        func enqueueReadyChange(
            _ change: SyncChange,
            currentDate: Date,
            retryState: SyncRetryState
        ) throws {
            readyBatch.append(PendingUpload(
                change: change,
                currentDate: currentDate,
                retryState: retryState
            ))
            if readyBatch.count >= uploadBatchSize {
                try flushReadyBatch()
            }
        }

        for change in changes {
            guard attemptedCount < maximumUploadsPerRun else {
                EditorLog.sync.debug(
                    "sync_upload_run_limit_reached attempted=\(attemptedCount, privacy: .public) limit=\(self.maximumUploadsPerRun, privacy: .public)"
                )
                break
            }
            let retryState = try syncRepository.retryState(change: change)
            let currentDate = now()
            if let nextAttemptAt = retryState.nextAttemptAt,
               nextAttemptAt > currentDate {
                EditorLog.sync.debug(
                    "sync_change_deferred entity_type=\(change.entityType, privacy: .public) entity_id=\(change.entityID, privacy: .public)"
                )
                continue
            }

            try enqueueReadyChange(change, currentDate: currentDate, retryState: retryState)
            attemptedCount += 1
        }
        try flushReadyBatch()
        return SyncUploadSummary(uploadedCount: uploadedCount, failedCount: failedCount)
    }

    private func prioritizedUploadChanges(_ changes: [SyncChange]) -> [SyncChange] {
        changes.enumerated().sorted { first, second in
            let firstPriority = uploadPriority(first.element)
            let secondPriority = uploadPriority(second.element)
            if firstPriority != secondPriority {
                return firstPriority < secondPriority
            }
            return first.offset < second.offset
        }.map(\.element)
    }

    private func uploadPriority(_ change: SyncChange) -> Int {
        if change.changeType == "delete" {
            return 90
        }

        switch change.entityType {
        case "workspace":
            return 0
        case "notebook":
            return 10
        case "tag":
            return 20
        case "page":
            return 30
        case "diaryPage":
            return 40
        case "pageTag":
            return 50
        case "attachment":
            return 60
        case "block":
            return 70
        case "pageVersion":
            return 80
        default:
            return 80
        }
    }
}

extension SyncEngine: @unchecked Sendable {}

extension SyncEngine: RemoteNotificationSyncing {}
