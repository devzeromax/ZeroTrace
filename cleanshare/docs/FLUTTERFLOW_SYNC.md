## FlutterFlow UI sync

The [CleanShare FlutterFlow project](https://app.flutterflow.io/project/clean-share-kx42rm) cannot be pulled automatically — it requires your login.

### How to export from FlutterFlow

1. Open [clean-share-kx42rm](https://app.flutterflow.io/project/clean-share-kx42rm)
2. **Settings → Developers → Download Code**
3. Export to a folder (e.g. `cleanshare-flutterflow-export/`)
4. Share that folder in this workspace for comparison

### Recommended merge strategy

| Keep from this repo | Import from FlutterFlow |
|---------------------|-------------------------|
| `lib/providers/` (Riverpod state) | Screen layouts if better |
| `lib/core/routing/` | Custom assets / images |
| `lib/widgets/glass_surface.dart` | Copy & component names |
| `design_tokens.dart` + `glass_tokens.dart` | Color tweaks only |
| Tests in `test/` | — |

Do **not** replace the whole project with a raw FlutterFlow export — you will lose Riverpod workflow state, router guards, and tests.

### Premium glass UI (this repo)

Glassmorphism is applied via:

- `GlassSurface` — frosted cards
- `AmbientBackground` — gradient orbs
- `GlassNavigationBar` — frosted bottom nav
- `PremiumPage` — page wrapper

Tuned for **subtle** Arc/iOS-style frost, not heavy cyber glass.
