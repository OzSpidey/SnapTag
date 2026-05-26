import SwiftUI
import AVFoundation

struct CameraView: View {
    @EnvironmentObject private var vm: CameraViewModel

    var body: some View {
        ZStack {
            cameraContent
        }
        .ignoresSafeArea(edges: .top)
        .task {
            if vm.permissionState == .notDetermined {
                await vm.requestPermissionAndStart()
            } else if vm.permissionState == .granted {
                await vm.startSession()
            }
        }
        .onDisappear {
            Task { await vm.stopSession() }
        }
        .alert(item: Binding(
            get: { vm.errorAlert.map(AlertWrapper.init) },
            set: { if $0 == nil { vm.errorAlert = nil } }
        )) { wrapper in
            Alert(title: Text("Camera Error"),
                  message: Text(wrapper.error.localizedDescription ?? ""),
                  dismissButton: .default(Text("OK")))
        }
    }

    // MARK: - Camera content

    @ViewBuilder
    private var cameraContent: some View {
        switch vm.permissionState {
        case .denied:
            permissionDeniedView
        case .notDetermined:
            ProgressView("Requesting camera access…")
        case .granted:
            liveView
        }
    }

    private var liveView: some View {
        GeometryReader { geo in
            ZStack {
                if let session = await vm.cameraSession.captureSession {
                    CameraPreviewLayer(session: session)
                }

                // Bounding box overlay over the live feed
                if let result = vm.liveResult, !result.detectedObjects.isEmpty {
                    BoundingBoxOverlay(
                        objects: result.detectedObjects,
                        imageFrame: CGRect(origin: .zero, size: geo.size)
                    )
                }

                // Scene classification panel at the bottom
                VStack {
                    Spacer()
                    if let result = vm.liveResult, !result.sceneLabels.isEmpty {
                        liveLabelsPanel(result.sceneLabels)
                    }
                }
            }
        }
    }

    private func liveLabelsPanel(_ labels: [SceneLabel]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(labels.prefix(3)) { label in
                HStack {
                    Text(label.displayName)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(label.confidencePercent)%")
                        .font(.subheadline.monospacedDigit())
                }
                .foregroundStyle(.white)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding()
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.slash.fill")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
            Text("Camera Access Required")
                .font(.title3.weight(.semibold))
            Text("Enable camera access in Settings to use live scene detection.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// MARK: - Alert wrapper

private struct AlertWrapper: Identifiable {
    let error: SnapTagError
    var id: String { error.localizedDescription ?? "error" }
}
