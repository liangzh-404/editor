import Foundation

protocol AttachmentTextRecognitionScheduling {
    func scheduleTextRecognition(
        attachmentID: String,
        recognize: @escaping @Sendable () throws -> Void,
        completion: @MainActor @escaping @Sendable (Result<Void, Error>) -> Void
    )
}

final class DispatchAttachmentTextRecognitionScheduler: AttachmentTextRecognitionScheduling {
    private let queue: DispatchQueue

    init(queue: DispatchQueue = DispatchQueue(label: "editor.attachment.text-recognition", qos: .utility)) {
        self.queue = queue
    }

    func scheduleTextRecognition(
        attachmentID: String,
        recognize: @escaping @Sendable () throws -> Void,
        completion: @MainActor @escaping @Sendable (Result<Void, Error>) -> Void
    ) {
        queue.async {
            let result: Result<Void, Error>
            do {
                try recognize()
                result = .success(())
            } catch {
                result = .failure(error)
            }

            Task { @MainActor in
                completion(result)
            }
        }
    }
}
