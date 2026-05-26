import AVFoundation

enum CameraPermissionState: Sendable {
    case notDetermined
    case granted
    case denied
}

final class CameraPermissionManager: Sendable {

    var current: CameraPermissionState {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:          return .granted
        case .notDetermined:       return .notDetermined
        case .denied, .restricted: return .denied
        @unknown default:          return .denied
        }
    }

    func requestAccess() async -> CameraPermissionState {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        return granted ? .granted : .denied
    }
}
