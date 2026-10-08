# CleanShare (Flutter Mobile)

Privacy-first file sanitization UI for **CleanShare** — mobile companion to the future Tauri + React desktop app.

## What's included

- **Riverpod** workflow state across Upload → Scan → Audit → Fix → Export
- **Onboarding persistence** via `shared_preferences`
- **file_picker** integration (+ demo sample file fallback)
- **go_router** redirects, error page, onboarding gate
- **Demo mode banner** — honest labeling until Rust/ONNX is connected
- **Dark theme** support (system)
- **Unit & widget tests** in `test/`

## Prerequisites

1. [Install Flutter](https://docs.flutter.dev/get-started/install/windows) (SDK 3.2+)
2. Add Flutter to your PATH

## Setup & run

```powershell
cd "c:\Users\msara\OneDrive\Desktop\APP NEW\cleanshare"

flutter create . --project-name cleanshare --org com.cleanshare
flutter pub get
flutter analyze
flutter test
flutter run
```

## Architecture

```
lib/
├── core/           # theme, router (Riverpod), extensions
├── providers/      # workflow + onboarding state
├── services/       # persistence
├── models/         # entities + WorkflowState
├── data/           # DemoData (replace with Rust FFI)
├── widgets/        # design system components
└── screens/        # feature screens
```

## Next phase

1. Wire `flutter_rust_bridge` / ONNX engine behind `ScanRepository`
2. Replace `DemoData.isDemoMode` when engine is live
3. Add golden tests + integration tests
4. Build Tauri + React desktop with shared design tokens
