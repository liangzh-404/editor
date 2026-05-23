import Foundation
import Vision

final class VisionImageTextRecognizer: ImageTextRecognizing, @unchecked Sendable {
    private let recognitionLevel: VNRequestTextRecognitionLevel
    private let usesLanguageCorrection: Bool

    init(
        recognitionLevel: VNRequestTextRecognitionLevel = .accurate,
        usesLanguageCorrection: Bool = true
    ) {
        self.recognitionLevel = recognitionLevel
        self.usesLanguageCorrection = usesLanguageCorrection
    }

    func recognizeText(in imageURL: URL) throws -> [AttachmentRecognizedTextObservation] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = recognitionLevel
        request.usesLanguageCorrection = usesLanguageCorrection

        let handler = VNImageRequestHandler(url: imageURL, options: [:])
        try handler.perform([request])

        return (request.results ?? []).compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else {
                return nil
            }
            let box = observation.boundingBox
            return AttachmentRecognizedTextObservation(
                text: candidate.string,
                confidence: Double(candidate.confidence),
                boundingBox: AttachmentRecognizedTextBoundingBox(
                    x: Double(box.origin.x),
                    y: Double(box.origin.y),
                    width: Double(box.width),
                    height: Double(box.height)
                )
            )
        }
    }
}
