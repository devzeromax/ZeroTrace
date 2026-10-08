# Code Review: Public Release Security Verdict (ZeroTrace / cleanshare)

**Date**: 2026-07-08  
**Scope**: Shipped Android release APK + security-critical source  
**APK**: `build/app/outputs/flutter-apk/app-release.apk` (~124,229,100 bytes; post-scrub)  
**Ready for Production (security)**: **Yes — conditional GO**  
**Critical / launch-blocking issues**: **0**

## Verdict

**YES — Ready for public release from a security standpoint**, for an **offline-first / bundled-marketplace** Android launch.

Previous **HIGH** developer identity leak (`msara` / `OneDrive`) is **remediated** in the current scrubbed APK. Remaining gaps are **MEDIUM hardening / CDN-readiness** items that should be tracked, but they do **not** block a first public APK if remote CDN pack downloads are not the day-1 trust boundary (or TLS pins are filled before CDN go-live).

| # | Area | Severity now | Blocks public launch? |
|---|------|--------------|------------------------|
| 1 | Path / PII residual after scrub | **LOW** | No |
| 2 | Signing / anti-repack | **OK** | No |
| 3 | Secrets in repo/APK | **OK in APK**; **MEDIUM local op risk** | No (if never published) |
| 4 | Marketplace TLS SPKI pins | **MEDIUM** | No until CDN ships unsigned-trust |
| 5 | Local encryption at rest | **OK** (mobile/desktop) | No |
| 6 | Runtime root/repack guards | **OK / deliberate UX cost** | No |
| 7 | Dart obfuscation missing | **MEDIUM** | No (hardening) |

---

## Review Plan (Step 0)

| Check | Focus |
|-------|--------|
| ASI-09 supply chain | cert pin, publisher Ed25519, zip SHA, host allowlist, TLS pins |
| A02 crypto / data at rest | Keystore/DPAPI + AES-GCM history |
| A06 / integrity | bootstrap fail-closed, engine hash, audit chain |
| PII / build hygiene | scrubbed `libapp.so`, secrets not in APK |
| Anti-tamper | root/frida/debugger / emulator policy |

---

## 1. Shipped APK path leak residual (post-scrub)

**Evidence** (all three ABIs of `libapp.so`):

| Token | Hits |
|-------|------|
| `msara` | **0** |
| `OneDrive` | **0** |
| Residual URI | `file:///C:/Users/xxxxx/xxxxxxxx/Desktop/ZeroTrace/cleanshare/.dart_tool/flutter_build/dart_plugin_registrant.dart` |

- Scrub (`tool/scrub_apk_paths.ps1`) correctly redacts username + OneDrive with equal-length `x` masks across **arm64-v8a / armeabi-v7a / x86_64**.
- **Intentional residual**: `Desktop` (and thus `Desktop/ZeroTrace`) left alone — colliding with Dart identifiers (`_DesktopCommandCenter`, etc.).
- `AppData` hits are **Flutter/Dart identifiers** (`_readAppData`, `_SharedAppDataState`), not OS paths.

**Residual risk**: Machine layout fingerprint (`C:/Users/.../Desktop/ZeroTrace`) without account identity. **LOW.** Prefer long-term builds from a neutral CI path (e.g. `C:\src\zerotrace`) so the string never forms.

---

## 2. Signing / anti-repack posture

| Check | Result |
|-------|--------|
| `apksigner verify --print-certs` | `CN=ZeroTrace, OU=Mobile, O=ZeroTrace, …` |
| Cert SHA-256 | `7ba8637f01aaf8bdeff0601d0ef0fac97b970927b5d7dc547fa971e65821b373` |
| Pin in code | Matches `PackTrustConstants.androidReleaseCertSha256` |
| Enforcement | `AppIntegrityVerifier.assertReleaseSigningCert` → fail-closed on Android release boot (`engineBootstrapProvider`) |
| Scrub re-sign | Same release keystore → pin still valid |

**Anti-repack**: Resigning with another cert bricks bootstrap. Engine lib hash pinned for Android (`engineLibHashes['android']`). **Production-ready for APK trust.**

---

## 3. Secrets in repo / APK

| Artifact | On disk | In APK | Gitignore |
|----------|---------|--------|-----------|
| `android/key.properties` (keystore passwords) | Yes (local) | **No** (scanned) | `android/.gitignore` |
| `android/keystore/zerotrace-release.jks` | Yes | **No** | `**/*.jks` |
| `tool/keys/publisher_seed.hex` | Yes | **No** (seed prefix absent) | `tool/keys/` in `.gitignore` |
| Publisher **public** key | Embedded | Expected (verify-only) | — |
| Live API / AWS keys | — | Only **scanner regexes** | — |

