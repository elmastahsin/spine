import SwiftUI

/// Shown while `SpineViewModel` is running its 3-second calibration countdown.
struct CalibrationView: View {
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "Calibrating…", comment: "Calibration in-progress title"))
                .font(.headline)
            Text(String(localized: "Sit up straight and look at the screen.", comment: "Calibration in-progress instruction"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ProgressView(value: progress)
        }
    }
}
