import SwiftUI

// MARK: - Scene Classification

struct SceneLabel: Identifiable, Sendable {
    let id = UUID()
    let identifier: String
    let confidence: Float

    var displayName: String {
        identifier
            .split(separator: ",")
            .first
            .map { String($0).capitalized }
            ?? identifier.capitalized
    }

    var confidencePercent: Int { Int(confidence * 100) }
}

// MARK: - Object Detection

struct DetectedObject: Identifiable, Sendable {
    let id = UUID()
    let label: String
    let confidence: Float
    /// Normalised bounding box in Vision coordinate space (origin bottom-left, 0–1).
    let boundingBox: CGRect
    let color: Color

    var confidencePercent: Int { Int(confidence * 100) }
}

// MARK: - Analysis Result

enum AnalysisStatus: Sendable {
    case idle
    case analyzing
    case completed
    case failed(SnapTagError)
}

struct AnalysisResult: Sendable {
    let imageHash: ImageHash
    let sceneLabels: [SceneLabel]      // sorted descending by confidence
    let detectedObjects: [DetectedObject]
    let processingTime: TimeInterval   // seconds
    let status: AnalysisStatus

    static let empty = AnalysisResult(
        imageHash: ImageHash(UIImage()),
        sceneLabels: [],
        detectedObjects: [],
        processingTime: 0,
        status: .idle
    )
}

// MARK: - Batch Item

struct BatchItem: Identifiable, Sendable {
    let id = UUID()
    let image: UIImage
    var result: AnalysisResult?
    var isProcessing: Bool = false
}
