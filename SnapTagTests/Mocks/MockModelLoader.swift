import Vision
@testable import SnapTag

actor MockModelLoader: ModelLoaderProtocol {
    var stubbedResult: Result<VNCoreMLModel, SnapTagError> = .failure(.modelNotFound(name: "YOLOv3Tiny"))
    private(set) var callCount = 0

    func loadYOLO() async -> Result<VNCoreMLModel, SnapTagError> {
        callCount += 1
        return stubbedResult
    }
}
