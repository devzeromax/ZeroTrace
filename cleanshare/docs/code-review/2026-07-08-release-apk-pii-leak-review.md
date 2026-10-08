# Code Review: Release APK Personal/System Data Leak Audit

**Component**: `build/app/outputs/flutter-apk/app-release.apk`  
**APK**: 124,195,241 bytes · LastWriteTime 2026-07-08 14:42:44  
**Ready for Production**: **No**  
**Critical Issues**: **1** (developer machine path embedded in shipped `libapp.so`)

## Verdict (YES / NO)

**YES** — This release APK contains personal/system data from this developer's machine that must be stripped before user-facing distribution.

Primary evidence (present in **all three** shipped ABIs of `libapp.so`):

```
file:///C:/Users/msara/OneDrive/Desktop/ZeroTrace/cleanshare/.dart_tool/flutter_build/dart_plugin_registrant.dart
```

That string leaks Windows username (`msara`), cloud sync folder (`OneDrive`), and the full local project path.

---

## Review Plan (Step 0)

| Check | Focus |
|-------|--------|
| Path / PII embedding | Absolute machine paths in Dart AOT (`libapp.so`) and native libs |
| Secrets | Keystore passwords, private keys, API tokens inside APK |
| Signing | Debug vs release keystore |
| Debug leftovers | Asserts, DevTools, kernel blobs, PDBs, source maps |
| Assets | Marketplace packs / demo PII / machine config |

---

## Priority 1 (Must Fix) ⛔

### 1. Absolute developer machine path in shipped `libapp.so` — **HIGH** (PII / recon)

| | |
|--|--|
| **Where (shipped)** | `lib/arm64-v8a/libapp.so`, `lib/armeabi-v7a/libapp.so`, `lib/x86_64/libapp.so` |
| **Also local-only?** | Same string exists in build intermediates; **also inside the shipping APK** |
| **Snippet** | `file:///C:/Users/msara/OneDrive/Desktop/ZeroTrace/cleanshare/.dart_tool/flutter_build/dart_plugin_registrant.dart` |
| **Cause** | Flutter AOT embeds the absolute `dart_plugin_registrant.dart` URI as a string constant. Symbol stripping does not remove it. |
| **Impact** | Username, OneDrive, Desktop layout, and repo location are visible to anyone unpacking the APK. Not a credential leak by itself; enables targeted social engineering / phishing and fingerprinting. |

**Remediation (preferred order):**

1. **Build from a path without personal identity** (recommended root fix): e.g. `C:\src\zerotrace\cleanshare` or a CI agent path — no username / OneDrive / Desktop.
2. **Always run the existing scrub after release build**:
   ```powershell
   .\tool\build_release_android.ps1 -ScrubPaths
   # or
   .\tool\scrub_apk_paths.ps1 -Apk build\app\outputs\flutter-apk\app-release.apk
   ```
   (`-ScrubPaths` is off by default today.)
3. Re-verify:
   ```powershell
   rg -a "msara|OneDrive|Users/" build\app\outputs\flutter-apk\app-release.apk
   # expect: no hits in libapp.so after scrub
   ```

---

## Priority 2 (Should Fix)

### 2. Release likely built **without** `--obfuscate` / `--split-debug-info` — **MEDIUM**

