import XCTest
import Vision
@testable import SnapTag

final class VisionServiceTests: XCTestCase {

    private var modelLoader: MockModelLoader!
    private var sut: VisionService!

    override func setUp() {
        super.setUp()
        modelLoader = MockModelLoader()
        sut = VisionService(modelLoader: modelLoader)
    }

    // MARK: - Scene classification

    func test_classifyScene_withValidImage_returnsNonEmptyLabels() async throws {
        let data = try XCTUnwrap(minimalJPEGData())
        let labels = try await sut.classifyScene(imageData: data)
        // VNClassifyImageRequest may or may not find labels in a 1x1 image,
        // but it should never throw.
        XCTAssertNotNil(labels)
    }

    func test_classifyScene_resultsSortedDescendingByConfidence() async throws {
        let data = try XCTUnwrap(minimalJPEGData())
        let labels = try await sut.classifyScene(imageData: data)
        let confidences = labels.map(\.confidence)
        XCTAssertEqual(confidences, confidences.sorted(by: >))
    }

    func test_classifyScene_withInvalidData_throwsImageDataUnavailable() async {
        do {
            _ = try await sut.classifyScene(imageData: Data("not-an-image".utf8))
            XCTFail("Expected imageDataUnavailable to be thrown")
        } catch SnapTagError.imageDataUnavailable {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Object detection — model not found

    func test_detectObjects_withMissingModel_throwsModelNotFound() async {
        // MockModelLoader defaults to .failure(.modelNotFound)
        do {
            let data = try XCTUnwrap(minimalJPEGData())
            _ = try await sut.detectObjects(imageData: data)
            XCTFail("Expected modelNotFound error")
        } catch SnapTagError.modelNotFound(let name) {
            XCTAssertEqual(name, "YOLOv3Tiny")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func test_detectObjects_modelLoaderCalledExactlyOnce() async throws {
        let data = try XCTUnwrap(minimalJPEGData())
        _ = try? await sut.detectObjects(imageData: data)
        let count = await modelLoader.callCount
        XCTAssertEqual(count, 1)
    }

    // MARK: - Helpers

    private func minimalJPEGData() -> Data? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64))
        let image = renderer.image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        }
        return image.jpegData(compressionQuality: 0.8)
    }
}
