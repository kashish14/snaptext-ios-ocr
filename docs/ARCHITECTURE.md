# Architecture

SnapText is a SwiftUI app using MVVM plus a small set of stateless services. Nothing needs a backend.

## Stack
| Concern | Technology |
|---|---|
| UI | SwiftUI (iOS 26.4+), UIKit bridges where needed |
| Persistence | SwiftData (`ScanHistoryItem`, `ClipboardItem`); `UserDefaults` for usage stats |
| OCR | Vision `VNRecognizeTextRequest` (fast and accurate paths) |
| Document scanning | VisionKit |
| Detection | `NSDataDetector` + hand-tuned regular expressions |
| Language | NaturalLanguage (summaries), Translation (scan & translate) |
| PDF | PDFKit, PencilKit (signatures) |
| System actions | EventKit, Contacts, NetworkExtension (`NEHotspotConfiguration`) |
| Tests | Swift Testing |

No third-party dependencies.

## Pipeline
```
 input                 recognize            understand                          decide                     present
┌──────────────────┐   ┌────────────┐   ┌────────────────┐   ┌──────────────────┐   ┌──────────────────────┐   ┌──────────┐
│ Share Extension  │   │            │   │                │   │                  │   │                      │   │ Result   │
│ Camera / Live    │──▶│ OCRService │──▶│ SmartDetector  │──▶│ContentClassifier │──▶│ ActionPriorityEngine │──▶│ screen + │
│ Gallery / Batch  │   │  (Vision)  │   │ 19 entity types│   │ doc/receipt/JSON…│   │ top 3–5 + "Do more"  │   │ tools    │
│ QR / Doc scanner │   └────────────┘   └────────────────┘   └──────────────────┘   └──────────▲───────────┘   └──────────┘
└──────────────────┘                                                                           │
                                                                                 UserBehaviorTracker
                                                                                 (frequency + recency)
```

## Folder map
```
SnapText/
├── SnapTextApp.swift          App entry, SwiftData container
├── ContentView.swift          Tab bar: Capture · Clipboard · History
├── Models/                    ScanResult, ScanHistoryItem, ClipboardItem, QuickAction, ToolContext, ScanMode
├── Services/
│   ├── OCRService.swift           Vision wrapper, downscaling, line ordering
│   ├── SmartDetector.swift        Entity detection (phones, UPI, Wi-Fi, IFSC, tracking…)
│   ├── ContentClassifier.swift    Rule-based content type classification
│   ├── ActionPriorityEngine.swift Classification + entities → ranked QuickActions
│   ├── UserBehaviorTracker.swift  Learns which actions you use
│   ├── ClipboardManager.swift     Clipboard history
│   └── PDFService.swift           PDF generation helpers
├── ViewModels/ScanViewModel.swift
└── Views/                     Capture, results, history, helpers
    └── Tools/                 One file per tool
SnapTextShare/                 Share Extension: image → OCR → clipboard
SnapTextTests/                 Unit tests (Swift Testing)
```

## Key decisions
- **Share Extension uses the fast Vision path.** Extensions have a tight memory budget and users expect an instant result. The main app uses the accurate path.
- **Images are downscaled** to a 4096 px longest edge before OCR, which keeps small text legible and memory bounded.
- **Shared code via target membership.** The extension compiles `Services/OCRService.swift` directly (a synchronized-folder exception in the project) instead of pulling in a framework.
- **Rules before ML.** Classification and ranking are deterministic heuristics: fast, explainable and testable. On-device models are a roadmap item.
- **Main-actor by default.** The project uses `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`; heavy work (OCR) is `nonisolated` and `async`.

## Adding things
- **A new entity type:** add a case to `DetectedEntity.EntityType`, a pattern and detection pass in `SmartDetector`, an action in `ActionPriorityEngine`, and a test in `SnapTextTests/SmartDetectorTests.swift`.
- **A new tool:** add a view under `Views/Tools/`, add a case to `DirectTool` (and a chip) in `Views/CaptureView.swift`, and read `ToolContext` if it should pre-fill from a scan.
