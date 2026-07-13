# Archive release process

Archive uses semantic versioning while it is in pre-release development:

- Minor (`0.2.0`): substantial features, redesigns, navigation changes, or structural work.
- Patch (`0.2.1`): focused fixes and small adjustments that do not materially change the experience.
- Major (`1.0.0`): a stable release or a later compatibility-breaking release.

## Required release steps

1. Choose the version before implementation and update `VERSION`, `package.json`, `CHANGELOG.md`, and `RELEASES.md`.
2. Confirm the Android version derives correctly from `VERSION`.
3. Run `npm run release:build`.
4. Verify the APK and its SHA-256 checksum in the local and Google Drive release folders.
5. Install and smoke-test the APK on an Android phone when available.
6. Commit the release, create an annotated `vX.Y.Z` Git tag, and push both to GitHub.
7. Attach the APK to the matching GitHub release when GitHub release tooling is available.

## Storage layout

```text
Local project/
  releases/
    v0.1.0/
      Archive-v0.1.0.apk
      Archive-v0.1.0.apk.sha256

Google Drive/Archive Productivity Tracker/
  Releases/
    v0.1.0/
      Archive-v0.1.0.apk
      Archive-v0.1.0.apk.sha256
```

The release script refuses to overwrite either local or Drive APKs. A different binary requires a new version.
