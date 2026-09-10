import AppKit
import SwiftUI

/// The MenuBarExtra window content; what's shown changes with `SpineViewModel.state`.
struct MenuContentView: View {
    @Environment(SpineViewModel.self) private var viewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch viewModel.state {
            case .waitingForAirPods:
                waitingForAirPodsContent
            case .needsCalibration:
                needsCalibrationContent
            case .calibrating(let progress):
                CalibrationView(progress: progress)
            case .monitoring(let status):
                monitoringContent(status: status)
            case .paused:
                pausedContent
            }

            Divider()

            Button(String(localized: "Quit", comment: "Quit menu item")) {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 260)
    }

    private var waitingForAirPodsContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(
                String(localized: "Connect your AirPods", comment: "Title shown while waiting for AirPods"),
                systemImage: "airpods"
            )
            .font(.headline)
            Text(String(localized: "Spine tracks posture using your AirPods' head motion sensors.", comment: "Explanation shown while waiting for AirPods"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var needsCalibrationContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Calibration needed", comment: "Title shown when calibration is required"))
                .font(.headline)

            if viewModel.calibrationFeedback == .tooMuchMovement {
                Text(String(localized: "You moved too much. Try again.", comment: "Shown after a rejected calibration attempt"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button(String(localized: "Calibrate", comment: "Button to start calibration")) {
                viewModel.startCalibration()
            }
        }
    }

    private func monitoringContent(status: PostureStatus) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(status == .bad
                 ? String(localized: "Posture is bad", comment: "Status line when posture is bad")
                 : String(localized: "Posture is good", comment: "Status line when posture is good"))
                .font(.headline)

            if let deviation = viewModel.currentDeviationDegrees {
                Text(verbatim: "\(String(localized: "Deviation:", comment: "Label prefix for the live posture deviation reading")) \(Int(deviation.rounded()))°")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Picker(String(localized: "Sensitivity", comment: "Sensitivity picker label"), selection: sensitivityBinding) {
                Text(String(localized: "Low", comment: "Low sensitivity option")).tag(PostureSensitivity.low)
                Text(String(localized: "Medium", comment: "Medium sensitivity option")).tag(PostureSensitivity.medium)
                Text(String(localized: "High", comment: "High sensitivity option")).tag(PostureSensitivity.high)
            }
            .pickerStyle(.menu)

            Picker(String(localized: "Cooldown", comment: "Cooldown picker label"), selection: cooldownBinding) {
                ForEach(SettingsStore.cooldownOptions, id: \.self) { seconds in
                    Text(verbatim: "\(Int(seconds)) \(String(localized: "s", comment: "Abbreviation for seconds, shown after a cooldown number"))").tag(seconds)
                }
            }
            .pickerStyle(.menu)

            Toggle(String(localized: "Voice alerts", comment: "Voice alerts toggle label"), isOn: voiceEnabledBinding)

            Divider()

            Button(String(localized: "Recalibrate", comment: "Button to restart calibration")) {
                viewModel.startCalibration()
            }
            Button(String(localized: "Pause", comment: "Button to pause monitoring")) {
                viewModel.togglePause()
            }
        }
    }

    private var pausedContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Paused", comment: "Title shown while monitoring is paused"))
                .font(.headline)
            Button(String(localized: "Resume", comment: "Button to resume monitoring")) {
                viewModel.togglePause()
            }
        }
    }

    private var sensitivityBinding: Binding<PostureSensitivity> {
        Binding(
            get: { viewModel.settings.sensitivity },
            set: { viewModel.updateSensitivity($0) }
        )
    }

    private var cooldownBinding: Binding<TimeInterval> {
        Binding(
            get: { viewModel.settings.cooldown },
            set: { viewModel.updateCooldown($0) }
        )
    }

    private var voiceEnabledBinding: Binding<Bool> {
        Binding(
            get: { viewModel.settings.voiceEnabled },
            set: { viewModel.setVoiceEnabled($0) }
        )
    }
}
