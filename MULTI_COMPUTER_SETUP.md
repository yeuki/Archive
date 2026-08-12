# Archive multi-computer setup

GitHub is the source of truth for editable code. Google Drive is only for versioned APKs, checksums, release notes, and an approved encrypted signing-key backup. Do not work from a source checkout synchronized by Drive.

## Clone on the laptop

Install GitHub CLI or use Git Credential Manager, then authenticate before cloning the private repository:

```powershell
gh auth status
gh auth login
git clone https://github.com/yeuki/Archive.git
cd Archive
git config pull.ff only
npm ci
```

If GitHub CLI is not used for Git credentials, sign in through Git Credential Manager when `git clone` prompts. Never paste a token into a tracked file.

Required tooling:

- Node.js 22 and npm 10 (the versions verified on the desktop)
- Java 21 or Android Studio's compatible bundled JBR
- Android SDK Platform 36, Build-Tools, and Platform-Tools
- The committed Gradle 8.11.1 wrapper

Create the untracked `android/local.properties`:

```properties
sdk.dir=C:/Users/<windows-user>/AppData/Local/Android/Sdk
```

## Restore release signing safely

Archive's published APKs use package `com.kyle.archive` and a legacy Android debug certificate with SHA-256 fingerprint:

```text
EA:CF:63:65:70:82:F5:0A:38:1C:7B:61:BA:7C:2F:B9:C9:A5:2A:F3:9B:62:F4:64:39:9B:0A:4C:36:30:D7:48
```

A newly generated laptop debug key will not match and Android will reject it as an update. Do not generate a replacement signing identity.

The desktop build falls back to the current machine's standard untracked debug keystore and verifies its certificate before packaging a release. On the laptop, restore that exact existing key to the standard `%USERPROFILE%\.android\debug.keystore` location before building. Alternatively:

1. Restore the existing key to a private folder outside the repository.
2. Copy `keystore.properties.example` to `keystore.properties`.
3. Fill it with the existing alias and password values from the password manager, or use the documented `ARCHIVE_*` environment variables.
4. Keep the file untracked.
5. Verify the identity:

```powershell
cd android
.\gradlew.bat verifyArchiveSigningCertificate
cd ..
```

The release build refuses a certificate mismatch.

No signing key or password has been copied to a new cloud location by this setup. Before making a cloud backup, get explicit approval. The recommended procedure is an AES-256-encrypted key-only archive in an access-restricted `Signing Backups` folder, with the archive passphrase kept solely in a password manager. Verify a test restore and the fingerprint above.

## Build, test, and lint

From the repository root:

```powershell
npm ci
npm run verify
npm run cap:sync
cd android
.\gradlew.bat test
.\gradlew.bat lint
.\gradlew.bat assembleDebug
.\gradlew.bat assembleRelease
cd ..
```

There is no separate ESLint configuration; Android lint is the project's lint command.

Artifacts:

```text
android/app/build/outputs/apk/debug/app-debug.apk
android/app/build/outputs/apk/release/app-release.apk
```

Install or update the release build:

```powershell
adb devices
adb install -r .\android\app\build\outputs\apk\release\app-release.apk
```

Use the full Android SDK path to `adb.exe` if it is not on `PATH`.

## Publish a versioned Google Drive release

Increase the semantic version in both `VERSION` and `package.json`, then update `CHANGELOG.md` and `RELEASES.md`. After the checks above pass:

```powershell
npm run release:build
```

If Google Drive is mounted somewhere other than `G:`, run the script directly with an override:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-release.ps1 -DriveRoot "H:\My Drive\Archive Productivity Tracker"
```

The script requires a clean, pushed `main` branch, pushes a unique annotated `vX.Y.Z` Git tag as the shared cross-computer release claim, and then stages each complete release without merging or overwriting. If another computer already claimed the tag, publication stops even when Drive has not synchronized yet. It creates:

```text
G:\My Drive\Archive Productivity Tracker\Releases\vX.Y.Z\
  Archive-vX.Y.Z.apk
  Archive-vX.Y.Z.apk.sha256
  RELEASE_NOTES.md
```

It also refreshes the Drive copies of `RELEASES.md` and `CHANGELOG.md`.

## Daily desktop/laptop workflow

Before leaving one computer:

```powershell
git status
git add <intentional-files>
git commit -m "Describe the completed change"
git push origin main
```

On the other computer, before editing:

```powershell
git status
git pull --ff-only origin main
```

For simultaneous or experimental work:

```powershell
git switch -c feature/short-description
git push -u origin feature/short-description
```

Do not edit the same uncommitted work independently on both machines. Commit and push before switching, and never substitute Drive source syncing for Git.
