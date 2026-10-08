# Code Review: ZeroTrace Security
**Ready for Production**: No
**Critical Issues**: 4
**Defense Rating**: 5/10

## Priority 1 (Must Fix) ⛔

1. **Signed catalog hash never checked on downloaded ZIP** — `validateDownloadManifest` verifies ed25519 over `catalog.manifest.sha256`, but `ModelDownloadManager` never hashes the downloaded `.zip` against that value before extraction. A network attacker who bypasses TLS could serve a zip whose inner manifest/model self-consistent but does not match the signed catalog hash.

2. **`INTEGRITY.json` is write-only at build time** — Bundled in assets but never read at runtime. Remote catalog cache (`MarketplaceCatalogSource.cacheRemoteCatalog`) accepts JSON with only host allowlist checks; no signature or integrity file validation.

3. **Engine bootstrap fail-open** — `engineBootstrapProvider` catches integrity failures and still sets `engineReadyProvider = true`, allowing a tampered `zerotrace_engine.dll` to load on Windows release builds.

4. **Encryption keys in SharedPreferences** — `SecureKeyStore` stores the AES-GCM master key in plain SharedPreferences. `HistoryStore` comment claims Keychain/Keystore; implementation does not. Local attacker can decrypt scan history.

## Priority 2 (High)

- TLS SPKI pins are empty (`tlsSpkiPins`); only system CA trust + host allowlist.
- Engine DLL hash pinning is Windows release-only; Linux/macOS/mobile have no FFI integrity check.
- Packs dropped manually into the packs folder are loaded without signature re-verification (`PluginDiscovery`).
- Post-extraction manifest is not signature-checked against catalog entry.

## What Works Well

- Zip-slip protection via `PathGuard.resolveUnderRoot` during extraction.
- Scan/export path sandboxing under app storage root.
- Ed25519 publisher key embedded; ONNX packs require signatures at install time.
- Placeholder ONNX models rejected (`> 1024` bytes).
- Host allowlist + HTTPS-only downloads.
- Hash-chained security audit log.
- Pack install cooldown after repeated failures (in-memory).

## Recommended Changes

Verify zip before extract:

```dart
await _verifier.verifySha256(zipFile, entry.manifest.sha256!);
await _extractZip(zipFile, packDir);
```

Fail-closed bootstrap:

```dart
} catch (e, st) {
  if (kReleaseMode) rethrow;
  debugPrint('Engine bootstrap warning: $e\n$st');
}
```

Use `flutter_secure_storage` for `SecureKeyStore` on supported platforms.

Validate remote catalog against bundled `INTEGRITY.json` or sign the full catalog payload.

Populate TLS pins: `dart run tool/extract_tls_pins.dart`.
