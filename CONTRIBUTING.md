# Contributing to Spine

## Build

```
xcodebuild -project Spine/Spine.xcodeproj -scheme Spine -configuration Debug build
```

## Test

```
xcodebuild -project Spine/Spine.xcodeproj -scheme Spine -destination 'platform=macOS' test -only-testing:SpineTests
```

`-only-testing:SpineTests` scopes to the Core-layer unit tests. The Xcode-generated
`SpineUITests` target assumes a normal windowed app and is unreliable against an
`LSUIElement` menu-bar-only app.

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
