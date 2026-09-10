import Foundation

/// Top-level state of the app, driving both the menu bar icon and menu content.
enum AppState: Equatable {
    /// No AirPods with head tracking connected yet.
    case waitingForAirPods
    /// AirPods connected but no baseline has been recorded.
    case needsCalibration
    /// Calibration in progress; `progress` is 0...1 over the countdown.
    case calibrating(progress: Double)
    /// Actively tracking posture against a saved baseline.
    case monitoring(PostureStatus)
    /// Monitoring is user-paused; baseline and connection are retained.
    case paused
}
