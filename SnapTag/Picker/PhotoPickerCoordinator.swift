import PhotosUI
import SwiftUI

/// UIViewControllerRepresentable wrapper for PHPickerViewController.
/// Supports single and multi-image selection; delivers UIImage values via a binding.
struct PhotoPicker: UIViewControllerRepresentable {

    @Binding var selectedImages: [UIImage]
    var selectionLimit: Int = 10

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = selectionLimit
        config.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    // MARK: - Coordinator

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let parent: PhotoPicker

        init(_ parent: PhotoPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard !results.isEmpty else { return }

            let group = DispatchGroup()
            var images: [(Int, UIImage)] = []
            let lock = NSLock()

            for (index, result) in results.enumerated() {
                guard result.itemProvider.canLoadObject(ofClass: UIImage.self) else { continue }
                group.enter()
                result.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                    defer { group.leave() }
                    if let image = object as? UIImage {
                        lock.withLock { images.append((index, image)) }
                    }
                }
            }

            group.notify(queue: .main) { [weak self] in
                self?.parent.selectedImages = images
                    .sorted { $0.0 < $1.0 }
                    .map(\.1)
            }
        }
    }
}
