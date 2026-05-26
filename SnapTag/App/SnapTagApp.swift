import SwiftUI

@main
struct SnapTagApp: App {
    @StateObject private var environment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(environment.analysisViewModel)
                .environmentObject(environment.cameraViewModel)
        }
    }
}
