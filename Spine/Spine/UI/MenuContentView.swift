import AppKit
import SwiftUI

/// The MenuBarExtra window content; what's shown changes with `SpineViewModel.state`.
struct MenuContentView: View {
    @Environment(SpineViewModel.self) private var viewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
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

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text(String(localized: "Quit", comment: "Quit menu item"))
            }
            .buttonStyle(.plain)
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 280)
    }

    // MARK: - States

    private var waitingForAirPodsContent: some View {
        VStack(spacing: 10) {
            Image(systemName: "airpods")
                .font(.system(size: 32))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)

            VStack(spacing: 4) {
                Text(String(localized: "Connect your AirPods", comment: "Title shown while waiting for AirPods"))
                    .font(.headline)
                Text(String(localized: "Spine tracks posture using your AirPods' head motion sensors.", comment: "Explanation shown while waiting for AirPods"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var needsCalibrationContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            header(icon: "checklist", tint: .orange, title: String(localized: "Calibration needed", comment: "Title shown when calibration is required"))

            if viewModel.calibrationFeedback == .tooMuchMovement {
                Label {
                    Text(String(localized: "You moved too much. Try again.", comment: "Shown after a rejected calibration attempt"))
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .font(.subheadline)
                .foregroundStyle(.orange)
            }

            Button {
                viewModel.startCalibration()
            } label: {
                Text(String(localized: "Calibrate", comment: "Button to start calibration"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func monitoringContent(status: PostureStatus) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            header(
                icon: statusIcon(status),
                tint: statusTint(status),
                title: status == .bad
                    ? String(localized: "Posture is bad", comment: "Status line when posture is bad")
                    : String(localized: "Posture is good", comment: "Status line when posture is good")
            )

            if let deviation = viewModel.currentDeviationDegrees {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(String(localized: "Deviation:", comment: "Label prefix for the live posture deviation reading"))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(verbatim: "\(Int(deviation.rounded()))°")
                            .monospacedDigit()
                            .fontWeight(.semibold)
                            .foregroundStyle(statusTint(status))
                    }
                    .font(.subheadline)

                    DeviationMeter(
                        deviationDegrees: deviation,
                        thresholdDegrees: viewModel.settings.sensitivity.thresholdDegrees,
                        tint: statusTint(status)
                    )
                }
            }

            VStack(alignment: .leading, spacing: 10) {
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
            }
            .padding(10)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 8) {
                Button {
                    viewModel.startCalibration()
                } label: {
                    Text(String(localized: "Recalibrate", comment: "Button to restart calibration"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    viewModel.togglePause()
                } label: {
                    Text(String(localized: "Pause", comment: "Button to pause monitoring"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var pausedContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            header(icon: "pause.circle.fill", tint: .secondary, title: String(localized: "Paused", comment: "Title shown while monitoring is paused"))

            Button {
                viewModel.togglePause()
            } label: {
                Text(String(localized: "Resume", comment: "Button to resume monitoring"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Shared pieces

    private func header(icon: String, tint: Color, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .font(.system(size: 15, weight: .semibold))
            Text(title)
                .font(.headline)
        }
    }

    private func statusTint(_ status: PostureStatus) -> Color {
        switch status {
        case .good: return .green
        case .drifting: return .orange
        case .bad: return .red
        }
    }

    private func statusIcon(_ status: PostureStatus) -> String {
        switch status {
        case .good: return "checkmark.circle.fill"
        case .drifting: return "exclamationmark.circle.fill"
        case .bad: return "exclamationmark.triangle.fill"
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

/// Small horizontal bar showing live deviation as a fraction of the current
/// sensitivity threshold (capped at 130% of threshold so it doesn't clip).
private struct DeviationMeter: View {
    let deviationDegrees: Double
    let thresholdDegrees: Double
    let tint: Color

    private var ratio: Double {
        guard thresholdDegrees > 0 else { return 0 }
        let cap = thresholdDegrees * 1.3
        return min(deviationDegrees, cap) / cap
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.secondary.opacity(0.15))
                RoundedRectangle(cornerRadius: 3)
                    .fill(tint)
                    .frame(width: proxy.size.width * ratio)
                    .animation(.easeInOut(duration: 0.2), value: ratio)
            }
        }
        .frame(height: 6)
    }
}
