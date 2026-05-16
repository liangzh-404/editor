import Foundation

protocol AttachmentThumbnailScheduling {
    func scheduleThumbnailGeneration(
        attachmentID: String,
        generate: @escaping @Sendable () throws -> String?,
        completion: @MainActor @escaping @Sendable (Result<String?, Error>) -> Void
    )
}

final class DispatchAttachmentThumbnailScheduler: AttachmentThumbnailScheduling {
    private let queue: DispatchQueue

    init(queue: DispatchQueue = DispatchQueue(label: "editor.attachment.thumbnail", qos: .utility)) {
        self.queue = queue
    }

    func scheduleThumbnailGeneration(
        attachmentID: String,
        generate: @escaping @Sendable () throws -> String?,
        completion: @MainActor @escaping @Sendable (Result<String?, Error>) -> Void
    ) {
        queue.async {
            let result: Result<String?, Error>
            do {
                result = .success(try generate())
            } catch {
                result = .failure(error)
            }

            Task { @MainActor in
                completion(result)
            }
        }
    }
}
