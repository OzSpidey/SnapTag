import Foundation
@testable import SnapTag

final class MockVisionService: VisionServiceProtocol, @unchecked Sendable {

    // Configurable stubs
    var classifyResult: Result<[SceneLabel], Error> = .success([
        SceneLabel(identifier: "outdoor, field", confidence: 0.92),
        SceneLabel(identifier: "sky", confidence: 0.76)
    ])
    var detectResult: Result<[DetectedObject], Error> = .success([])

    // Call counters
    private(set) var classifyCallCount = 0
    private(set) var detectCallCount = 0

    func classifyScene(imageData: Data) async throws -> [SceneLabel] {
        classifyCallCount += 1
        return try classifyResult.get()
    }

    func detectObjects(imageData: Data) async throws -> [DetectedObject] {
        detectCallCount += 1
        return try detectResult.get()
    }
}
