import SwiftUI
import Combine

@MainActor
final class AnalysisViewModel: ObservableObject {

    // MARK: - Published state

    @Published private(set) var analysisResult: AnalysisResult?
    @Published private(set) var isAnalyzing: Bool = false
    @Published private(set) var batchItems: [BatchItem] = []
    @Published private(set) var batchProgress: BatchProgress = BatchProgress(completed: 0, total: 0)
    @Published private(set) var modelState: ModelState = .notLoaded
    @Published var errorAlert: SnapTagError?

    // MARK: - Dependencies

    private let analyzer: ImageAnalyzer
    private let modelLoader: ModelLoaderProtocol
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(analyzer: ImageAnalyzer, modelLoader: ModelLoaderProtocol) {
        self.analyzer = analyzer
        self.modelLoader = modelLoader
        Task { await prefetchModelState() }
    }

    // MARK: - Single image analysis

    func analyzePhoto(_ image: UIImage) {
        isAnalyzing = true
        analysisResult = nil

        Task {
            defer { isAnalyzing = false }
            do {
                analysisResult = try await analyzer.analyze(image)
            } catch let err as SnapTagError {
                if err.isDegradedMode {
                    // Model not found is handled via the banner; still try classification-only
                    do { analysisResult = try await analyzer.analyze(image) } catch {}
                } else {
                    errorAlert = err
                }
            } catch {
                errorAlert = SnapTagError.visionRequestFailed(underlying: error)
            }
        }
    }

    // MARK: - Batch processing

    func analyzeBatch(_ images: [UIImage]) {
        guard !images.isEmpty else { return }

        batchItems = images.map { BatchItem(image: $0) }
        batchProgress = BatchProgress(completed: 0, total: images.count)
        isAnalyzing = true

        Task {
            defer { isAnalyzing = false }

            let (results, succeeded, failed) = await analyzer.analyzeBatch(images) { [weak self] progress in
                Task { @MainActor [weak self] in
                    self?.batchProgress = progress
                }
            }

            for (index, result) in results.enumerated() {
                batchItems[index].result = result
                batchItems[index].isProcessing = false
            }

            if failed > 0 {
                errorAlert = .batchPartialFailure(succeeded: succeeded, failed: failed)
            }
        }
    }

    func clearBatch() {
        batchItems = []
        batchProgress = BatchProgress(completed: 0, total: 0)
    }

    // MARK: - Private

    private func prefetchModelState() async {
        modelState = .loading
        let result = await modelLoader.loadYOLO()
        switch result {
        case .success(let model): modelState = .loaded(model)
        case .failure(let err):   modelState = err.isDegradedMode ? .notFound : .failed(err)
        }
    }
}
