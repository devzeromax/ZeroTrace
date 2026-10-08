# ZeroTrace — Product Overview

**Version:** 1.0.0  
**Tagline:** Share files. Leave zero trace.  
**Last updated:** June 2026

---

## What it is

ZeroTrace is a **privacy-first file sanitization app**. It scans photos, documents, and other files on your device, finds privacy risks (metadata, faces, license plates, secrets, QR codes, and more), helps you fix them, and exports a clean copy — **without uploading anything to a server**.

Everything runs **locally on your device**. There are no user accounts, no cloud backend, and no analytics pipeline tied to your files.

---

## Who it's for

- People who share photos or documents and want to strip hidden metadata first
- Developers who need to catch API keys or tokens before sharing code or configs
- Anyone who wants on-device face blur, plate detection, or document OCR before publishing
- Privacy-conscious users who prefer offline tools over cloud scanners

---

## Core workflow

1. **Select a file** — pick an image or document from your device
2. **Scan** — built-in and installed packs analyze the file on-device
3. **Review findings** — see what was detected (metadata, faces, PII, secrets, etc.)
4. **Fix / export** — sanitize and save a clean copy with an optional report
5. **History** — past scans stay on your device until you delete them

---

## Built-in scanners (no download required)

These ship inside the app and work **offline** from first launch:

| Pack | What it does |
|------|----------------|
| **Privacy Essentials** | EXIF metadata, GPS, and privacy reporting |
| **Metadata Cleaner** | PDF, Office, and ZIP header/metadata detection |
| **Developer Protection** | API keys, tokens, JWTs, and secret patterns in code/config |
| **QR Protection** | QR and barcode scanning for sensitive URLs and tokens |

---

## Optional marketplace packs

Download from **Settings → Pack marketplace** (requires internet for the download only; scanning works offline after install):

| Pack | Size (approx.) | What it does |
|------|----------------|--------------|
| **Face Protection** | ~3.5 MB | Detect faces at more angles; enable blur before sharing |
| **Vehicle Protection** | ~37 MB | License plates and vehicle regions in photos |
| **Document Protection** | ~18 MB | OCR for document images + PDF text-layer PII scan |

Packs are **signed and hash-verified** before install. Neural packs (face, vehicle, document) use the on-device ONNX runtime.

---

## Platforms

| Platform | Status |
|----------|--------|
| **Android** | Primary — release APK available (arm64) |
| **Windows** | Supported (desktop build) |
| **macOS / Linux / iOS / Web** | In codebase; mobile and desktop are the focus |

---

## Privacy model

- **No server** — scans, fixes, and exports never leave your device
- **Internet only for pack downloads** — optional marketplace; core app works offline
- **Local storage** — scan history, exports, installed packs, and settings stay on-device
- **Delete all data** — Settings wipes scans, exports, packs, keys, and history in one action
- **No camera/mic/contacts** — the app only accesses files you select

See **Settings → Privacy policy** and **Legal notice** in the app for full disclosures.

---

## Security (current release)

Client-side hardening for a local-only, sideloaded APK:

| Control | What it does |
|---------|----------------|
| **Dart obfuscation** | Release builds use `--obfuscate` to make reverse engineering harder |
| **APK signing cert pin** | App refuses to boot if the APK was re-signed by someone else |
| **Native engine hash pin** | Verifies the Rust scanner engine wasn't swapped |
| **Root / debug / Frida detection** | Blocks scan, export, and neural pack install on hostile devices (release only) |
| **Pack signatures** | Ed25519-signed catalog and per-pack hashes before install |
| **Audit log** | HMAC hash-chain security log, verified on startup |
| **Encrypted key storage** | Android Keystore / iOS Keychain / Windows DPAPI for secrets |
| **Build-path scrubbing** | Release APK strips developer machine paths from native binaries |

**Honest limit:** a skilled attacker can still fork or patch an open APK. These controls raise the bar against casual tampering and repacks — they are not DRM.

---

## Release status

ZeroTrace **1.0.0** is a public release:

- AI detection (faces, plates, OCR) is **not 100% accurate** — always review before sharing
- Some marketplace CDN endpoints may not be live yet; bundled packs work offline
- **Release-signed** with `zerotrace-release.jks` (not debug). Cert pin auto-updated in app.

---

## Install & test (Android)

**APK path:**

```
cleanshare/build/app/outputs/flutter-apk/app-release.apk
```

**Size:** ~95 MB (arm64-v8a only)

**How to install:**

1. Copy `app-release.apk` to your Android phone
2. Enable **Install from unknown sources** for your file manager or browser
3. Tap the APK and install
4. Open ZeroTrace — grant photo/file access when prompted
5. Try: select a photo → scan → review findings → export

**Rebuild command (from `cleanshare/`):**

```powershell
.\tool\build_release_android.ps1
```

**What to verify on device:**

- App launches (no "could not start safely" error)
- Built-in scanners work offline
- Optional packs install from marketplace (when CDN is reachable)
- Delete all data in Settings wipes everything and returns you to marketplace

---

## Tech stack (summary)

| Layer | Technology |
|-------|------------|
| UI | Flutter 3 / Dart 3, Riverpod, GoRouter |
| Scanner engine | Rust (`zerotrace_engine`) via FFI |
| Neural inference | ONNX Runtime (on-device) |
| State / routing | Riverpod + GoRouter |
| Security | Ed25519 signatures, HMAC audit chain, cert/engine pinning |

---

## Release signing

Release builds use `android/key.properties` + `android/keystore/zerotrace-release.jks`.

**First-time setup:**
```powershell
.\tool\create_release_keystore.ps1   # once
.\tool\build_release_android.ps1     # every release
```

Back up the `.jks` and password from `android/keystore/BACKUP_THESE_CREDENTIALS.txt` to a password manager, then delete that file.

---

## What's next (not in this build)

- Live CDN with TLS certificate pinning for marketplace downloads
- iOS TestFlight / App Store build
- Full widget/integration test coverage

---

## Contact

Questions about privacy: see the app store listing or in-app **Settings → Privacy policy**.
