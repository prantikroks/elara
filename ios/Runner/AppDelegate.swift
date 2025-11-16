import UIKit
import Flutter
import ARKit     // For AR
import HealthKit // For Health

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {

  // --- NATIVE HEALTH MANAGER ---
  // Create a single, persistent instance of our HealthKit manager
  //
  // IMPORTANT: Your 'HealthKitManager' class MUST conform to 'FlutterStreamHandler'
  // to be used with the Event Channel below.
  let healthManager = HealthKitManager()
  // --- END NATIVE HEALTH MANAGER ---

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    let controller = window?.rootViewController as! FlutterViewController
    
    // --- AR CHANNEL (from before) ---
    let arChannel = FlutterMethodChannel(name: "com.elara.app/ar",
                                         binaryMessenger: controller.binaryMessenger)
    
    arChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      guard call.method == "launchAR" else {
        result(FlutterMethodNotImplemented)
        return
      }
      // When we get the call, launch our native AR screen
      // This assumes you have an 'ARViewController.swift' file.
      self?.launchARScreen(controller: controller)
      result(nil) // Send a "success" response back to Flutter
    }
    
    // --- HEALTH METHOD CHANNEL (Start/Stop) ---
    let healthMethodChannel = FlutterMethodChannel(name: "com.elara.app/health_method",
                                               binaryMessenger: controller.binaryMessenger)
    
    healthMethodChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "startHealthStream" {
        // This assumes your 'HealthKitManager' has a 'startStreaming()' function
        self?.healthManager.startStreaming()
        result(nil)
      } else if call.method == "stopHealthStream" {
        // This assumes your 'HealthKitManager' has a 'stopStreaming()' function
        self?.healthManager.stopStreaming()
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    
    // --- HEALTH EVENT CHANNEL (The Stream) ---
    let healthEventChannel = FlutterEventChannel(name: "com.elara.app/health_event",
                                             binaryMessenger: controller.binaryMessenger)
    
    // This connects our HealthKitManager (the "Handler") to the event channel.
    // This is the line that REQUIRES 'HealthKitManager' to conform to 'FlutterStreamHandler'.
    healthEventChannel.setStreamHandler(healthManager)
    
    // --- END HEALTH CHANNELS ---

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // This function creates and presents our new ARViewController
  // This assumes you have a file named 'ARViewController.swift' that
  // defines a UIViewController subclass.
  func launchARScreen(controller: UIViewController) {
    let arVC = ARViewController()
    arVC.modalPresentationStyle = .fullScreen
    controller.present(arVC, animated: true, completion: nil)
  }
}