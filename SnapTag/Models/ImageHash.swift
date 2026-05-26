import UIKit
import CryptoKit

/// Deterministic cache key derived from image pixel content.
/// Uses SHA-256 of a 0.5-quality JPEG representation — fast and stable
/// across different UIImage instances with identical pixels.
struct ImageHash: Hashable, Sendable {
    let value: String

    init(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.5) else {
            // Fallback: random key so the image is never incorrectly cache-hit
            value = UUID().uuidString
            return
        }
        value = SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
