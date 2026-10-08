/// ZeroTrace pack trust constants (ASI-09 supply chain).
library;

abstract final class PackTrustConstants {

  /// Direct-APK / offline distribution: no remote catalog or pack downloads.
  static const remoteMarketplaceEnabled = false;

  /// HTTPS hosts allowed for remote pack/catalog downloads.

  static const allowedDownloadHosts = {

    'releases.zerotrace.app',

    'cdn.zerotrace.app',

  };



  /// Ed25519 public key (hex, 32 bytes) for `ed25519:<sig>` catalog signatures.

  /// Rotate: `dart run tool/embed_publisher_key.dart`

  static const publisherPublicKeyHex =

      'e27c80ac7abf056d2dfa9f5a69d5566b65bc405963c005fd5d44d244e490f9a0';



  /// Expected SHA-256 of `zerotrace_engine.dll` (Windows release build).

  /// Re-pin: `dart run tool/embed_engine_hash.dart`

  static const engineDllSha256Windows = '145e50dd4b292b54608853ae41ca516a1912ff82d28183caf6bb86752d75e332';



  /// SPKI/certificate DER SHA-256 pins per host (`sha256/hex` without prefix).

  /// Populate before CDN go-live: `dart run tool/extract_tls_pins.dart`

  /// Release builds reject unpinned marketplace TLS until pins are set.

  static const tlsSpkiPins = <String, List<String>>{

    'releases.zerotrace.app': [],

    'cdn.zerotrace.app': [],

  };



  /// True when at least one marketplace host has TLS pins configured.

  static bool get marketplaceTlsReady =>

      tlsSpkiPins.values.any((pins) => pins.isNotEmpty);



  /// Android release APK strips debug symbols — pin the stripped artifact.
  /// Re-pin after release APK build:
  ///   dart run tool/embed_engine_hash.dart --platform android --release-apk
  static const engineLibHashes = <String, String>{
    'android': '92ae6d86a107237015596ae1f57d23be28dd2b880a857e64354eebbd9b3256d3',
  };

  /// SHA-256 of the release APK signing certificate (hex, lowercase).
  /// Pin after release build: `dart run tool/embed_release_cert.dart --sha256 <hex>`
  /// Leave empty to allow sideload debug builds until you publish an official cert.
  static const androidReleaseCertSha256 = '7ba8637f01aaf8bdeff0601d0ef0fac97b970927b5d7dc547fa971e65821b373';



  /// Max staged scan file size (100 MB).

  static const maxStagingBytes = 100 * 1024 * 1024;

}

