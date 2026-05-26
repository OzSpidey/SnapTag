import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var analysisVM: AnalysisViewModel
    @EnvironmentObject private var cameraVM: CameraViewModel

    var body: some View {
        TabView {
            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "photo.on.rectangle")
                }

            CameraView()
                .tabItem {
                    Label("Camera", systemImage: "camera.viewfinder")
                }
        }
        .alert(item: Binding(
            get: { analysisVM.errorAlert.map(AlertWrapper.init) },
            set: { if $0 == nil { analysisVM.errorAlert = nil } }
        )) { wrapper in
            Alert(
                title: Text("Analysis Error"),
                message: Text(wrapper.error.localizedDescription ?? "Unknown error"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

// MARK: - Alert wrapper (Identifiable bridge)

private struct AlertWrapper: Identifiable {
    let error: SnapTagError
    var id: String { error.localizedDescription ?? "error" }
}
