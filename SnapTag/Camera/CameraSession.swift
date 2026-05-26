import AVFoundation
import Combine

/// Wraps AVCaptureSession and publishes raw CMSampleBuffer frames.
/// The actor serialises start/stop calls which are not thread-safe on AVCaptureSession.
actor CameraSession: NSObject {

    // MARK: Public interface

    /// Emits each captured frame. Subscribers should throttle on their own scheduler.
    /// Marked nonisolated because PassthroughSubject is @unchecked Sendable and the
    /// delegate callback already runs off the actor on the capture queue.
    nonisolated let framePublisher = PassthroughSubject<CMSampleBuffer, Never>()

    private(set) var captureSession: AVCaptureSession?
    private(set) var isRunning: Bool = false

    // MARK: Setup

    func configure() throws {
        let session = AVCaptureSession()
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            throw SnapTagError.cameraPermissionDenied
        }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        // Discard late frames rather than block the capture pipeline.
        output.alwaysDiscardsLateVideoFrames = true
        let queue = DispatchQueue(label: "com.ozspidey.SnapTag.captureQueue", qos: .userInitiated)
        output.setSampleBufferDelegate(self, queue: queue)

        guard session.canAddOutput(output) else {
            throw SnapTagError.cameraPermissionDenied
        }
        session.addOutput(output)
        captureSession = session
    }

    func start() {
        guard let session = captureSession, !isRunning else { return }
        session.startRunning()
        isRunning = true
    }

    func stop() {
        guard let session = captureSession, isRunning else { return }
        session.stopRunning()
        isRunning = false
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraSession: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        framePublisher.send(sampleBuffer)
    }
}
