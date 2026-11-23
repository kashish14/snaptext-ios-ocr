# Roadmap

SnapText is built in milestones. Items marked **help wanted** are good places to start. Comment on or open an issue before you begin so work isn't duplicated.

## ✅ Milestone 1: Core OCR
- [x] Xcode project (SwiftUI, MVVM, SwiftData)
- [x] `OCRService`: Vision wrapper with fast/accurate modes, multi-language, auto-downscaling
- [x] Camera, gallery and batch capture
- [x] Copy / share with haptics; error states for "no text found"
- [x] Selectable, formatted result text

## ✅ Milestone 2: Share Extension
- [x] `SnapTextShare` extension that receives an image, runs fast OCR and auto-copies
- [x] Success/error feedback, then auto-dismiss
- [ ] Profile memory on very large images and tune the extension's downscale limit (currently 4096 px, shared with the app) (**help wanted**)
- [ ] "Open in SnapText" button for full results (**help wanted**)

## ✅ Milestone 3: Smart Detection
- [x] `SmartDetector`: 19 entity types (phone, URL, email, address, date, UPI, Wi-Fi, tracking, flight, IFSC, PAN, GST, …)
- [x] One-tap actions: call, mail, maps, calendar, contacts, join Wi-Fi, courier tracking
- [x] `ContentClassifier`: document / receipt / table / JSON / code / photo
- [x] `ActionPriorityEngine` + `UserBehaviorTracker`: actions ranked by relevance and personal usage
- [ ] OTP detection with a prominent "Copy code" action (**help wanted**)

## ✅ Milestone 4: Tools & History
- [x] Scan history and clipboard history (SwiftData) with search
- [x] 25+ tools: PDF (create, merge, sign), image (compress, resize, remove background, watermark, passport photo), text (summarize, compare, word count, JSON format), utilities (units, color picker, ruler)
- [x] Live camera, handwriting, object detection, scan & translate

## 🚧 Milestone 5: Polish & Quality (current)
- [x] Unit tests for detection and classification
- [x] CI on every push and PR
- [ ] Expand test coverage: `ActionPriorityEngine`, `OCRService` with fixture images (**help wanted**)
- [ ] Swift 6 strict-concurrency clean build (**help wanted**)
- [ ] VoiceOver and Dynamic Type audit (**help wanted**)
- [x] README screenshots
- [ ] App icon

## 🔭 Next
- [ ] Home Screen widget: tap to scan, last 3 scans to re-copy (**help wanted**)
- [ ] App Group so Share Extension scans appear in History
- [ ] Onboarding: two skippable screens
- [ ] iPad and visionOS layout polish
- [ ] Localization via a String Catalog (**help wanted**)
- [ ] On-device text cleanup and summarization with Apple Foundation Models

## Non-goals
- Cloud OCR or uploading user images
- Accounts or login
- Ads or third-party tracking SDKs
