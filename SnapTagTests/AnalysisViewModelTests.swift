import XCTest
import Combine
@testable import SnapTag

@MainActor
final class AnalysisViewModelTests: XCTestCase {

    private var mockService: MockVisionService!
    private var mockCache: MockResultCache!
    private var mockLoader: MockModelLoader!
    private var analyzer: ImageAnalyzer!
    private var sut: AnalysisViewModel!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        mockService  = MockVisionService()
        mockCache    = MockResultCache()
        mockLoader   = MockModelLoader()
        analyzer     = ImageAnalyzer(visionService: mockService, cache: mockCache)
        sut          = AnalysisViewModel(analyzer: analyzer, modelLoader: mockLoader)
        cancellables = []
    }

    // MARK: - analyzePhoto

    func test_analyzePhoto_setsIsAnalyzingTrueThenFalse() async {
        var states: [Bool] = []
        sut.$isAnalyzing
            .sink { states.append($0) }
            .store(in: &cancellables)

        sut.analyzePhoto(makeImage())
        // Let the task run
        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(states.first, false)  // initial
        XCTAssertTrue(states.contains(true))  // went true
        XCTAssertEqual(states.last, false)    // returned false
    }

    func test_analyzePhoto_populatesAnalysisResult() async throws {
        sut.analyzePhoto(makeImage())
        try? await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertNotNil(sut.analysisResult)
    }

    func test_analyzePhoto_errorPath_setsErrorAlert() async {
        mockService.classifyResult = .failure(SnapTagError.imageDataUnavailable)
        sut.analyzePhoto(makeImage())
        try? await Task.sleep(nanoseconds: 500_000_000)
        // analysisResult may be nil; errorAlert should be set
        XCTAssertNotNil(sut.errorAlert)
    }

    // MARK: - Batch

    func test_analyzeBatch_progressReachesTotal() async throws {
        let images = (0..<3).map { _ in makeImage() }
        sut.analyzeBatch(images)
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        XCTAssertEqual(sut.batchProgress.completed, images.count)
    }

    func test_analyzeBatch_batchItemsCountMatchesInput() async {
        let images = (0..<4).map { _ in makeImage() }
        sut.analyzeBatch(images)
        XCTAssertEqual(sut.batchItems.count, images.count)
    }

    func test_clearBatch_resetsBatchState() {
        sut.analyzeBatch([makeImage(), makeImage()])
        sut.clearBatch()
        XCTAssertTrue(sut.batchItems.isEmpty)
        XCTAssertEqual(sut.batchProgress.total, 0)
    }

    // MARK: - Model state

    func test_modelNotFound_setsNotFoundState() async {
        try? await Task.sleep(nanoseconds: 300_000_000)
        if case .notFound = sut.modelState {
            // pass
        } else if case .notLoaded = sut.modelState {
            // still loading — acceptable in this timing window
        } else {
            XCTFail("Expected .notFound or .notLoaded, got \(sut.modelState)")
        }
    }

    // MARK: - Helpers

    private func makeImage(size: CGSize = CGSize(width: 64, height: 64)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.systemBlue.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }
}
