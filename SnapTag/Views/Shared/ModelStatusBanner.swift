import SwiftUI

/// Shows a non-blocking degraded-mode warning when YOLOv3Tiny is absent.
/// Scene classification still works; only object detection is unavailable.
struct ModelStatusBanner: View {
    let state: ModelState

    var body: some View {
        switch state {
        case .notFound:
            banner(
                icon: "exclamationmark.triangle.fill",
                colour: .orange,
                message: "Object detection unavailable — YOLOv3Tiny.mlmodelc not found. See README."
            )
        case .failed:
            banner(
                icon: "xmark.octagon.fill",
                colour: .red,
                message: "Core ML model failed to load. Scene classification only."
            )
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func banner(icon: String, colour: Color, message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(colour)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
    }
}
