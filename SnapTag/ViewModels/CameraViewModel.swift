import AVFoundation
import SwiftUI
import Combine

@MainActor
final class CameraViewModel: ObservableObject {

    // MARK: - Published state

    @Published private(set) var liveResult: AnalysisResult?
    @Published private(set) var permissionState: CameraPermissionState = .notDetermined
    @Published private(set) var isSessionRunning: Bool = false
    @Published private(set) var captureSession: AVCaptureSession?
    @Published var errorAlert: SnapTagError?

    let cameraSession: CameraSession

    // MARK: - Private

    private let analyzer: ImageAnalyzer
    private let permissionManager: CameraPermissionManager
    private var cancellables = Set<AnyCancellable>()
    private var analysisTask: Task<Void, Never>?

    // MARK: - Init

    init(analyzer: ImageAnalyzer,
         cameraSession: CameraSession = CameraSession(),
         permissionManager: CameraPermissionManager = CameraPermissionManager()) {
        self.analyzer = analyzer
        self.cameraSession = cameraSession
        self.permissionManager = permissionManager
        self.permissionState = permissionManager.current

        setupFramePipeline()
    }

    // MARK: - Camera lifecycle

    func requestPermissionAndStart() async {
        permissionState = await permissionManager.requestAccess()
        guard permissionState == .granted else { return }
        await startSession()
    }

    func startSession() async {
        do {
            try await cameraSession.configure()
            await cameraSession.start()
            captureSession = await cameraSession.captureSession
            isSessionRunning = true
        } catch {
            errorAlert = error as? SnapTagError ?? .visionRequestFailed(underlying: error)
        }
    }

    func stopSession() async {
        await cameraSession.stop()
        isSessionRunning = false
    }

    // MARK: - Frame pipeline

    private func setupFramePipeline() {
        // Throttle to ~5 fps (200 ms) to stay ahead of Vision without overwhelming it.
        cameraSession.framePublisher
            .throttle(for: .milliseconds(200), scheduler: DispatchQueue.global(qos: .userInitiated), latest: true)
            .compactMap { buffer -> UIImage? in
                guard let imageBuffer = CMSampleBufferGetImageBuffer(buffer) else { return nil }
                let ciImage = CIImage(cvPixelBuffer: imageBuffer)
                let context = CIContext()
                guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
                return UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] image in
                self?.submitFrame(image)
            }
            .store(in: &cancellables)
    }

    private func submitFrame(_ image: UIImage) {
        // Cancel any in-flight analysis — we only care about the latest frame.
        analysisTask?.cancel()
        analysisTask = Task { [weak self] in
            guard let self, !Task.isCancelled else { return }
            if let result = try? await self.analyzer.analyze(image) {
                self.liveResult = result
            }
        }
    }
}
