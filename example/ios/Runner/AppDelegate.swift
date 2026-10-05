import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    FlutterMethodChannel(
      name: "example/launch", binaryMessenger: engineBridge.applicationRegistrar.messenger()
    ).setMethodCallHandler { call, result in
      guard call.method == "getArgs" else { result(FlutterMethodNotImplemented); return }
      // `-mode <auto|shader|native>` picks the glass path for scenes;
      // `-flip <seconds>` flips the scene's brightness after that long.
      var args = LaunchArgs.all
      args["mode"] = LaunchArgs.arg("mode")
      args["flip"] = LaunchArgs.arg("flip")
      result(args)
    }
  }
}
