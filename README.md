# nosugar

Every day without added sugar, a sugar crystal dissolves into a star. Consecutive
nights form a constellation.

- **Tonight**: hold the button to light tonight's star (or say you had sugar).
- **Moons**: every 7 clean nights earns one (max 3); spend it to forgive a slip.
- **Craving SOS**: 90 seconds of paced breathing while a crystal dissolves.
- **Label scanner**: on-device OCR finds sugar under other names.
- **Sky**: every constellation you've made, plus milestones (3, 7, 14, 30, 66, 100).

Flutter app for iOS and Android. Data stays on the device (shared_preferences).

## Run

```sh
flutter test
flutter run                       # debug on a simulator or device
flutter build ios --release       # then install with Xcode or devicectl
```

Demo data for screenshots: `--dart-define=DEMO=true`, optionally
`--dart-define=SCREEN=lit|sos|slip|sky|scan|onboard`.

## Layout

- `lib/state.dart`: streak, moons, constellations, persistence
- `lib/sky.dart`: crystal, constellation and burst painters
- `lib/sugar_names.dart`: hidden-sugar dictionary and matcher
- `lib/screens/`: onboarding, home (Tonight), lit, slip, sos, scan, sky
- OCR is native: Apple Vision in `ios/Runner/AppDelegate.swift`, ML Kit in
  `android/app/src/main/kotlin/.../MainActivity.kt`, via the `nosugar/ocr` channel.
