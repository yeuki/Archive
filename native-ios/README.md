# Archive for iPhone — native SwiftUI candidate

This is the first native increment of Archive. Open `Archive.xcodeproj`, not the older Capacitor project in `ios/`. All native screens are SwiftUI; no WebView, npm runtime or CocoaPods are required. The older web and Android apps remain the functional reference until native parity is accepted.

The approved Home direction is [A's warm colors and serif typography with C's layout](../docs/reference/native-ios-home-concept.png). Content uses matte semantic pastel surfaces. The floating centered-Home dock uses the system's actual Liquid Glass on iOS 26+, a standard material fallback on iOS 17–18, and solid material when Reduce Transparency is enabled. Titles and values use system serif fonts; controls use the system sans-serif. No custom font licenses are needed.

## Open and run on a Mac

1. Install Xcode 26 or newer and its iOS simulator runtime. Clone this branch.
2. Open `native-ios/Archive.xcodeproj` directly in Xcode. Its only package is the local, dependency-free `ArchiveCore` folder.
3. Select the `Archive` scheme and an iPhone simulator, then Run. Simulator builds do not require an Apple developer team.
4. For a physical iPhone, select your signing team under the Archive target's Signing & Capabilities, enable the existing HealthKit capability for the app identifier, connect the phone and Run. Retain the established `com.kyle.archive` identity; do not regenerate signing material. Device provisioning availability depends on the Apple account/capabilities available to that team.
5. Export a complete JSON backup from the existing Archive installation. In native Settings, import that file and review the confirmation. Native storage cannot automatically access Safari or Android storage.
6. In Settings, review Apple Health access. In Garmin Connect, enable sharing with Apple Health and sync the watch. Return to Archive and pull down. Permission review itself does not start another data read.

The native app starts with habit definitions and no personal history. The mockup's sleep, water and chart values are illustrative only and are not seeded into the app.

## Verification

On any development machine with Node:

```sh
node scripts/native-ios-project.mjs
```

On a Mac:

```sh
swift test --package-path native-ios/ArchiveCore
xcodebuild -project native-ios/Archive.xcodeproj -scheme Archive -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
# Choose an available simulator name/ID shown by xcrun simctl list devices available:
xcodebuild -project native-ios/Archive.xcodeproj -scheme Archive -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO test
```

The native GitHub Actions workflow runs domain tests, an unsigned simulator build and workout tests on a hosted Mac. That verifies compilation and deterministic behavior, not visual polish, physical watch transport, signing or device performance. See `PARITY.md` for the real migration status.

The Xcode project is generated deterministically using the Node standard library. After adding or removing Swift files, run `npm run native:project`; commit the generated project and shared scheme. No third-party project generator is required.

## Storage and recovery

The document is an atomic JSON file in the app's Application Support/Archive directory, protected until first unlock. Mutations persist before published UI changes. A failed save leaves the previous in-memory/disk document intact. A corrupt startup file blocks writes and stays recoverable instead of being overwritten by an empty document. A validated replacement import first copies the exact previous file into the on-device Recovery directory.

Complete backups preserve unknown fields, workout configuration and history, modules and coach history even before every native editor is available. Source UUIDs travel with the document. Device-specific HealthKit cursors and enabled state are reset on explicit import because a portable backup may come from another iPhone; access can then be reviewed again. A successful access-review sheet is never described as proof that every read category was allowed.

Keep health JSON files and signing assets out of Git. Native candidates remain under Unreleased until accepted; this folder does not assign or publish a new version or overwrite APK releases.
