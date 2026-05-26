import UIKit

// MARK: - Batch progress

struct BatchProgress: Sendable {
    let completed: Int
    let total: Int
    var fraction: Double { total > 0 ? Double(completed) / Double(total) : 0 }
}

// MARK: - ImageAnalyzer

/// Orchestrates scene classification + object detection for single images and batches.
/// Checks the cache before invoking Vision; stores results after processing.
/// This type is `nonisolated` — it is called from `@MainActor` ViewModels and
/// dispatches work into the `VisionService` actor automatically.
final class ImageAnalyzer: Sendable {

    private let visionService: VisionServiceProtocol
    private let cache: ResultCacheProtocol

    init(visionService: VisionServiceProtocol, cache: ResultCacheProtocol) {
        self.visionService = visionService
        self.cache = cache
    }

    // MARK: - Single image

    func analyze(_ image: UIImage) async throws -> AnalysisResult {
        let hash = ImageHash(image)

        if let cached = cache.result(for: hash) {
            return cached
        }

        guard let data = image.jpegData(compressionQuality: 1.0) else {
            throw SnapTagError.imageDataUnavailable
        }

        let start = Date()

        // Run classification and detection concurrently.
        async let labels  = try visionService.classifyScene(imageData: data)
        async let objects = detectObjectsOrEmpty(imageData: data)

        let result = AnalysisResult(
            imageHash: hash,
            sceneLabels:     try await labels,
            detectedObjects: await objects,
            processingTime:  Date().timeIntervalSince(start),
            status:          .completed
        )

        cache.store(result, for: hash)
        return result
    }

    // MARK: - Batch

    /// Processes multiple images concurrently. Each image runs in its own Task inside a
    /// TaskGroup so the group never blocks on a single slow image. Results are returned
    /// in the original input order regardless of completion order.
    ///
    /// - Parameter onProgress: Called on a background executor after each image completes.
    func analyzeBatch(
        _ images: [UIImage],
        onProgress: @Sendable (BatchProgress) -> Void = { _ in }
    ) async -> (results: [AnalysisResult?], succeeded: Int, failed: Int) {

        var ordered = [AnalysisResult?](repeating: nil, count: images.count)
        var succeeded = 0
        var failed = 0

        await withTaskGroup(of: (Int, Result<AnalysisResult, Error>).self) { group in
            for (index, image) in images.enumerated() {
                group.addTask {
                    do {
                        let result = try await self.analyze(image)
                        return (index, .success(result))
                    } catch {
                        return (index, .failure(error))
                    }
                }
            }

            var completed = 0
            for await (index, outcome) in group {
                completed += 1
                switch outcome {
                case .success(let analysisResult):
                    ordered[index] = analysisResult
                    succeeded += 1
                case .failure:
                    failed += 1
                }
                onProgress(BatchProgress(completed: completed, total: images.count))
            }
        }

        return (ordered, succeeded, failed)
    }

    // MARK: - Private

    /// Object detection is optional — if the model is absent, return empty array
    /// rather than propagating the error (scene classification still works).
    private func detectObjectsOrEmpty(imageData: Data) async -> [DetectedObject] {
        do {
            return try await visionService.detectObjects(imageData: imageData)
        } catch let err as SnapTagError where err.isDegradedMode {
            return []   // model not found — silently degrade
        } catch {
            return []
        }
    }
}
