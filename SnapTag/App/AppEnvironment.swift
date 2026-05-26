import Foundation

/// Root dependency graph. Created once at app startup and injected into the SwiftUI environment.
@MainActor
final class AppEnvironment: ObservableObject {

    let modelLoader: ModelLoaderProtocol
    let visionService: VisionServiceProtocol
    let resultCache: ResultCacheProtocol
    let analyzer: ImageAnalyzer

    let analysisViewModel: AnalysisViewModel
    let cameraViewModel: CameraViewModel

    init() {
        let loader  = ModelLoader()
        let service = VisionService(modelLoader: loader)
        let cache   = ResultCache(countLimit: 100)
        let engine  = ImageAnalyzer(visionService: service, cache: cache)

        modelLoader   = loader
        visionService = service
        resultCache   = cache
        analyzer      = engine

        analysisViewModel = AnalysisViewModel(analyzer: engine, modelLoader: loader)
        cameraViewModel   = CameraViewModel(analyzer: engine)
    }
}
