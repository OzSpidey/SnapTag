import Vision
import CoreML

// MARK: - Protocol

protocol ModelLoaderProtocol: Sendable {
    /// Returns the compiled YOLOv3Tiny model, or `.failure(.modelNotFound)` if the
    /// .mlmodelc bundle is absent from the app's main bundle.
    func loadYOLO() async -> Result<VNCoreMLModel, SnapTagError>
}

// MARK: - Model state

enum ModelState: Sendable {
    case notLoaded
    case loading
    case loaded(VNCoreMLModel)
    case notFound
    case failed(SnapTagError)
}

// MARK: - Production Implementation

/// Lazily loads YOLOv3Tiny exactly once. Subsequent callers await the same result.
/// The actor serialises concurrent load requests so the model is never initialised twice.
actor ModelLoader: ModelLoaderProtocol {

    private static let modelName = "YOLOv3Tiny"

    private var state: ModelState = .notLoaded
    /// Continuations waiting for the in-flight load to complete.
    private var pendingContinuations: [CheckedContinuation<Result<VNCoreMLModel, SnapTagError>, Never>] = []

    // MARK: - ModelLoaderProtocol

    func loadYOLO() async -> Result<VNCoreMLModel, SnapTagError> {
        switch state {
        case .loaded(let model):
            return .success(model)
        case .notFound:
            return .failure(.modelNotFound(name: Self.modelName))
        case .failed(let err):
            return .failure(err)
        case .loading:
            // Park the caller until the in-flight load resolves.
            return await withCheckedContinuation { continuation in
                pendingContinuations.append(continuation)
            }
        case .notLoaded:
            state = .loading
            let result = await performLoad()
            state = stateFrom(result: result)
            // Resume any callers that arrived while loading.
            for continuation in pendingContinuations {
                continuation.resume(returning: result)
            }
            pendingContinuations.removeAll()
            return result
        }
    }

    // MARK: - Private

    private func performLoad() async -> Result<VNCoreMLModel, SnapTagError> {
        guard let url = Bundle.main.url(forResource: Self.modelName, withExtension: "mlmodelc") else {
            return .failure(.modelNotFound(name: Self.modelName))
        }
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .cpuAndNeuralEngine  // prefer Neural Engine when available
            let mlModel = try MLModel(contentsOf: url, configuration: config)
            let vnModel = try VNCoreMLModel(for: mlModel)
            return .success(vnModel)
        } catch {
            return .failure(.modelLoadFailed(underlying: error))
        }
    }

    private func stateFrom(result: Result<VNCoreMLModel, SnapTagError>) -> ModelState {
        switch result {
        case .success(let model): return .loaded(model)
        case .failure(let err):
            if case .modelNotFound = err { return .notFound }
            return .failed(err)
        }
    }
}
