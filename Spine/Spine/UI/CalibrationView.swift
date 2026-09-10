import SwiftUI

/// Shown while `SpineViewModel` is running its 3-second calibration countdown.
struct CalibrationView: View {
    @Environment(SpineViewModel.self) private var viewModel

    let progress: Double

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.15), value: progress)
                Text(verbatim: "\(Int(progress * 100))%")
                    .font(.system(.callout, design: .rounded))
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
            .frame(width: 64, height: 64)

            VStack(spacing: 4) {
                Text(viewModel.localized("Calibrating…", comment: "Calibration in-progress title"))
                    .font(.headline)
                Text(viewModel.localized("Sit up straight and look at the screen.", comment: "Calibration in-progress instruction"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}
