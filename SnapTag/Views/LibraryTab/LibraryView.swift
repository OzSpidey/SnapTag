import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var vm: AnalysisViewModel

    @State private var selectedImages: [UIImage] = []
    @State private var showPicker = false
    @State private var displayedImage: UIImage?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ModelStatusBanner(state: vm.modelState)

                    // Image display + bounding boxes
                    if let image = displayedImage {
                        ImageAnalysisView(image: image, result: vm.analysisResult)
                    } else {
                        emptyState
                    }

                    // Scene labels
                    if let result = vm.analysisResult {
                        ConfidenceListView(labels: result.sceneLabels)
                            .padding(.top, 8)

                        processingTimeTag(result.processingTime)
                    }

                    // Batch progress + grid
                    if !vm.batchItems.isEmpty {
                        BatchProgressView(progress: vm.batchProgress)
                        BatchResultGrid(items: vm.batchItems) { item in
                            displayedImage = item.image
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("SnapTag")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showPicker = true
                    } label: {
                        Label("Pick Photos", systemImage: "photo.badge.plus")
                    }
                    .disabled(vm.isAnalyzing)

                    if vm.isAnalyzing {
                        ProgressView()
                    }
                }
            }
            .sheet(isPresented: $showPicker) {
                PhotoPicker(selectedImages: $selectedImages)
            }
            .onChange(of: selectedImages) { images in
                guard !images.isEmpty else { return }
                if images.count == 1 {
                    displayedImage = images[0]
                    vm.analyzePhoto(images[0])
                } else {
                    vm.clearBatch()
                    displayedImage = nil
                    vm.analyzeBatch(images)
                }
            }
        }
    }

    // MARK: - Sub-views

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64))
                .foregroundStyle(.quaternary)
            Text("Tap + to pick photos from your library")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    private func processingTimeTag(_ time: TimeInterval) -> some View {
        Text(String(format: "Processed in %.2f s", time))
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(.horizontal)
    }
}

// MARK: - Image + overlay composite

private struct ImageAnalysisView: View {
    let image: UIImage
    let result: AnalysisResult?

    var body: some View {
        GeometryReader { geo in
            let displayRect = aspectFitRect(for: image.size, in: geo.size)
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                if let objects = result?.detectedObjects, !objects.isEmpty {
                    BoundingBoxOverlay(objects: objects, imageFrame: displayRect)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(image.size, contentMode: .fit)
        .padding(.horizontal)
    }

    private func aspectFitRect(for imageSize: CGSize, in viewSize: CGSize) -> CGRect {
        let scale = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let fitted = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: (viewSize.width  - fitted.width)  / 2,
            y: (viewSize.height - fitted.height) / 2,
            width:  fitted.width,
            height: fitted.height
        )
    }
}

// MARK: - Batch result grid

private struct BatchResultGrid: View {
    let items: [BatchItem]
    let onTap: (BatchItem) -> Void

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(items) { item in
                BatchThumb(item: item)
                    .onTapGesture { onTap(item) }
            }
        }
        .padding(.horizontal)
    }
}

private struct BatchThumb: View {
    let item: BatchItem

    var body: some View {
        ZStack {
            Image(uiImage: item.image)
                .resizable()
                .scaledToFill()
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            if item.isProcessing {
                ProgressView()
                    .tint(.white)
                    .padding(4)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            } else if let result = item.result {
                VStack {
                    Spacer()
                    Text(result.sceneLabels.first?.displayName ?? "")
                        .font(.system(size: 9, weight: .semibold))
                        .lineLimit(1)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(4)
                }
            }
        }
    }
}