**Operational MEDIUM**: Workspace lives under **OneDrive**. Plaintext `key.properties` + JKS + publisher seed are local-only but cloud-synced — treat as sensitive; do not zip into public releases; prefer CI secrets for builds.

---

## 4. Network / TLS pinning (marketplace / CDN)

`PackTrustConstants.tlsSpkiPins` for `releases.zerotrace.app` / `cdn.zerotrace.app` are **empty**.

`PinnedHttpClient` behavior:

- HTTPS + host allowlist **enforced**.
- Empty pins → system CA trust (`withTrustedRoots: true`); `badCertificateCallback` allows allowlisted hosts without SPKI match (**interim comment in code**).
- When pins populated → custom `SecurityContext` without system roots + pin match required.

**Zip / catalog trust (improved vs 2026-06-18 review)**:

- `ModelDownloadManager` verifies catalog zip SHA-256 before extract.
- `CatalogIntegrityVerifier` / `INTEGRITY.json` used for bundled + remote catalog hashes.
- Ed25519 required for onnx/rules via `PackTrustPolicy`.

**Deferral**: Populate pins (`dart run tool/extract_tls_pins.dart`) **before** relying on live CDN as a trust boundary. Empty pins are **acceptable** for bundled-only launch; **not acceptable** as the sole defense once CDN is production traffic.

---

## 5. Local data protection

| Layer | Status |
|-------|--------|
| History | AES-GCM via `SecureSettingsCipher` (`HistoryStore`) |
| Key material | Android Keystore / iOS Keychain (`PlatformSecureStorage`); Windows DPAPI (`WindowsDpapiKeyStore`) |
| Web | SharedPreferences fallback (documented limitation) |

Prior “keys in SharedPreferences” finding is **addressed** on mobile/desktop. **OK for public mobile release.**

---

## 6. Runtime security guards — hardened vs break-release?

| Guard | Release behavior | Risk of bricking legit users |
|-------|------------------|------------------------------|
| Signing cert mismatch | Bootstrap **throws** | Only unofficial / repacked APKs — **intended** |
| Engine hash mismatch | Fail-closed (native path) | Rebuild must re-pin after scrub/engine change |
| Root / Frida / debugger (`hostileRuntime`) | Blocks scan/export/pack install; audits | **Rooted/custom-ROM users** lose sensitive features — product tradeoff, not a false-security hole |
| Emulator | Neural packs blocked; audit only otherwise | Expected for release QA (use debug builds) |
| Integrity channel exception | `DeviceIntegrity.load` returns **safe** | Soft fail-open if MethodChannel dies — **LOW**; cert check still requires a hash when pin set |

Guards are **production-hardened** for the intended threat (tamper / hostile runtime). They can **break rooted devices** by design — document in release notes; do not disable for “support” of hostile environments.

---

## 7. Remaining MEDIUM / HIGH vs deferrals

### Do not block launch (if accepted)

| Sev | Issue | Why deferrable |
|-----|-------|----------------|
| **LOW** | `Desktop/ZeroTrace` path residual in AOT | No username; build-path hygiene later |
| **MEDIUM** | Empty TLS SPKI pins | OK until CDN is live; then must-fix |
| **MEDIUM** | No Dart `--obfuscate` / no `build/symbols` on this APK | Class names readable (`PackSignatureVerifier`, …); reverse-engineering harder with obfuscation, not a secret leak |
| **MEDIUM** | Plaintext keystore/seed under OneDrive | Local/opsec, not shipped |
| **LOW** | Fat APK includes `x86_64` | Size/surface; arm64-only preferred |

### Fixed since earlier audits (do not re-block)

- Developer `msara` / `OneDrive` in all ABI `libapp.so` — scrubbed.
- Zip SHA before extract; catalog `INTEGRITY.json` verification; bootstrap fail-closed on cert.
- Keystore/Keychain-backed history encryption.

---

## Explicit answer

### Ready for public release from a security standpoint?

# **YES**

**Top non-blocking follow-ups (do before or with CDN launch):**

1. Fill `tlsSpkiPins` before production CDN downloads.  
2. Ship next APK with `tool/build_release_android.ps1` **+** `-ScrubPaths` **+** `--obfuscate` (verify `build/symbols` kept private).  
3. Prefer CI/neutral build path to eliminate residual Desktop URI.  
4. Keep `key.properties` / JKS / `publisher_seed.hex` out of any public artifact or shared cloud folder dump.

**Would flip to NO:** shipping with live remote marketplace trust while TLS pins remain empty **and** treating system-CA-only as sufficient for ASI-09; or rediscovering plaintext identity (username) / private keys inside a public APK; or unpinning / emptying `androidReleaseCertSha256` in a release build.
