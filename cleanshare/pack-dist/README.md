# Neural pack distribution (not bundled in the APK)

These signed ONNX packs are published to the marketplace CDN. They are **not**
shipped inside the Flutter asset bundle.

| Pack | Approx. size |
|------|----------------|
| `face-protection.zip` | ~3.5 MB |
| `document-protection.zip` | ~18 MB |
| `vehicle-protection.zip` | ~37 MB |

Host under `https://releases.zerotrace.app/packs/<id>/1.0.0/pack.zip` (see
`assets/marketplace/catalog.json` download URLs), then enable
`PackTrustConstants.remoteMarketplaceEnabled` and TLS pins before release.
