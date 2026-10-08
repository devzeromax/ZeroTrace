# ZeroTrace — Project Overview

**Version:** 1.0.0  
**Tagline:** Share files. Leave zero trace.  
**App folder:** `cleanshare/`

ZeroTrace is a privacy-first file sanitization app. It scans a file on the device, lists privacy risks, and exports a cleaned copy. The file is not uploaded. There is no user account, no scan server, and no analytics pipeline tied to the file.

---

## Problem

People share photos, PDFs, Office files, and code from a phone or PC. Those files can still contain:

- GPS and camera metadata inside a photo
- Faces and license plates in a picture
- Names, ID numbers, and other text in a document image or PDF
- API keys, tokens, and JWTs in code or config
- Sensitive links inside a QR code or barcode

Cleaning often depends on a cloud scanner, which needs the private file uploaded first. ZeroTrace does the scan on the device and writes the cleaned copy there.

---

## Who it is for

- People who share photos or documents and want hidden metadata removed first
- Developers who need to catch API keys or tokens before sharing code or config
- Anyone who wants on-device face blur, plate detection, or document OCR before publishing
- Users who want an offline tool instead of a cloud scanner

---

## What the user does

1. **Select a file.** Pick an image or document from the device.
2. **Scan.** Built-in packs and any installed packs analyze the file on the device.
3. **Review findings.** The app lists metadata, faces, personal data, secrets, and other hits.
4. **Fix and export.** The user sanitizes the file and saves a cleaned copy, with an optional report.
5. **History.** Past scans stay on the device until the user deletes them.

---

## Built-in scanners

These ship inside the app and work offline from first launch.

| Pack | What it does |
|------|----------------|
| Privacy Essentials | EXIF metadata, GPS, and privacy reporting |
| Metadata Cleaner | PDF, Office, and ZIP header and metadata detection |
| Developer Protection | API keys, tokens, JWTs, and secret patterns in code or config |
| QR Protection | QR and barcode scanning for sensitive URLs and tokens |

---

## Optional packs

Downloaded from **Settings → Pack marketplace**. The download needs a network. After install, scanning works offline.

| Pack | Size (approx.) | What it does |
|------|----------------|--------------|
| Face Protection | ~3.5 MB | Detect faces at more angles and blur them before sharing |
| Vehicle Protection | ~37 MB | License plates and vehicle regions in photos |
| Document Protection | ~18 MB | OCR for document images, plus PDF text-layer personal-data scan |

Packs are signed and hash-checked before install. Face, vehicle, and document packs use the on-device ONNX runtime.

---

## Privacy

- Scans, fixes, and exports stay on the device.
- The network is used only to download an optional pack.
- Scan history, exports, installed packs, and settings stay on the device.
- **Delete all data** in Settings wipes scans, exports, packs, keys, and history in one action.
- The app does not use the camera, microphone, or contacts. It reads only files the user selects.

Full wording is in the app under **Settings → Privacy policy** and **Legal notice**.

---

## Security in the current release

These controls apply to the local, sideloaded Android release:

| Control | What it does |
|---------|----------------|
| Dart obfuscation | Release builds use `--obfuscate` |
| APK signing cert pin | The app refuses to boot if the APK was re-signed |
| Native engine hash pin | Checks that the Rust scanner engine was not swapped |
| Root, debug, and Frida checks | Blocks scan, export, and neural pack install on hostile devices (release only) |
| Pack signatures | Ed25519-signed catalog and a hash for each pack before install |
| Audit log | HMAC hash-chain security log, checked on startup |
| Encrypted key storage | Android Keystore, iOS Keychain, or Windows DPAPI |
| Build-path scrubbing | The release APK strips developer machine paths from native binaries |

A skilled person can still fork or patch an open APK. These controls raise the bar against casual tampering and repacks. They are not DRM.

---

## Platforms

| Platform | Status |
|----------|--------|
| Android | Primary. Release APK is available (arm64). |
| Windows | Supported desktop build. |
| macOS, Linux, iOS, Web | Present in the codebase. Mobile and desktop are the focus. |

---

## Tech stack

| Layer | Technology |
|-------|------------|
| UI | Flutter 3, Dart 3 |
| State and routing | Riverpod, GoRouter |
| Scanner | Rust engine `zerotrace_engine`, called through FFI |
| Neural inference | ONNX Runtime on the device |
| Pack trust | Ed25519 signatures and per-pack hashes |
| Local integrity | HMAC audit chain, certificate pin, engine hash pin |

---

## Release status (1.0.0)

- Public release.
- Face, plate, and OCR detection is not fully accurate. The user reviews findings before sharing.
- Some marketplace CDN endpoints may not be live. Bundled packs still work offline.
- The Android release is signed with the release keystore, not a debug key. The certificate pin matches that signature.

**Android APK:** `cleanshare/build/app/outputs/flutter-apk/app-release.apk`  
**Size:** ~95–105 MB arm64 (face/plate/document packs bundled for offline install; auto-install on first launch)

Install by copying the APK to the phone, allowing install from that source, then opening ZeroTrace and granting file access. Check: launch, offline scan, optional pack install when the CDN is reachable, and **Delete all data** in Settings.

Rebuild from `cleanshare/`:

```powershell
.\tool\build_release_android.ps1
```

---

## Not in this build

- A live CDN with TLS certificate pinning for marketplace downloads (neural packs live in `cleanshare/pack-dist/` until CDN go-live)
- An iOS TestFlight or App Store build
- Full widget and integration test coverage

---

## Pitch decks in this folder

- `ZeroTrace-SIH2025-Idea.pptx` — SIH idea template, six slides
- `ZeroTrace-Hackathon-Pitch.pptx` — live hackathon deck

Shorter product notes also live in `cleanshare/product.md`.
