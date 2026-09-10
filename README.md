# Spine

Spine is an open-source macOS menu bar app that watches your posture using the
motion sensors built into your AirPods. It tracks how far your head tilts
from a calibrated baseline and gives you a short spoken nudge when you've
been slouching for too long — no camera, no network calls, no third-party
dependencies, and no data ever leaves your Mac.

## Requirements

- macOS 14.0 or later.
- AirPods with head tracking support: AirPods Pro (any generation), AirPods
  Max, or AirPods (3rd generation) or later. Older AirPods models don't
  expose motion data and won't work with Spine.

## Build

Open `Spine/Spine.xcodeproj` in Xcode and run, or build from the command line:

```
xcodebuild -project Spine/Spine.xcodeproj -scheme Spine -configuration Debug build
```

Run the test suite (covers the posture-evaluation and calibration logic,
no AirPods required):

```
xcodebuild -project Spine/Spine.xcodeproj -scheme Spine -destination 'platform=macOS' test
```

## Privacy

Spine only reads head motion data from your AirPods while they're connected.
That data is processed entirely on your Mac to compute posture state — it is
never written to disk beyond your calibration baseline, never transmitted
over the network, and there is no analytics or telemetry of any kind.

## Known limitations

- AirPods measure the rotation of your head, not your spine. Spine can tell
  when your head has tilted away from your calibrated baseline, but it has
  no way to observe your actual back or shoulder posture.
- Looking down at a keyboard or trackpad briefly can register as posture
  drift like any other head tilt. The grace period before a nudge fires is
  meant to absorb short glances, but sustained keyboard-heavy work may still
  trigger occasional false positives.
- Spoken Turkish alerts require a Turkish system voice. If none is installed,
  open **System Settings → Accessibility → Spoken Content → System Voice**
  and download a Turkish voice, or Spine will fall back to whatever voice
  macOS picks for the `tr-TR` language.

## License

MIT — see [LICENSE](LICENSE).
