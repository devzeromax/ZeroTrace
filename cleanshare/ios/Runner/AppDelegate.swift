import Flutter
import UIKit
import Security

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let channelName = "com.cleanshare.cleanshare/secure_store"
  private let serviceName = "com.cleanshare.cleanshare.secure_store"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let messenger = engineBridge.applicationRegistrar.messenger()
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "unavailable", message: "App delegate released", details: nil))
        return
      }
      switch call.method {
      case "isSupported":
        result(true)
      case "read":
        guard let args = call.arguments as? [String: Any],
              let key = args["key"] as? String, !key.isEmpty else {
          result(FlutterError(code: "invalid", message: "Missing key", details: nil))
          return
        }
        result(self.readKey(key))
      case "write":
        guard let args = call.arguments as? [String: Any],
              let key = args["key"] as? String, !key.isEmpty,
              let value = args["value"] as? String else {
          result(FlutterError(code: "invalid", message: "Missing key or value", details: nil))
          return
        }
        result(self.writeKey(key, value: value))
      case "delete":
        guard let args = call.arguments as? [String: Any],
              let key = args["key"] as? String, !key.isEmpty else {
          result(FlutterError(code: "invalid", message: "Missing key", details: nil))
          return
        }
        result(self.deleteKey(key))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func readKey(_ key: String) -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: serviceName,
      kSecAttrAccount as String: key,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess, let data = item as? Data else { return nil }
    return String(data: data, encoding: .utf8)
  }

  @discardableResult
  private func writeKey(_ key: String, value: String) -> Bool {
    _ = deleteKey(key)
    guard let data = value.data(using: .utf8) else { return false }
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: serviceName,
      kSecAttrAccount as String: key,
      kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]
    return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
  }

  @discardableResult
  private func deleteKey(_ key: String) -> Bool {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: serviceName,
      kSecAttrAccount as String: key,
    ]
    let status = SecItemDelete(query as CFDictionary)
    return status == errSecSuccess || status == errSecItemNotFound
  }
}
