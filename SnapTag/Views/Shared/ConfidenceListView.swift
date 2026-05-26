import SwiftUI

struct ConfidenceListView: View {
    let labels: [SceneLabel]
    var maxItems: Int = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Scene Classification")
                .font(.headline)
                .padding(.horizontal)

            if labels.isEmpty {
                Text("No scene detected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                ForEach(labels.prefix(maxItems)) { label in
                    ConfidenceRow(label: label)
                }
            }
        }
    }
}

// MARK: - Row

private struct ConfidenceRow: View {
    let label: SceneLabel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label.displayName)
                    .font(.subheadline)
                    .lineLimit(1)
                Spacer()
                Text("\(label.confidencePercent)%")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemFill))
                        .frame(height: 6)
                    Capsule()
                        .fill(barColor(for: label.confidence))
                        .frame(width: geo.size.width * CGFloat(label.confidence), height: 6)
                        .animation(.spring(duration: 0.4), value: label.confidence)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal)
    }

    private func barColor(for confidence: Float) -> Color {
        switch confidence {
        case 0.75...: return .green
        case 0.4..<0.75: return .orange
        default: return .red
        }
    }
}
