import Vision
import UIKit
import SwiftUI

// MARK: - Protocol

protocol VisionServiceProtocol: Sendable {
    func classifyScene(imageData: Data) async throws -> [SceneLabel]
    func detectObjects(imageData: Data) async throws -> [DetectedObject]
}

// MARK: - Production Implementation

/// All Vision requests are created and executed inside this actor,
/// satisfying Vision's requirement that VNRequest objects not be shared across threads.
actor VisionService: VisionServiceProtocol {

    private let modelLoader: ModelLoaderProtocol

    /// Palette for assigning distinct colours to bounding box labels.
    private static let boxColours: [String] = [
        "#FF3B30", "#FF9500", "#FFCC00", "#34C759",
        "#5AC8FA", "#007AFF", "#5856D6", "#FF2D55"
    ]

    init(modelLoader: ModelLoaderProtocol) {
        self.modelLoader = modelLoader
    }

    // MARK: Scene Classification

    func classifyScene(imageData: Data) async throws -> [SceneLabel] {
        guard let cgImage = UIImage(data: imageData)?.cgImage else {
            throw SnapTagError.imageDataUnavailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNClassifyImageRequest { request, error in
                if let error {
                    continuation.resume(throwing: SnapTagError.visionRequestFailed(underlying: error))
                    return
                }
                let observations = (request.results as? [VNClassificationObservation]) ?? []
                let labels = observations
                    .filter { $0.confidence > 0.05 }   // drop noise below 5 %
                    .prefix(10)
                    .map { SceneLabel(identifier: $0.identifier, confidence: $0.confidence) }
                    .sorted { $0.confidence > $1.confidence }
                continuation.resume(returning: Array(labels))
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: SnapTagError.visionRequestFailed(underlying: error))
            }
        }
    }

    // MARK: Object Detection

    func detectObjects(imageData: Data) async throws -> [DetectedObject] {
        let modelResult = await modelLoader.loadYOLO()
        switch modelResult {
        case .failure(let err):
            throw err
        case .success(let coreMLModel):
            return try await runObjectDetection(imageData: imageData, model: coreMLModel)
        }
    }

    // MARK: Private

    private func runObjectDetection(imageData: Data, model: VNCoreMLModel) async throws -> [DetectedObject] {
        guard let cgImage = UIImage(data: imageData)?.cgImage else {
            throw SnapTagError.imageDataUnavailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNCoreMLRequest(model: model) { [weak self] request, error in
                if let error {
                    continuation.resume(throwing: SnapTagError.visionRequestFailed(underlying: error))
                    return
                }
                let observations = (request.results as? [VNRecognizedObjectObservation]) ?? []
                let objects = observations.enumerated().compactMap { index, obs -> DetectedObject? in
                    guard let topLabel = obs.labels.first else { return nil }
                    let colourHex = VisionService.boxColours[index % VisionService.boxColours.count]
                    return DetectedObject(
                        label: topLabel.identifier.capitalized,
                        confidence: topLabel.confidence,
                        boundingBox: obs.boundingBox,
                        color: .init(hex: colourHex)
                    )
                }
                continuation.resume(returning: objects)
            }
            // Scale to fill to handle non-square inputs consistently.
            request.imageCropAndScaleOption = .scaleFill

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: SnapTagError.visionRequestFailed(underlying: error))
            }
        }
    }
}

// MARK: - Color hex initialiser (private utility)

private extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")))
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(
            red:   Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8)  & 0xFF) / 255,
            blue:  Double( rgb        & 0xFF) / 255
        )
    }
}
