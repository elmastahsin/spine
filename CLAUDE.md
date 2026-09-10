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
                                    Exposes pitch (posture) and full HeadAttitude (pitch/yaw/roll, cosmetic 3D only).
  Services/AudioNudger.swift       AVSpeechSynthesizer. Random message pick, locale/gender-based voice.
  Services/SettingsStore.swift     UserDefaults: baseline, sensitivity, cooldown, voiceEnabled, voiceGender, languagePreference
  Services/LocalizedBundle.swift   Resolves the .lproj bundle for an explicit language override.
  UI/MenuContentView.swift         Menu content driven by AppState
  UI/CalibrationView.swift         Calibration flow UI
  UI/HeadVisualizationView.swift   SceneKit NSViewRepresentable: procedural 3D head, no bundled asset,
                                    tilts live with HeadAttitude.
Spine/SpineTests/
  PostureEvaluatorTests.swift
  CalibratorTests.swift
```

Posture logic (Core/) is deliberately CoreMotion-free — it takes pitch + an injected
timestamp, never `Date()` — so it's fully unit-testable without real AirPods.

## Rules

- No third-party packages. Only first-party Apple frameworks: SwiftUI, AppKit, CoreMotion,
  AVFoundation, SceneKit, Foundation, Observation.
- The 3D head in `HeadVisualizationView` is built procedurally from SceneKit primitives —
  never add a bundled/downloaded 3D asset file.
- No network calls, analytics, or telemetry. All data stays on-device.
- Code, comments, README, and commit messages in English.
- User-facing and spoken strings are localized via String Catalog
  (`Spine/Spine/Localizable.xcstrings`) for `en` and `tr`.
- Never hand-edit `project.pbxproj`. If a change requires it (e.g. a new build setting),
  stop and ask the user to make it in Xcode.

## Build & test

```
xcodebuild -project Spine/Spine.xcodeproj -scheme Spine -configuration Debug build
xcodebuild -project Spine/Spine.xcodeproj -scheme Spine -destination 'platform=macOS' test -only-testing:SpineTests
```

Run the build after every phase of work before moving on. `-only-testing:SpineTests` scopes to the
Core-layer unit tests; the Xcode-generated `SpineUITests` target assumes a normal windowed app and
is unreliable against an `LSUIElement` menu-bar-only app (no main window to launch/terminate
against), so it's not part of the required gate.
