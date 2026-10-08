# Code Review: Anti-Tamper & Duplication (ZeroTrace / CleanShare Android)

**Date**: 2026-07-08  
**Scope**: Tampering, repackaging, cloning, duplication — from actual code  
**Platform**: Android release (`com.cleanshare.cleanshare`)  
**Ready for Production (anti-tamper only)**: **Conditional — B−**  
**Critical Issues**: **0** (no silent trust of repacked APK in release)  
**Bypassable by skilled attacker**: **Yes** (client-only checks, no Play Integrity)

---

## Executive Summary

Release builds **fail closed at cold start** on wrong signing certificate or patched native engine `.so`. Sensitive operations (scan, export, ONNX pack install) **fail closed on hostile runtime** (root / Frida / debugger) in release. Several paths **fail open**: MethodChannel errors return a “safe” device report, hostile runtime is **audit-only at boot**, audit log tampering does not block the app, TLS SPKI pins are empty, and profile/debug builds skip cert/engine gates.

A **branded duplicate APK** resigned with another key is **blocked** for users who install it. A duplicate rebuilt with **stolen release keystore**, or with **patched checks**, can fool users — there is no server attestation or Play Integrity.

---

## Attack → Detection → App Reaction

| # | Attack | Detection (code) | App reaction | Fail mode |
|---|--------|------------------|--------------|-----------|
| 1 | **APK repack / resign** (modified DEX/assets, new signature) | `DeviceIntegrityHelper.signingCertSha256()` → `AppIntegrityVerifier.assertPinnedSigningCert` | **Bootstrap throws** `AppIntegrityException` → `EngineBootstrapErrorScreen` (“Unofficial build detected…”) | **Closed** (release only) |
| 2 | **Clone APK** (copy branding, different `applicationId`, attacker keystore) | Same cert pin vs embedded `PackTrustConstants.androidReleaseCertSha256` | Same bootstrap block | **Closed** (release) |
| 3 | **Clone with stolen release keystore** | Pin matches attacker’s “official” resign | **No detection** — full app behavior | **Open** |
| 4 | **Patch embedded pin / NOP bootstrap check** (Frida, smali, patched `libapp.so`) | None if hook succeeds | App runs normally | **Open** (inherent client limit) |
| 5 | **Patch `libzerotrace_engine.so`** | `EngineIntegrity.verifyAtPath` SHA-256 vs `engineLibHashes['android']` in `ensureEngineIntegrity` | Bootstrap **throws** `StateError` → error screen; re-checked before scan/export | **Closed** (release) |
| 6 | **Patch engine + update pin constant in Dart** | Pin matches patched lib | No detection | **Open** |
| 7 | **Frida / instrumentation** | `DeviceIntegrityHelper.isFridaSuspected()` — `/proc/self/maps` strings `frida`, `gum-js-loop` | Boot: **audit** `hostile_runtime_detected`; scan/export/ONNX install: **`RuntimeSecurityException`** | **Partial** (UI works; ops blocked) |
| 8 | **Xposed / LSPosed** | **Not implemented** | No signal | **Open** |
| 9 | **Magisk / root** | `isRootSuspected()` — `test-keys`, `su` paths incl. `/magisk/.core/bin/su`, `which su` | Same as Frida (hostile → audit boot, block sensitive ops release) | **Partial** |
| 10 | **Debugger attached** | `Debug.isDebuggerConnected()` | Same hostile-runtime policy | **Partial** |
| 11 | **Emulator / CI farm** | `isEmulator()` — Build.FINGERPRINT/MODEL/HARDWARE heuristics | Boot: **audit** `emulator_detected`; ONNX install: **blocked** (`requiresNeuralEngine`); `neuralPacksAllowed()` false; **scan/export not blocked** for emulator alone | **Partial** |
| 12 | **Spoof integrity MethodChannel** | None — Dart trusts channel response | Forged “clean” report + cert hash → bypass hostile + cert checks if pin also patched | **Open** |
| 13 | **MethodChannel failure** | `DeviceIntegrity.load()` catch → `DeviceIntegrityReport.safe` | All integrity flags false; cert null → cert check throws “Could not read…” **unless** empty pin | **Open** on errors |
| 14 | **Fake marketplace ZIP** | `ManifestVerifier.verifySha256` + `PackSignatureVerifier` (Ed25519 `zerotrace\|packId\|version\|sha256`) | Install **throws** → `pack_install_failed` audit | **Closed** |
| 15 | **Zip-slip in pack** | `PathGuard.resolveUnderRoot` on extract | `PathGuardException` → install fails | **Closed** |
| 16 | **Hash swap in manifest** (sig over wrong hash) | Ed25519 verify fails | `PackTrustException` | **Closed** |
| 17 | **MITM CDN download** | `PackTrustPolicy` host allowlist; `PinnedHttpClient` SPKI pins | Pins **empty** → system CA trust (`return true` in `_verifyCertificate`) | **Open** until pins embedded |
| 18 | **Tamper installed pack on disk** | `InstalledPackTrustVerifier` on `PluginDiscovery.discoverAll` | Pack skipped / scan plugin not loaded | **Closed** for onnx/rules |
| 19 | **Tamper `security_audit.jsonl`** | `SecurityAuditLog.verifyChain()` HMAC chain | Boot: record `audit_chain_tampered`; **app continues** | **Open** (detect only) |
| 20 | **Delete / replace audit file** | Missing file → `verifyChain` returns true | Silent reset | **Open** |
| 21 | **Profile / debug build** | `!kReleaseMode` skips cert pin; `kDebugMode` skips engine integrity | Full app on modified device | **Open** (by design) |

