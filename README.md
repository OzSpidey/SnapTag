# SnapTag — iOS Scene Recognition App

A production-grade iOS app that classifies scenes and detects objects in photos from the camera roll and live camera feed using Apple's **Vision framework** and **Core ML**. Built with Swift 5.9 strict concurrency, SwiftUI, and Combine.

---

## Vision Pipeline Architecture

```
UIImage / CMSampleBuffer
        │
        ▼
 ImageAnalyzer ──────────────────────────────────────────────┐
        │                                                     │
        │  check ImageHash → ResultCache (NSCache)            │
        │  cache miss ↓                                       │
        │                                                     │
        ├─── async let ──→  VisionService (actor)             │
        │                        │                            │
        │             ┌──────────┴──────────┐                 │
        │             ▼                     ▼                 │
        │   VNClassifyImageRequest    VNCoreMLRequest         │
        │   (built-in, no model)      (YOLOv3Tiny)            │
        │             │                     │                 │
        │         [SceneLabel]       [DetectedObject]         │
        │             └──────────┬──────────┘                 │
        │                        ▼                            │
        │                  AnalysisResult ───────────────────►│
        │                                                     │
        └─────────────────────────────────────────────────────┘
                                 │
                                 ▼
                    store in ResultCache (keyed by SHA-256)
                                 │
                    ┌────────────┴────────────┐
                    ▼                         ▼
          AnalysisViewModel            CameraViewModel
          (@MainActor)                 (@MainActor, 5 fps)
                    │                         │
                    ▼                         ▼
             LibraryView               CameraView
          (PHPickerViewController)  (AVCaptureSession)
          BoundingBoxOverlay         BoundingBoxOverlay
          ConfidenceListView         live label panel
```

### Key design decisions

| Decision | Rationale |
|---|---|
| `actor VisionService` | Vision docs forbid sharing `VNRequest` across threads; the actor serialises all request creation and execution |
| `actor ModelLoader` | Prevents double-init races when multiple callers await the first load concurrently |
| `@MainActor` on ViewModels | All `@Published` writes are on the main actor; SwiftUI receives them safely |
| `ENABLE_STRICT_CONCURRENCY_CHECKING=complete` | Catches data races at compile time, not runtime |
| Canvas-based `BoundingBoxOverlay` | Single draw call for all boxes — safe for 20+ simultaneous detections on a live feed |
| NSCache + SHA-256 key | Identical images (e.g. selected twice in batch) are only processed once |
| 200 ms throttle on camera frames | Keeps Vision ahead of the capture queue without GPU saturation |
| `TaskGroup` for batch | Each image is an independent child task; the group collects in completion order and re-sorts by original index |
| XcodeGen `project.yml` | `.xcodeproj` is not committed — no merge conflicts, reproducible CI generation |

---

## Features

- **Photo Library** — multi-select via `PHPickerViewController`; single or batch mode
- **Live Camera** — `AVCaptureSession` at 5 fps with real-time bounding boxes
- **Scene Classification** — `VNClassifyImageRequest` (built-in, no model required); top-10 labels with animated confidence bars
- **Object Detection** — `VNCoreMLRequest` with YOLOv3Tiny; graceful degraded mode when model is absent
- **Bounding Boxes** — `Canvas`-based SwiftUI overlay with Vision → SwiftUI coordinate transform
- **Batch Processing** — `async/await` + `TaskGroup`; live progress bar; per-image results grid
- **Results Cache** — `NSCache` keyed by SHA-256 of JPEG; zero re-processing cost for repeated images
- **Reactive UI** — Combine `PassthroughSubject` for camera frames; `@Published` for all UI state

---

## Requirements

- **Xcode 15+**
- **iOS 16+** (deployment target)
- **Mint** (for XcodeGen)

```bash
brew install mint
```

---

## Setup

### 1. Clone & generate the Xcode project

```bash
git clone https://github.com/OzSpidey/SnapTag.git
cd SnapTag
mint run xcodegen generate
open SnapTag.xcodeproj
```

### 2. (Optional) Add YOLOv3Tiny for object detection

Scene classification works immediately. To enable bounding-box object detection:

