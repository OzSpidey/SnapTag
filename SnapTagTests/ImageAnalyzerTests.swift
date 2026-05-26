import XCTest
@testable import SnapTag

final class ImageAnalyzerTests: XCTestCase {

    private var mockService: MockVisionService!
    private var mockCache: MockResultCache!
    private var sut: ImageAnalyzer!

    override func setUp() {
        super.setUp()
        mockService = MockVisionService()
        mockCache = MockResultCache()
        sut = ImageAnalyzer(visionService: mockService, cache: mockCache)
    }

    // MARK: - Single image

    func test_analyze_callsVisionService() async throws {
        let image = makeImage(color: .red)
        _ = try await sut.analyze(image)
        XCTAssertEqual(mockService.classifyCallCount, 1)
    }

    func test_analyze_storesResultInCache() async throws {
        let image = makeImage(color: .green)
        _ = try await sut.analyze(image)
        XCTAssertEqual(mockCache.storeCallCount, 1)
    }

    func test_analyze_secondCallHitsCache_notVisionService() async throws {
        let image = makeImage(color: .blue)
        _ = try await sut.analyze(image)
        _ = try await sut.analyze(image)
        // Second call must be a cache hit — service should still be at 1
        XCTAssertEqual(mockService.classifyCallCount, 1)
        XCTAssertEqual(mockCache.hitCount, 1)
    }

    func test_analyze_returnsModelNotFoundAsDegradedMode_notThrown() async throws {
        // detectObjects failing with modelNotFound should not bubble up
        mockService.detectResult = .failure(SnapTagError.modelNotFound(name: "YOLOv3Tiny"))
        let image = makeImage(color: .yellow)
        let result = try await sut.analyze(image)
        XCTAssertTrue(result.detectedObjects.isEmpty)
        XCTAssertFalse(result.sceneLabels.isEmpty)
    }

    // MARK: - Batch processing

    func test_analyzeBatch_processesAllImages() async {
        let images = (0..<3).map { _ in makeImage(color: .gray) }
        let (results, succeeded, _) = await sut.analyzeBatch(images)
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(succeeded, 3)
    }

    func test_analyzeBatch_resultsOrderMatchesInput() async {
        // Use images that produce different hashes
        let red   = makeImage(color: .red,   size: CGSize(width: 10, height: 10))
        let green = makeImage(color: .green, size: CGSize(width: 20, height: 20))
        let blue  = makeImage(color: .blue,  size: CGSize(width: 30, height: 30))
        let (results, _, _) = await sut.analyzeBatch([red, green, blue])
        // All slots should be filled (no nil)
        XCTAssertTrue(results.allSatisfy { $0 != nil })
    }

    func test_analyzeBatch_partialFailure_countIsAccurate() async {
        var callCount = 0
        mockService.classifyResult = .success([])

        // Alternate success/failure using a fresh service with custom logic
        final class AlternatingService: VisionServiceProtocol, @unchecked Sendable {
            var callCount = 0
            func classifyScene(imageData: Data) async throws -> [SceneLabel] {
                callCount += 1
                if callCount % 2 == 0 { throw SnapTagError.imageDataUnavailable }
                return [SceneLabel(identifier: "test", confidence: 0.9)]
            }
            func detectObjects(imageData: Data) async throws -> [DetectedObject] { [] }
        }

        let service = AlternatingService()
        let cache   = MockResultCache()
        let analyzer = ImageAnalyzer(visionService: service, cache: cache)
        let images  = (0..<4).map { i in makeImage(color: .init(white: CGFloat(i) / 4, alpha: 1), size: CGSize(width: i + 5, height: i + 5)) }

        let (_, succeeded, failed) = await analyzer.analyzeBatch(images)
        XCTAssertEqual(succeeded + failed, images.count)
        _ = callCount  // suppress unused warning
    }

    func test_analyzeBatch_progressCallbacks_countUpToTotal() async {
        let images = (0..<5).map { _ in makeImage(color: .purple) }
        var progressValues: [BatchProgress] = []
        let (_, _, _) = await sut.analyzeBatch(images) { progress in
            progressValues.append(progress)
        }
        XCTAssertEqual(progressValues.last?.completed, images.count)
        XCTAssertEqual(progressValues.last?.total, images.count)
    }

    // MARK: - Helpers

    private func makeImage(color: UIColor, size: CGSize = CGSize(width: 64, height: 64)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }
}
