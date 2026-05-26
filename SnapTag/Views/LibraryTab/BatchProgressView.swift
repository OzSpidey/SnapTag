import SwiftUI

struct BatchProgressView: View {
    let progress: BatchProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Processing batch")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(progress.completed) / \(progress.total)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: progress.fraction)
                .tint(.blue)
                .animation(.linear(duration: 0.15), value: progress.fraction)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
    }
}
