import Foundation

struct CloudKitUploadResult: Equatable, Sendable {
    let recordName: String
    let changeTag: String?
}

protocol CloudKitSyncAdapter {
    func upload(change: SyncChange) throws -> CloudKitUploadResult
}

final class SyncEngine {
    private let syncRepository: SyncRepository
    private let adapter: CloudKitSyncAdapter

    init(syncRepository: SyncRepository, adapter: CloudKitSyncAdapter) {
        self.syncRepository = syncRepository
        self.adapter = adapter
    }

    func uploadPendingChanges() throws {
        let changes = try syncRepository.pendingChanges()
        for change in changes {
            let result = try adapter.upload(change: change)
            try syncRepository.markUploaded(change: change, uploadResult: result)
            EditorLog.sync.debug(
                "sync_change_uploaded entity_type=\(change.entityType, privacy: .public) entity_id=\(change.entityID, privacy: .public)"
            )
        }
    }
}