---

## Duplicate / Clone Scenario (End-to-End)

### Scenario A — Casual cloner (resign with debug/other keystore)

1. Attacker decompiles `app-release.apk`, changes icon/strings, re-signs.
2. User sideloads fake “ZeroTrace”.
3. `assertBootstrap` → `assertReleaseSigningCert` compares cert to `7ba8637f…b373`.
4. **Mismatch** → `EngineBootstrapException` → user sees `EngineBootstrapErrorScreen`, **no main UI**.
5. **User fooled at store listing level** (similar icon/name), but **app self-identifies as unofficial** on first launch.

### Scenario B — Play Store / phishing clone (different package, copied assets)

1. Attacker publishes `com.fake.zerotrace` with ZeroTrace branding.
2. Android allows coexistence with `com.cleanshare.cleanshare`.
3. Cert pin still fails → **bootstrap error screen**.
4. **Gap**: OS does not validate branding; user must notice wrong package or error message.

### Scenario C — Determined attacker (patch checks)

1. Patch `libapp.so` / hook `deviceIntegrityReport` to return official cert hash and `hostileRuntime=false`.
2. Patch or replace `libzerotrace_engine.so` and update `PackTrustConstants.engineLibHashes` in binary.
3. **App runs fully** including scan on rooted/Frida device.
4. No Play Integrity, no native anti-hook in engine, no Xposed detection.

### Scenario D — Insider / stolen `zerotrace-release.jks`

1. Attacker builds byte-identical or trojanized APK signed with **real** release key.
2. Cert pin **passes**; engine hash passes if they ship matching `.so`.
3. **Indistinguishable from legitimate** via client checks alone.

---

## Debug vs Release Behavior

| Control | Debug | Profile | Release |
|---------|-------|---------|---------|
| Signing cert pin | Skipped (`!kReleaseMode`) | Skipped | **Enforced** — boot fail |
| Engine SHA-256 pin | **Skipped** (`ensureEngineIntegrity` returns immediately) | Enforced | **Enforced** — boot fail |
| Engine mismatch in debug | Logged `engine_hash_mismatch_debug`, still loads | Enforced | Blocked |
| Hostile runtime at boot | Audit only | Audit only | Audit only |
| Hostile runtime on scan/export | **Allowed** | **Allowed** | **Blocked** |
| ONNX pack install on hostile device | Allowed (no `kReleaseMode` gate on install except ONNX path still calls guard) | Blocked in release only | **Blocked** |
| `neuralPacksAllowed()` | Always `true` | Uses report | `false` if hostile/emulator |
| TLS SPKI pins | Empty → system CA + debug print | Same | Same (host allowlist only) |
| Device report cache | First load cached for process lifetime | Same | Same — **late attach Frida after boot undetected** |

---

## What Still Works After Tampering