1. Download **YOLOv3Tiny.mlmodel** from [Apple's Core ML model gallery](https://developer.apple.com/machine-learning/models/)
2. Compile it:

```bash
xcrun coremlc compile YOLOv3Tiny.mlmodel .
```

3. Drag the resulting **YOLOv3Tiny.mlmodelc** folder into the Xcode project, ensuring it is added to the **SnapTag** target.
4. Build and run.

Without the model the app runs in degraded mode — scene classification is fully functional, and a banner explains that object detection is unavailable.

---

## Project Structure

```
SnapTag/
├── project.yml                          # XcodeGen — run `mint run xcodegen generate` to produce .xcodeproj
├── Mintfile                             # pins XcodeGen version
├── .github/workflows/ci.yml            # GitHub Actions: build + test on macos-14
├── SnapTag/
│   ├── App/
│   │   ├── SnapTagApp.swift            # @main entry point
│   │   └── AppEnvironment.swift        # root dependency graph / DI container
│   ├── Models/
│   │   ├── AnalysisResult.swift        # SceneLabel, DetectedObject, AnalysisResult, BatchItem
│   │   ├── ImageHash.swift             # SHA-256 cache key
│   │   └── SnapTagError.swift          # typed error enum with LocalizedError
│   ├── Services/
│   │   ├── VisionService.swift         # actor — VNClassifyImageRequest + VNCoreMLRequest
│   │   ├── ModelLoader.swift           # actor — lazy YOLOv3Tiny load, concurrent-safe
│   │   ├── ImageAnalyzer.swift         # orchestrates classify + detect, cache layer
│   │   └── ResultCache.swift           # NSCache wrapper with ResultCacheProtocol
│   ├── Camera/
│   │   ├── CameraSession.swift         # actor — AVCaptureSession lifecycle
│   │   └── CameraPermissionManager.swift
│   ├── Picker/
│   │   └── PhotoPickerCoordinator.swift # PHPickerViewController UIViewControllerRepresentable
│   ├── ViewModels/
│   │   ├── AnalysisViewModel.swift     # @MainActor — library tab state
│   │   └── CameraViewModel.swift       # @MainActor — live camera state, 200 ms throttle
│   └── Views/
│       ├── ContentView.swift           # TabView root
│       ├── CameraTab/
│       │   ├── CameraView.swift
│       │   └── CameraPreviewLayer.swift  # UIViewRepresentable for AVCaptureVideoPreviewLayer
│       ├── LibraryTab/
│       │   ├── LibraryView.swift
│       │   └── BatchProgressView.swift
│       └── Shared/
│           ├── BoundingBoxOverlay.swift  # Canvas-based; handles Vision ↔ SwiftUI coord flip
│           ├── ConfidenceListView.swift  # animated confidence bar rows
│           └── ModelStatusBanner.swift  # degraded-mode warning
└── SnapTagTests/
    ├── VisionServiceTests.swift
    ├── ImageAnalyzerTests.swift
    ├── ResultCacheTests.swift
    ├── AnalysisViewModelTests.swift
    └── Mocks/
        ├── MockVisionService.swift
        ├── MockModelLoader.swift
        └── MockResultCache.swift
```

---

## Running Tests

```bash
mint run xcodegen generate
xcodebuild test \
  -project SnapTag.xcodeproj \
  -scheme SnapTag \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
```

Or press **⌘U** in Xcode.

---

## CI/CD

GitHub Actions runs on every push to `main` and every pull request:

- **macos-14** runner (Xcode 15.4)
- Installs XcodeGen via Mint, generates the project, builds, and runs the test suite
- Uploads `.xcresult` as an artifact on every run (retained 14 days)
- Parallel SwiftLint job on the same runner

See [`.github/workflows/ci.yml`](.github/workflows/ci.yml).

---

## Architecture Diagram — Concurrency

```
Main thread (@MainActor)
├── AnalysisViewModel   @Published state → SwiftUI renders
├── CameraViewModel     @Published state → SwiftUI renders
│
├── Task { await analyzer.analyze(image) }
│       │
│       └── ImageAnalyzer (nonisolated, async)
│               ├── await visionService.classifyScene(...)  ┐ concurrent
│               └── await visionService.detectObjects(...)  ┘ via async let
│                       │
│                       └── actor VisionService
│                               └── VNImageRequestHandler.perform([...])
│                                   (runs on Vision's internal thread pool)
│
└── CameraSession.framePublisher (PassthroughSubject)
        │
        ├── .throttle(200ms, scheduler: DispatchQueue.global)
        └── .sink { Task { await cameraVM.submitFrame(...) } }
```

---

## License

MIT
