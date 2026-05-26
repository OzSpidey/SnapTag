import Foundation

enum SnapTagError: Error, LocalizedError, Sendable {
    case modelNotFound(name: String)
    case modelLoadFailed(underlying: Error)
    case visionRequestFailed(underlying: Error)
    case cameraPermissionDenied
    case photoLibraryPermissionDenied
    case imageDataUnavailable
    case batchPartialFailure(succeeded: Int, failed: Int)

    var errorDescription: String? {
        switch self {
        case .modelNotFound(let name):
            return "Core ML model '\(name)' not found. Object detection is unavailable. See README to add the model."
        case .modelLoadFailed(let err):
            return "Failed to load Core ML model: \(err.localizedDescription)"
        case .visionRequestFailed(let err):
            return "Vision analysis failed: \(err.localizedDescription)"
        case .cameraPermissionDenied:
            return "Camera access denied. Enable it in Settings → SnapTag → Camera."
        case .photoLibraryPermissionDenied:
            return "Photo library access denied. Enable it in Settings → SnapTag → Photos."
        case .imageDataUnavailable:
            return "Could not read image data from the selected photo."
        case .batchPartialFailure(let ok, let failed):
            return "Batch complete: \(ok) succeeded, \(failed) failed."
        }
    }

    /// True when the error is non-fatal and the UI should show a degraded-mode banner rather than an alert.
    var isDegradedMode: Bool {
        if case .modelNotFound = self { return true }
        return false
    }
}
