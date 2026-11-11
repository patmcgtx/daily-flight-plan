# Daily Flight Plan for Android

An early native Android port of [Daily Flight Plan](../README.md), built in Kotlin and Jetpack Compose. The iOS app stays the source of truth for look, feel, and behavior; this port keeps the same layering and the same design, and it is deliberately small.

<p align="center">
  <img src="docs/images/ios-vs-android-light.png" alt="Daily Flight Plan on Android, light mode" width="260">
  &nbsp;&nbsp;
  <img src="docs/images/ios-vs-android-dark.png" alt="Daily Flight Plan on Android, dark mode (Paper Night)" width="260">
</p>

<!-- Optional: a side-by-side of iOS and Android, and a short demo GIF.
<p align="center"><img src="docs/images/ios-vs-android.png" alt="iOS and Android side by side" width="640"></p>
<p align="center"><img src="docs/images/android-demo.gif" alt="Adding, flagging and deferring an item" width="260"></p>
-->

## Status: v1, Cockpit tab only

**In:**

- Day navigation, with a Today / Tomorrow / Yesterday label and a "go to today" button.
- The Flight Status card (progress, editable flight name and destination, next up), the briefing row (live clock, countdown to midnight, outstanding flagged count), six day-section cards, and the Open card.
- Add, edit, complete, flag, cancel, and defer-to-tomorrow, through a bottom-sheet form with time and section pickers.
- Light ("paper") and dark ("Paper Night") themes, using the same design tokens as iOS.

**Out, on purpose:** sync, routines and templates, categories, calendar and reminders, AI summaries, drag-and-drop between sections, search and filters, and settings. The Maintenance and Nav Log tabs are "coming soon" placeholders, as on iOS.

## How it maps to the iOS app

| Concern | Android | iOS |
|---|---|---|
| Language and UI | Kotlin, Jetpack Compose | Swift, SwiftUI |
| Persistence | Room (SQLite) | SwiftData |
| Preferences | DataStore | `@AppStorage` |
| State | `ViewModel` with `StateFlow` | `@Observable` view models |
| Dependency injection | Plain constructor injection | `@Environment` |
| Unit tests | JUnit 5, with parameterized tests | Swift Testing |

The data layer depends on DAO interfaces, so repository rules are tested on the JVM with fake DAOs. The view model takes an injected clock and minute tick, so its tests never depend on the wall clock.

**Why not Kotlin Multiplatform, Flutter, or React Native?** The iOS app stays SwiftUI and SwiftData, so sharing code would have meant rewriting working iOS code. A native port also made it a fair side-by-side comparison of the two stacks.

## Tests

- **220 JVM unit tests** (no device needed), covering the model, the repository, the view model, and theme contrast.
- **14 instrumented Room tests**, which run the DAO SQL against in-memory SQLite on an emulator.
- The UI is verified by hand on an emulator, in light and dark mode. There are no Compose UI tests yet.

## Build and run

Open `android/` in Android Studio, or build from the terminal. From this directory:

```bash
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
export ANDROID_HOME=$HOME/Library/Android/sdk
./gradlew :app:assembleDebug               # build
./gradlew :app:testDebugUnitTest           # JVM unit tests
./gradlew :app:connectedDebugAndroidTest   # Room tests; needs a running emulator
```

`local.properties` (gitignored) holds `sdk.dir` and must exist on each machine. Requires minSdk 26.

## How it was built

An AI-assisted port in five phases, using the iOS app's design docs and tests as the specification: scaffold and theme, pure logic with tests, the Room layer, the Cockpit UI, and the item form. The architecture and the deviations from iOS are written down in [the port plan](docs/android-port-plan.md), which also records what is deliberately left out and why.

## Known limits

- The date and time pickers are the stock Material ones (themed, but not in the app's monospaced font).
- The launcher icon is a placeholder.
- No Compose UI tests and no CI yet for the Android build.
