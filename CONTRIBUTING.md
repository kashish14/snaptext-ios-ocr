# Contributing to SnapText

Thanks for helping! Bug reports, docs, tests, new detectors and new tools are all welcome.

## Quick start
1. Fork the repo and create a branch: `git checkout -b feat/short-description`
2. Open `SnapText.xcodeproj` in Xcode 26.4+ and set your own signing Team (see the [README](README.md#build--run)).
3. Make your change. Run the tests with **⌘U**.
4. Open a pull request against `main`.

## What to work on
- Items marked **help wanted** in [ROADMAP.md](ROADMAP.md)
- Issues labelled `good first issue` or `help wanted`
- Anything else: open an issue first so we can agree on the approach

## Guidelines
- **Privacy is non-negotiable.** No network calls for core features, no analytics, no third-party tracking SDKs.
- **No new dependencies** without discussion. Prefer Apple frameworks.
- **Keep it small.** One focused change per PR. Match the existing style (SwiftUI, MVVM, services in `Services/`).
- **Test detection logic.** Changes to `SmartDetector`, `ContentClassifier` or `ActionPriorityEngine` need a test in `SnapTextTests/`.
- **Don't commit signing changes.** Leave `DEVELOPMENT_TEAM` empty and keep the bundle IDs as they are in your PR.
- **Accessibility:** add labels to icon-only buttons and support Dynamic Type.

## Commit messages
Use [Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `chore:`.

## Reporting bugs
Use the bug report template. Include the iOS version, device, steps, and a sample image if it's safe to share. Remove any personal information from screenshots first.

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE) and that you'll follow the [Code of Conduct](CODE_OF_CONDUCT.md).
