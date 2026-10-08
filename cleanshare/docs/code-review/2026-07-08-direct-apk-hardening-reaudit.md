# Code Review: Direct-APK Hardening Re-Audit
**Ready for Production**: No  
**Critical Issues**: 2

## Scope
Re-audit after local hardening changes for:
1) detached APK signatures + independent verification channel readiness  
2) TLS pin population + release enforcement  
3) integrity channel fail-closed behavior in release  
4) startup hostile-runtime restriction/blocking  
5) release pipeline strict signing without debug fallback

## Control Status

### 1) Detached APK signatures + verify instructions + independent channel readiness
**Status**: Partial

- Detached Ed25519 signing and verification tooling is present and functional.
- Local verification passes against the current release APK and detached `.sig.json`.
- Documentation instructs publishing the signature on an independent channel (e.g., GitHub Releases), but channel publication/operational checks are process-dependent and not verifiable from code alone.

### 2) TLS pins populated/enforced in release
**Status**: Partial

- Enforcement path is fail-closed in release if any allowlisted marketplace host has no pin.
- Current constants still contain empty pin arrays for both marketplace hosts, so production effectiveness depends on pin population before shipping.

### 3) Integrity channel fail-closed in release
**Status**: Implemented

- Catalog integrity checks validate bundled and cached/remote catalog JSON against `INTEGRITY.json` and signature constraints.
- Invalid cache/remote integrity is rejected and app falls back to bundled verified catalog, preventing trust in tampered remote data.
- Pack downloads are re-verified with SHA-256 and Ed25519 before install.

### 4) Startup hostile-runtime restricted/block mode
**Status**: Implemented

- Release startup now blocks when hostile runtime signals are detected (debugger/root/frida).
- Sensitive operations still re-check and block in release.

### 5) Release pipeline strict signing (no debug fallback)
**Status**: Implemented

- Android release Gradle config throws if release signing properties are missing.
- Release build explicitly uses `signingConfig = signingConfigs.getByName("release")`.

## Regressions / New Risk Introduced

1. **Residual release privacy leak remains likely unless optional scrub step is enabled**: build script keeps path-scrub off by default (`-ScrubPaths` optional), while prior audit found absolute local machine path in shipped `libapp.so`.
2. **Detached signature artifact naming mismatch risk**: generated signature payload can reference `artifact: app-release.apk` while distribution might rename APK, creating verification friction unless artifact naming discipline is enforced.

## Priority 1 (Must Fix) ⛔

1. Populate `tlsSpkiPins` for all allowlisted hosts and rebuild release artifact.
2. Make path scrub mandatory (or fail build when local absolute path markers are found in APK libs).

## Recommended Changes

- Add CI gate: fail release when `marketplaceTlsReady` is false.
- Add CI gate: fail release when `rg -a "C:/Users/|OneDrive|/Users/" app-release.apk` matches.
- Publish detached signature and APK hash in two independent channels with identical artifact filename.

