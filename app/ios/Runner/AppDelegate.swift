import Flutter
import UIKit
import LocalAuthentication
import Security

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let biometricsChannelName = "ow.platform/biometrics"
  private let screenGuardChannelName = "ow.platform/screen_guard"
  private let screenGuardEventsName = "ow.platform/screen_guard_events"
  private let hardwareKeyStoreChannelName = "ow.platform/hardware_key_store"

  var screenGuardEventSink: FlutterEventSink?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // M0-13 / M0-11: 把数据库与敏感文件排除出系统备份（iCloud / iTunes）
    excludeAppDocumentsFromBackup()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "OneWalletPlatformPlugin") else {
      return
    }
    let messenger = registrar.messenger()

    // 1. ScreenGuard
    let screenGuardChannel = FlutterMethodChannel(name: screenGuardChannelName, binaryMessenger: messenger)
    screenGuardChannel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }
      if call.method == "enable" {
        NotificationCenter.default.addObserver(
          self,
          selector: #selector(self.screenCaptureChanged),
          name: UIScreen.capturedDidChangeNotification,
          object: nil
        )
        result(nil)
      } else if call.method == "disable" {
        NotificationCenter.default.removeObserver(
          self,
          name: UIScreen.capturedDidChangeNotification,
          object: nil
        )
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    let screenGuardEventChannel = FlutterEventChannel(name: screenGuardEventsName, binaryMessenger: messenger)
    screenGuardEventChannel.setStreamHandler(ScreenGuardStreamHandler(delegate: self))

    // 2. Biometrics
    let biometricsChannel = FlutterMethodChannel(name: biometricsChannelName, binaryMessenger: messenger)
    biometricsChannel.setMethodCallHandler { (call, result) in
      if call.method == "isAvailable" {
        let context = LAContext()
        var error: NSError?
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        result(canEvaluate)
      } else if call.method == "authenticate" {
        let context = LAContext()
        let args = call.arguments as? [String: Any]
        let reason = args?["reason"] as? String ?? "验证身份"
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
          DispatchQueue.main.async {
            if success {
              result(true)
            } else {
              result(FlutterError(code: "AUTHENTICATION_FAILED", message: error?.localizedDescription, details: nil))
            }
          }
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    // 3. HardwareKeyStore
    let hardwareKeyStoreChannel = FlutterMethodChannel(name: hardwareKeyStoreChannelName, binaryMessenger: messenger)
    hardwareKeyStoreChannel.setMethodCallHandler { (call, result) in
      if call.method == "isAvailable" {
        let context = LAContext()
        var error: NSError?
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        result(canEvaluate)
      } else if call.method == "wrap" {
        guard let args = call.arguments as? [String: Any],
              let alias = args["alias"] as? String,
              let plaintextData = (args["plaintext"] as? FlutterStandardTypedData)?.data else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing alias or plaintext", details: nil))
          return
        }

        var error: Unmanaged<CFError>?
        guard let accessControl = SecAccessControlCreateWithFlags(
          kCFAllocatorDefault,
          kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
          .biometryCurrentSet,
          &error
        ) else {
          result(FlutterError(code: "UNSUPPORTED", message: "AccessControl creation failed", details: nil))
          return
        }

        let deleteQuery: [String: Any] = [
          kSecClass as String: kSecClassGenericPassword,
          kSecAttrAccount as String: alias,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
          kSecClass as String: kSecClassGenericPassword,
          kSecAttrAccount as String: alias,
          kSecValueData as String: plaintextData,
          kSecAttrAccessControl as String: accessControl,
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status == errSecSuccess {
          result(FlutterStandardTypedData(bytes: plaintextData))
        } else {
          result(FlutterError(code: "WRAP_FAILED", message: "Keychain status: \(status)", details: nil))
        }
      } else if call.method == "unwrap" {
        guard let args = call.arguments as? [String: Any],
              let alias = args["alias"] as? String,
              let reason = args["reason"] as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing alias or reason", details: nil))
          return
        }

        let context = LAContext()
        context.localizedReason = reason

        let getQuery: [String: Any] = [
          kSecClass as String: kSecClassGenericPassword,
          kSecAttrAccount as String: alias,
          kSecReturnData as String: true,
          kSecMatchLimit as String: kSecMatchLimitOne,
          kSecUseAuthenticationContext as String: context,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(getQuery as CFDictionary, &item)
        if status == errSecSuccess, let data = item as? Data {
          result(FlutterStandardTypedData(bytes: data))
        } else if status == errSecAuthFailed || status == errSecItemNotFound {
          result(FlutterError(code: "KEY_PERMANENTLY_INVALIDATED", message: "Biometric enrollment changed or item missing", details: nil))
        } else if status == errSecUserCanceled {
          result(FlutterError(code: "USER_CANCELED", message: "User canceled authentication", details: nil))
        } else {
          result(FlutterError(code: "UNWRAP_FAILED", message: "Keychain status: \(status)", details: nil))
        }
      } else if call.method == "delete" {
        guard let args = call.arguments as? [String: Any],
              let alias = args["alias"] as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing alias", details: nil))
          return
        }
        let deleteQuery: [String: Any] = [
          kSecClass as String: kSecClassGenericPassword,
          kSecAttrAccount as String: alias,
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  @objc private func screenCaptureChanged() {
    let isCaptured = UIScreen.main.isCaptured
    screenGuardEventSink?(isCaptured)
  }

  private func excludeAppDocumentsFromBackup() {
    guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
    var resourceValues = URLResourceValues()
    resourceValues.isExcludedFromBackup = true
    var url = documentsPath
    try? url.setResourceValues(resourceValues)
  }
}

class ScreenGuardStreamHandler: NSObject, FlutterStreamHandler {
  weak var delegate: AppDelegate?

  init(delegate: AppDelegate) {
    self.delegate = delegate
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    delegate?.screenGuardEventSink = events
    events(UIScreen.main.isCaptured)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    delegate?.screenGuardEventSink = nil
    return nil
  }
}
