Archive's iPhone experience is being rebuilt in SwiftUI around the approved warm pastel and serif design. This draft adds the first persistent native increment while leaving the existing web and Android app available as the full functionality reference.

The candidate includes daily capture, habit management, hydration/undo, manual and imported sleep, native navigation/materials, basic charts/modules, focused workout/routine/history adapters, a one-shot HealthKit importer, and complete legacy JSON import/export. The Foundation-only core preserves unknown document fields so features still being ported do not lose their data.

This is a migration candidate, not a feature-complete replacement. `native-ios/PARITY.md` records the remaining module, Coach, notification, training and analytics work. No release version, deployment or phone installation is included.

Validation: existing `npm run verify` and the generated-project graph check pass locally. macOS domain tests, native compilation and workout tests run in this PR's native workflow. Physical Garmin transport, signing, native visual/motion quality and accessibility still need iPhone checks.
