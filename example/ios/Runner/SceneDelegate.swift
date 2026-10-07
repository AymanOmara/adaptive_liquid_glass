import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  // The UIScene template keeps the window here, so the `-renderer swiftui`
  // root view controller swap happens once the scene has connected.
  override func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    MotionScenes.installDump()
    // `-motion <id>` (Task 16) takes over before the static host.
    if !ControlScenes.install(in: window) && !MotionScenes.install(in: window) {
      LaunchArgs.installReferenceScene(in: window)
    }
  }
}