| Tamper type | UI / settings | Read encrypted history | Scan | Export | Marketplace browse | ONNX install |
|-------------|---------------|------------------------|------|--------|-------------------|--------------|
| Resigned APK (release) | **No** (boot block) | No | No | No | No | No |
| Patched `.so` (release) | **No** (boot block) | No | No | No | No | No |
| Root / Frida / debugger (release) | **Yes** | Yes (if keys intact) | **No** | **No** | Yes | **No** (ONNX) |
| Emulator (release) | **Yes** | Yes | **Yes** (non-neural) | **Yes** | Yes | **No** |
| Audit log tampered | **Yes** | Yes | Yes* | Yes* | Yes | Yes* |
| Successful clone (stolen key / patched checks) | **Yes** | Yes | **Yes** | **Yes** | Yes | Yes |

\*Assumes release device not hostile and bootstrap passed.

---

## Fails Closed vs Fails Open (Anti-Tamper Only)

### Fails closed (good)

- Release APK **wrong signing cert** → no app entry.
- Release **engine `.so` hash mismatch** → no app entry.
- **Pack install**: SHA-256, Ed25519, zip-slip, host allowlist.
- **Scan / export** on root/Frida/debugger in **release**.
- **ONNX pack install** on hostile/emulator in **release**.
- Re-verify **installed packs** at discovery time.

### Fails open (gaps)

- `DeviceIntegrity.load()` **exception → safe report** (all-clear defaults).
- **Hostile runtime at boot** — full UI; only audit.
- **Audit chain tamper** — logged, not blocked.
- **Empty TLS SPKI pins** — CDN MITM theoretically possible.
- **No Xposed**, weak Frida (maps-only), **cached** device report.
- **Pins and public keys in plaintext** in APK (expected for verify-only keys; aids targeted patching).
- **Profile builds** skip cert pin; treat as release-equivalent risk if shipped to users.
- **No Play Integrity / SafetyNet** — cannot prove genuine install to a server.
- **Branding clone** on another package — user confusion, not crypto failure.

---

## Anti-Tamper Grade (Tampering & Duplication Only)

| Dimension | Grade | Notes |
|-----------|-------|-------|
| Anti-repack (cert + engine pin) | **B+** | Real pins, boot fail-closed in release |
| Runtime hook / root resistance | **C** | Block sensitive ops only; UI open; bypassable |
| Anti-clone (user deception) | **C−** | Blocks wrong cert; not wrong package on Play |
| Supply chain (packs) | **A−** | Ed25519 + SHA + zip-slip; TLS pins pending |
| Audit integrity | **C+** | Strong chain; tamper does not gate app |
| Determined attacker resistance | **D+** | Client-only; no hardware attestation |

### **Overall anti-tamper posture: B− (73/100)**

Strong against **unsophisticated repackaging and casual APK cloning**. Not strong against **skilled reverse engineers, stolen signing keys, or store-level brand impersonation**.

---

## Priority Hardening (Tamper-Specific)

1. **P1** — Fail closed on `audit_chain_tampered` in release (or wipe secrets + block scan).
2. **P1** — Do not return `DeviceIntegrityReport.safe` on channel errors in release; fail bootstrap.
3. **P2** — Re-fetch device report (or native re-check) on each `assertSensitiveOperation`.
4. **P2** — Embed TLS SPKI pins before CDN downloads are live.
5. **P2** — Play Integrity API (optional server nonce) for high-trust flows.
6. **P3** — Xposed stack detection; expand Frida checks (ports, named pipes).
7. **P3** — Native integrity checks inside `libzerotrace_engine.so` (self-hash, JNI anti-debug).

---

## Key Code References

- Bootstrap gate: `engineBootstrapProvider` → `RuntimeSecurityGuard.assertBootstrap`
- Cert pin: `AppIntegrityVerifier`, `PackTrustConstants.androidReleaseCertSha256`
- Engine pin: `EngineIntegrity.verifyAtPath`, `ensureEngineIntegrity`
- Hostile policy: `RuntimeSecurityGuard.assertSensitiveOperation`, `DeviceIntegrityReport.hostileRuntime`
- Native signals: `DeviceIntegrityHelper.kt`
- Pack trust: `PackSignatureVerifier`, `PathGuard`, `InstalledPackTrustVerifier`
