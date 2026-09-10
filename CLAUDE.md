# Spine

macOS menu bar posture app. Uses AirPods head-motion sensors (`CMHeadphoneMotionManager`)
to detect posture drift and gives a spoken nudge when the user slouches. No camera, no
network, no third-party dependencies — everything stays on-device.

## Project layout

The Xcode project lives at `Spine/Spine.xcodeproj` (target: `Spine`, scheme: `Spine`).
It uses Xcode's synchronized-folder feature (`PBXFileSystemSynchronizedRootGroup`), so
new files added under `Spine/Spine/`, `Spine/SpineTests/`, or `Spine/SpineUITests/` are
picked up automatically — **never hand-edit `project.pbxproj`**.

```
Spine/Spine/
  App/SpineApp.swift              MenuBarExtra(style: .window), injects AppState
  Core/AppState.swift              enum: waitingForAirPods, needsCalibration, calibrating(progress), monitoring(PostureStatus), paused
  Core/PostureEvaluator.swift      Pure Swift, no CoreMotion import. EMA smoothing, threshold, grace period, hysteresis, cooldown.
  Core/Calibrator.swift            Pure Swift. Mean + stddev over samples, rejects stddev > 3°.
  Services/HeadMotionService.swift CMHeadphoneMotionManager wrapper. First motion sample = "connected".
  Services/AudioNudger.swift       AVSpeechSynthesizer. Random message pick, locale-based voice.
  Services/SettingsStore.swift     UserDefaults: baseline, sensitivity, cooldown, voiceEnabled
  UI/MenuContentView.swift         Menu content driven by AppState
  UI/CalibrationView.swift         Calibration flow UI
Spine/SpineTests/
  PostureEvaluatorTests.swift
  CalibratorTests.swift
```

Posture logic (Core/) is deliberately CoreMotion-free — it takes pitch + an injected
timestamp, never `Date()` — so it's fully unit-testable without real AirPods.

## Rules

- No third-party packages. Only SwiftUI, CoreMotion, AVFoundation, Foundation, Observation.
- No network calls, analytics, or telemetry. All data stays on-device.
- Code, comments, README, and commit messages in English.
- User-facing and spoken strings are localized via String Catalog
  (`Spine/Spine/Localizable.xcstrings`) for `en` and `tr`.
- Never hand-edit `project.pbxproj`. If a change requires it (e.g. a new build setting),
  stop and ask the user to make it in Xcode.

## Build & test

```
xcodebuild -project Spine/Spine.xcodeproj -scheme Spine -configuration Debug build
xcodebuild -project Spine/Spine.xcodeproj -scheme Spine -destination 'platform=macOS' test
```

Run the build after every phase of work before moving on.
