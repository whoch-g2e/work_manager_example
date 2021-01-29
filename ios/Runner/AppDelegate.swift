import UIKit
import Flutter
import workmanager

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    static func registerPlugins(with registry: FlutterPluginRegistry) {
            GeneratedPluginRegistrant.register(with: registry)
   }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    UIApplication.shared.setMinimumBackgroundFetchInterval(TimeInterval(60*15))
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
        AppDelegate.registerPlugins(with: registry)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
