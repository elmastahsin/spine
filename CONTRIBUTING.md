# Contributing to Spine

## Build

```
xcodebuild -project Spine/Spine.xcodeproj -scheme Spine -configuration Debug build
```

## Test

```
xcodebuild -project Spine/Spine.xcodeproj -scheme Spine -destination 'platform=macOS' test
```

## Guidelines

- No third-party dependencies — only SwiftUI, CoreMotion, AVFoundation,
  Foundation, and Observation.
- No network calls, analytics, or telemetry.
- Keep posture logic (`Spine/Spine/Core`) free of CoreMotion imports and
  free of real `Date()` calls, so it stays unit-testable without AirPods.
- The Xcode project uses synchronized folders — add new files directly under
  `Spine/Spine`, `Spine/SpineTests`, or `Spine/SpineUITests` and Xcode picks
  them up automatically. Never hand-edit `project.pbxproj`.
- User-facing and spoken strings go through `String(localized:)` and get
  added to `Spine/Spine/Localizable.xcstrings` for both `en` and `tr`.