| Evidence | Detail |
|----------|--------|
| Missing | `build\symbols\` directory (script would create it) |
| Present in `libapp.so` | Readable URIs like `package:cleanshare/infrastructure/marketplace/model_download_manager.dart` and class names (`PackSignatureVerifier`, `DeveloperSecretsScannerPlugin`, …) |
| Product docs / script | `tool/build_release_android.ps1` and `product.md` expect obfuscation |

**Impact**: Easier reverse engineering of marketplace trust / sanitizer flows. Not personal-data leakage, but weakens release hardening.

**Remediation**:

```powershell
.\tool\build_release_android.ps1 -ScrubPaths
# ensures: flutter build apk --release --obfuscate --split-debug-info=build\symbols
```

Keep `build\symbols\` **private** (never ship; add to `.gitignore` if not already covered by `build/`).

### 3. Plaintext keystore passwords on disk (`android/key.properties`) — **MEDIUM** (local / VCS risk; **not in APK**)

| | |
|--|--|
| **Where** | `android/key.properties` (local workspace) |
| **In APK?** | **No** — password string not found in APK contents |
| **Gitignore** | `android/.gitignore` already lists `key.properties` and `**/*.jks` |

**Snippet (local only — rotate if this file was ever shared):**

```
storePassword=… (present)
keyPassword=… (present)
keyAlias=zerotrace
storeFile=../keystore/zerotrace-release.jks
```

**Remediation**: Never commit; prefer CI secrets / env injection; rotate passwords if exposed via chat, backup, or sync; ensure parent monorepo also ignores these files.

### 4. `android/local.properties` contains SDK absolute paths — **LOW** (local only)

```
sdk.dir=C:\\Users\\msara\\AppData\\Local\\Android\\Sdk
flutter.sdk=C:\\Flutter\\flutter
```

**In APK?** **No.** Already gitignored under `android/.gitignore`. Do not bundle into assets.

---

## Checked and Clear (Evidence)

| Check | Result |
|-------|--------|
| **Signing** | **Release keystore**, not debug. `apksigner verify --print-certs`: DN `CN=ZeroTrace, OU=Mobile, O=ZeroTrace, L=Unknown, ST=Unknown, C=US`; SHA-256 `7ba8637f01aaf8bdeff0601d0ef0fac97b970927b5d7dc547fa971e65821b373` matches `PackTrustConstants.androidReleaseCertSha256`. |
| **Private keys / keystore inside APK** | **None** (no `.jks` / `.pem` / `key.properties` zip entries; password not in binary scan). |
| **API keys / AWS AKIA live secrets** | Only **detection regex patterns** (e.g. `AKIA[0-9A-Z]{16}`) in engine / scanners — intentional, not credentials. |
| **Publisher private seed** | Not found. Public Ed25519 hex in `INTEGRITY.json` / `PackTrustConstants` is **expected** (verify-only). |
| **Hostnames / emails / local IPs of this machine** | No username/email beyond the `file:///` path. `127.0.0.1` / `localhost` / `DevTools` / `vm-service` strings appear in **`libflutter.so`** as **engine CLI help / option names** (Flutter SDK), not as live endpoints or your hostname. |
| **`libzerotrace_engine.so`** | No `msara` / `OneDrive` / `Users\` paths. |
| **PDB / source maps / kernel_blob** | **Not** in APK. |
| **Flutter product mode** | AOT release snapshot (`libapp.so`); no `kernel_blob.bin`. `dart.vm.product` string present as constellation metadata (normal). |
| **Marketplace assets** | Branding, packs, catalog — no developer PII. `developer-protection` pack rules file is a stub (`zerotrace-pack-stub:…`), not demo personal data. |
| **VCS stamp** | `META-INF/version-control-info.textproto` → `NO_SUPPORTED_VCS_FOUND` (no git user/email stamp). |

### Signing implication summary

| Mode | This APK? | Implication |
|------|-----------|-------------|
| Debug keystore | **No** | Would use `CN=Android Debug…`, storepass `android` — anyone can resign |
| Release (`zerotrace`) | **Yes** | Correct for distribution; keep JKS + `key.properties` off public channels |

---

## Lower / Informational

### `DebugProbesKt.bin` in APK root — **LOW**

Kotlin coroutines debug-probe metadata (~1.7 KB). Common in Android/Kotlin releases; not your machine path. Optional: rely on R8 full mode / packaging excludes if you want zero debug-named resources (cosmetic).

### Multi-ABI APK includes `x86_64` — **LOW** (size / attack surface)

Fat APK ships `arm64-v8a`, `armeabi-v7a`, `x86_64`. Prefer:

```powershell
flutter build apk --release --target-platform android-arm64 --obfuscate --split-debug-info=build\symbols
```

(as `build_release_android.ps1` already intends) for store/sideload hardening and smaller artifacts.

### Empty TLS SPKI pins — **MEDIUM product-trust** (out of PII scope)

`PackTrustConstants.tlsSpkiPins` hosts have empty pin lists. Marketplace TLS pinning not enforced until pins are populated — supply-chain concern, not machine PII.

---

## Concrete Strip / Rebuild Checklist

1. **Immediate (this APK)**:
   ```powershell
   cd cleanshare
   .\tool\scrub_apk_paths.ps1 -Apk build\app\outputs\flutter-apk\app-release.apk
   rg -a "msara|OneDrive|/Users/" build\app\outputs\flutter-apk\app-release.apk
   ```
2. **Next release pipeline**:
   ```powershell
   .\tool\build_release_android.ps1 -ScrubPaths
   ```
   Optionally default `-ScrubPaths` to **on**, or fail the script if `msara|OneDrive|C:/Users/` still match inside `libapp.so`.
3. **Build-path hygiene**: clone/build under a non-personal path in CI.
4. **Gradle**: keep `minifyEnabled` / R8 for Java/Kotlin if not already; Flutter Dart obfuscation is separate (`--obfuscate`).
5. **Never ship**: `build\symbols\`, `*.jks`, `key.properties`, `local.properties`, native unstripped libs under intermediates.
6. **`.gitignore`**: already covers keystore/local for android; ensure `tool/keys/` stays ignored (already in cleanshare `.gitignore`).

---

## Priority Summary

| Sev | Finding | In shipped APK? |
|-----|---------|-----------------|
| **HIGH** | `C:/Users/msara/OneDrive/Desktop/ZeroTrace/.../dart_plugin_registrant.dart` in `libapp.so` (all ABIs) | **Yes** |
| **MEDIUM** | Likely missing Dart obfuscation / split-debug-info | Hardening gap |
| **MEDIUM** | Plaintext release passwords in local `key.properties` | **No** (local) |
| **LOW** | `local.properties` SDK paths | **No** (local) |
| **LOW** | `DebugProbesKt.bin`, fat ABI | Yes / cosmetic |
| **Clear** | Release signing, no keystore/API secrets in APK, no PDB/sourcemap | — |

**Does this release APK contain personal/system data from this developer's machine that must be stripped?** → **YES**.
