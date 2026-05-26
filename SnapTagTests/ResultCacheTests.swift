import XCTest
@testable import SnapTag

final class ResultCacheTests: XCTestCase {

    private var sut: ResultCache!

    override func setUp() {
        super.setUp()
        sut = ResultCache(countLimit: 10)
    }

    func test_storeAndRetrieve_roundTrips() {
        let image = makeImage()
        let hash  = ImageHash(image)
        let result = makeResult(hash: hash)

        sut.store(result, for: hash)
        let retrieved = sut.result(for: hash)

        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.imageHash.value, hash.value)
    }

    func test_cacheMiss_returnsNil() {
        let hash = ImageHash(makeImage(color: .cyan))
        XCTAssertNil(sut.result(for: hash))
    }

    func test_samePixelContent_producesSameHash() {
        let a = makeImage(color: .red, size: CGSize(width: 50, height: 50))
        let b = makeImage(color: .red, size: CGSize(width: 50, height: 50))
        XCTAssertEqual(ImageHash(a).value, ImageHash(b).value)
    }

    func test_differentImages_produceDifferentHashes() {
        let a = makeImage(color: .red)
        let b = makeImage(color: .blue)
        XCTAssertNotEqual(ImageHash(a).value, ImageHash(b).value)
    }

    func test_evictAll_clearsAllEntries() {
        for i in 0..<5 {
            let image = makeImage(color: UIColor(red: CGFloat(i) / 5, green: 0, blue: 0, alpha: 1),
                                  size: CGSize(width: i + 10, height: i + 10))
            let hash = ImageHash(image)
            sut.store(makeResult(hash: hash), for: hash)
        }
        sut.evictAll()
        // NSCache eviction is best-effort, so we only assert no crash
        XCTAssertNoThrow(sut.evictAll())
    }

    func test_threadSafety_concurrentReadWrite() {
        let cache = ResultCache(countLimit: 500)
        let expectation = expectation(description: "concurrent access")
        expectation.expectedFulfillmentCount = 100

        DispatchQueue.concurrentPerform(iterations: 100) { i in
            let image = self.makeImage(color: UIColor(red: CGFloat(i % 10) / 10, green: 0, blue: 0, alpha: 1),
                                       size: CGSize(width: i + 1, height: i + 1))
            let hash = ImageHash(image)
            cache.store(self.makeResult(hash: hash), for: hash)
            _ = cache.result(for: hash)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
    }

    // MARK: - Helpers

    private func makeImage(color: UIColor = .red, size: CGSize = CGSize(width: 64, height: 64)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func makeResult(hash: ImageHash) -> AnalysisResult {
        AnalysisResult(
            imageHash: hash,
            sceneLabels: [SceneLabel(identifier: "test", confidence: 0.9)],
            detectedObjects: [],
            processingTime: 0.1,
            status: .completed
        )
    }
}
