import Foundation
import HealthKit
import Flutter // Make sure Flutter is imported

// We MUST conform to FlutterStreamHandler to send data to Flutter
class HealthKitManager: NSObject, FlutterStreamHandler {
  
  let healthStore = HKHealthStore()
  var workoutSession: HKWorkoutSession?
  var heartRateQuery: HKStreamingQuery?
  var hrvQuery: HKStreamingQuery?

  // --- Event Channel STATE ---
  // This is the "sink" that we "pour" our data into for Flutter
  private var eventSink: FlutterEventSink?

  // --- FlutterStreamHandler CONFORMANCE ---
  // This is called when Flutter *starts* listening (in the Provider's init)
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = events
    
    // Request authorization as soon as Flutter is ready
    self.requestAuthorization()
    
    return nil // No error
  }

  // This is called when Flutter *stops* listening (when Provider is disposed)
  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    self.eventSink = nil
    self.stopStreaming() // Stop all queries
    return nil // No error
  }

  // --- 1. AUTHORIZATION ---
  func requestAuthorization() {
    let typesToRead: Set = [
      HKObjectType.quantityType(forIdentifier: .heartRate)!,
      HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
    ]
    
    let typesToWrite: Set = [
      HKObjectType.workoutType() // We "write" a workout to get real-time data
    ]
    
    healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { (success, error) in
      if !success {
        self.eventSink?(FlutterError(code: "AUTH_ERROR", message: "HealthKit authorization failed", details: error?.localizedDescription))
      } else {
        self.eventSink?(["status": "authorized"])
      }
    }
  }

  // --- 2. START THE STREAM ---
  // This is called from AppDelegate via the "startHealthStream" method channel
  func startStreaming() {
    // This is the "market-killer" trick. To get real-time HR/HRV,
    // we must start an Apple Watch "Workout Session".
    let workoutConfiguration = HKWorkoutConfiguration()
    workoutConfiguration.activityType = .mindAndBody // Perfect for Elara
    workoutConfiguration.locationType = .unknown

    do {
      workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: workoutConfiguration)
    } catch {
      eventSink?(FlutterError(code: "WORKOUT_ERROR", message: "Failed to create workout session", details: error.localizedDescription))
      return
    }

    // --- Create the Heart Rate Query ---
    let hrType = HKObjectType.quantityType(forIdentifier: .heartRate)!
    heartRateQuery = HKStreamingQuery(
      quantityType: hrType,
      predicate: nil,
      updateHandler: { [weak self] query, samples, deletedObjects, anchor, error in
        guard let samples = samples as? [HKQuantitySample] else { return }
        // Send the data to Flutter
        self?.sendHealthData(samples: samples)
      }
    )
    
    // --- Create the HRV Query ---
    let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
    hrvQuery = HKStreamingQuery(
      quantityType: hrvType,
      predicate: nil,
      updateHandler: { [weak self] query, samples, deletedObjects, anchor, error in
        guard let samples = samples as? [HKQuantitySample] else { return }
        // Send the data to Flutter
        self?.sendHealthData(samples: samples)
      }
    )

    // --- Start everything! ---
    // Make sure queries have been created before executing
    guard let hrQuery = heartRateQuery, let hrvQuery = hrvQuery else {
        eventSink?(FlutterError(code: "QUERY_ERROR", message: "Failed to create queries", details: nil))
        return
    }
    
    workoutSession?.start()
    healthStore.execute(hrQuery)
    healthStore.execute(hrvQuery)
  }
  
  // --- 3. STOP THE STREAM ---
  // This is called from AppDelegate via the "stopHealthStream" method channel
  func stopStreaming() {
    workoutSession?.stop()
    
    if let query = heartRateQuery { healthStore.stop(query) }
    if let query = hrvQuery { healthStore.stop(query) }
    
    heartRateQuery = nil
    hrvQuery = nil
    workoutSession = nil
  }
  
  // --- 4. SEND DATA TO FLUTTER ---
  private func sendHealthData(samples: [HKQuantitySample]) {
    for sample in samples {
      var data: [String: Any] = [
        "timestamp": sample.endDate.timeIntervalSince1970
      ]
      
      if sample.quantityType.identifier == HKQuantityTypeIdentifier.heartRate.rawValue {
        let value = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
        data["hr"] = value
      } else if sample.quantityType.identifier == HKQuantityTypeIdentifier.heartRateVariabilitySDNN.rawValue {
        let value = sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
        data["hrv"] = value
      }
      
      // Send this data map to the Flutter EventChannel
      // Only send if we actually added HR or HRV data
      if data.keys.count > 1 {
        self.eventSink?(data)
      }
    }
  }
}