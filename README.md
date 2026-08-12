# Archive

Archive is a private-first personal productivity, health, and workout tracker. It combines daily habits, hydration, sleep, workout planning, workout history, and an approval-based AI coach in one compact interface.

![Archive app overview](docs/screenshots/archive-overview.png)

## Highlights

- Daily habit, water, and sleep tracking
- Curated Today and metric story pages with optional pinned panels
- Purposeful chart, progress, page, and interaction motion with reduced-motion support
- Weekly workout scheduling and editable routines
- Exercise library with equipment and build-focus profiles
- Detailed workout logging and monthly workout history
- Gemini-powered coaching with reviewable changes
- Local JSON backup and restore
- Canonical Health Connect archive with launch and pull-to-refresh syncing, source provenance, reconciliation, and watch-first sleep precedence
- Android packaging through Capacitor

## Privacy

Archive stores app state and the optional Gemini API key locally on the device. API keys are not hard-coded into the project or included in Archive JSON backups.

Do not commit personal backup exports, browser profiles, local Android configuration, or environment files.

## Tech stack

- React 19
- Vite 7
- Capacitor 7
- Android Studio and Gradle
- Browser `localStorage`
- Google Gemini API

## Run locally

Requirements:

- Node.js
- npm

```powershell
npm install
npm run dev
```

Vite prints the local development URL in the terminal.

## Build the web app

```powershell
npm run verify
```

`npm run verify` checks the repository contract, health/sleep synchronization rules, Workout Mode, motion safeguards, and the production web build. Pull requests and pushes to `main` run the same gate plus Android tests, lint, and debug assembly through GitHub Actions.

## Build the Android APKs

```powershell
npm run build
npx cap sync android
cd android
.\gradlew.bat assembleDebug
.\gradlew.bat assembleRelease
```

The APKs are generated at:

```text
android/app/build/outputs/apk/debug/app-debug.apk
android/app/build/outputs/apk/release/app-release.apk
```

Release packaging verifies the existing Archive signing certificate and refuses an incompatible key. See [`MULTI_COMPUTER_SETUP.md`](MULTI_COMPUTER_SETUP.md) before building on another computer.

## Versioned releases

Archive uses semantic pre-release versions recorded in [`VERSION`](VERSION). To build a signed release and preserve the current version locally and in Google Drive, run:

```powershell
npm run release:build
```

The release script refuses to overwrite an existing version. Release notes and APK locations are indexed in [`RELEASES.md`](RELEASES.md), while user-facing changes are maintained in [`CHANGELOG.md`](CHANGELOG.md).

## Product and development references

- [`docs/PRODUCT.md`](docs/PRODUCT.md) — current product contract and page hierarchy
- [`docs/DESIGN_SYSTEM.md`](docs/DESIGN_SYSTEM.md) — Archive Canvas visual and motion language
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — data, native, persistence, and build boundaries
- [`docs/DECISIONS.md`](docs/DECISIONS.md) — accepted and rejected directions
- [`docs/DEVELOPMENT_WORKFLOW.md`](docs/DEVELOPMENT_WORKFLOW.md) — concise branch and approval flow
- [`docs/specs/TEMPLATE.md`](docs/specs/TEMPLATE.md) — major-change specification template
- [`docs/reference/README.md`](docs/reference/README.md) — curated visual baseline

The canonical repository is [github.com/yeuki/Archive](https://github.com/yeuki/Archive).

## Data model

Archive does not generate simulated history for new users. Daily records and completed workouts are persisted only after user actions. A workout enters history only after **Finish workout** is selected.

Health Connect data is normalized into one local, versioned health archive. When import is enabled, Archive performs an authoritative 30-day reconciliation during cold launch and whenever the user completes a pull-to-refresh gesture on a main page. There is no periodic, resume, or background polling. Each refresh reconciles daily totals, sleep sessions, and workouts—including corrections and deletions—while high-frequency heart-rate and HRV data use a bounded rolling sample window. Each imported record retains provider, source, timezone, and import provenance.

## Project status

Archive is an actively developed personal application. The repository contains the web source and Android project, but excludes generated builds and private local data.
