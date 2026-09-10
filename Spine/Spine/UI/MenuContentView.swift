import AppKit
import SwiftUI

/// The MenuBarExtra window content; what's shown changes with `SpineViewModel.state`.
struct MenuContentView: View {
    @Environment(SpineViewModel.self) private var viewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            brandHeader

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

            HStack {
                languagePicker

                Spacer()

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Text(viewModel.localized("Quit", comment: "Quit menu item"))
                }
                .buttonStyle(.plain)
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(width: 280)
    }

    // MARK: - Brand

    private var brandHeader: some View {
        HStack(spacing: 8) {
            SpineMark()
                .frame(width: 16, height: 20)
            Text("Spine")
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - States

    private var waitingForAirPodsContent: some View {
        VStack(spacing: 10) {
            Image(systemName: "airpods")
                .font(.system(size: 32))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)

            VStack(spacing: 4) {
                Text(viewModel.localized("Connect your AirPods", comment: "Title shown while waiting for AirPods"))
                    .font(.headline)
                Text(viewModel.localized("Spine tracks posture using your AirPods' head motion sensors.", comment: "Explanation shown while waiting for AirPods"))
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
            header(icon: "checklist", tint: .orange, title: viewModel.localized("Calibration needed", comment: "Title shown when calibration is required"))

            if viewModel.calibrationFeedback == .tooMuchMovement {
                Label {
                    Text(viewModel.localized("You moved too much. Try again.", comment: "Shown after a rejected calibration attempt"))
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .font(.subheadline)
                .foregroundStyle(.orange)
            }

            Button {
                viewModel.startCalibration()
            } label: {
                Text(viewModel.localized("Calibrate", comment: "Button to start calibration"))
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
                    ? viewModel.localized("Posture is bad", comment: "Status line when posture is bad")
                    : viewModel.localized("Posture is good", comment: "Status line when posture is good")
            )

            if let deviation = viewModel.currentDeviationDegrees {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(viewModel.localized("Deviation:", comment: "Label prefix for the live posture deviation reading"))
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
                Picker(viewModel.localized("Sensitivity", comment: "Sensitivity picker label"), selection: sensitivityBinding) {
                    Text(viewModel.localized("Low", comment: "Low sensitivity option")).tag(PostureSensitivity.low)
                    Text(viewModel.localized("Medium", comment: "Medium sensitivity option")).tag(PostureSensitivity.medium)
                    Text(viewModel.localized("High", comment: "High sensitivity option")).tag(PostureSensitivity.high)
                }
                .pickerStyle(.menu)

                Picker(viewModel.localized("Cooldown", comment: "Cooldown picker label"), selection: cooldownBinding) {
                    ForEach(SettingsStore.cooldownOptions, id: \.self) { seconds in
                        Text(verbatim: "\(Int(seconds)) \(viewModel.localized("s", comment: "Abbreviation for seconds, shown after a cooldown number"))").tag(seconds)
                    }
                }
                .pickerStyle(.menu)

                Toggle(viewModel.localized("Voice alerts", comment: "Voice alerts toggle label"), isOn: voiceEnabledBinding)

                if viewModel.settings.voiceEnabled {
                    Picker(viewModel.localized("Voice", comment: "Voice gender picker label"), selection: voiceGenderBinding) {
                        Text(viewModel.localized("Automatic", comment: "Automatic voice gender option")).tag(VoiceGenderPreference.automatic)
                        Text(viewModel.localized("Female", comment: "Female voice gender option")).tag(VoiceGenderPreference.female)
                        Text(viewModel.localized("Male", comment: "Male voice gender option")).tag(VoiceGenderPreference.male)
                    }
                    .pickerStyle(.menu)
                }
            }
            .padding(10)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 8) {
                Button {
                    viewModel.startCalibration()
                } label: {
                    Text(viewModel.localized("Recalibrate", comment: "Button to restart calibration"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    viewModel.togglePause()
                } label: {
                    Text(viewModel.localized("Pause", comment: "Button to pause monitoring"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var pausedContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            header(icon: "pause.circle.fill", tint: .secondary, title: viewModel.localized("Paused", comment: "Title shown while monitoring is paused"))

            Button {
                viewModel.togglePause()
            } label: {
                Text(viewModel.localized("Resume", comment: "Button to resume monitoring"))
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

    private var languagePicker: some View {
        Picker(selection: languageBinding) {
            Text(viewModel.localized("System", comment: "Language option: follow the system language")).tag(LanguagePreference.system)
            Text(verbatim: "English").tag(LanguagePreference.en)
            Text(verbatim: "Türkçe").tag(LanguagePreference.tr)
        } label: {
            Image(systemName: "globe")
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .fixedSize()
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

    private var voiceGenderBinding: Binding<VoiceGenderPreference> {
        Binding(
            get: { viewModel.settings.voiceGender },
            set: { viewModel.updateVoiceGender($0) }
        )
    }

    private var languageBinding: Binding<LanguagePreference> {
        Binding(
            get: { viewModel.settings.languagePreference },
            set: { viewModel.updateLanguagePreference($0) }
        )
    }
}

/// Small vertebrae-column mark used as Spine's in-menu brand icon.
private struct SpineMark: View {
    private let vertebraeCount = 5

    var body: some View {
        VStack(spacing: 2) {
            ForEach(0..<vertebraeCount, id: \.self) { index in
                Capsule()
                    .fill(Color.accentColor.opacity(1 - Double(index) * 0.14))
                    .frame(height: 3)
                    .frame(maxWidth: .infinity)
                    .scaleEffect(x: 1 - Double(index) * 0.12, anchor: .center)
            }
        }
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
