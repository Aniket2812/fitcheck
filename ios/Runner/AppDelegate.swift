import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let channelName = "com.compete.youcam2/share"
  private let appGroup = "group.com.compete.youcam2.share"
  private let sharedTextKey = "sharedProductText"
  private var shareChannel: FlutterMethodChannel?
  private var initialSharedText: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    shareChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      switch call.method {
      case "getInitialSharedText":
        self.initialSharedText = self.initialSharedText ?? self.readSharedText()
        result(self.initialSharedText)
      case "resetSharedText":
        self.initialSharedText = nil
        UserDefaults(suiteName: self.appGroup)?.removeObject(forKey: self.sharedTextKey)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func receiveSharedProduct() {
    guard let text = readSharedText() else { return }
    if let shareChannel {
      shareChannel.invokeMethod("sharedText", arguments: text)
    } else {
      initialSharedText = text
    }
  }

  private func readSharedText() -> String? {
    UserDefaults(suiteName: appGroup)?.string(forKey: sharedTextKey)
  }
}
