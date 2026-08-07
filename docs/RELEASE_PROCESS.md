# Archive release process

Archive uses semantic versioning while it is in pre-release development:

- Minor (`0.2.0`): substantial features, redesigns, navigation changes, or structural work.
- Patch (`0.2.1`): focused fixes and small adjustments that do not materially change the experience.
- Major (`1.0.0`): a stable release or a later compatibility-breaking release.

## Required release steps

1. Choose the version before implementation and update `VERSION`, `package.json`, `CHANGELOG.md`, and `RELEASES.md`.
2. Confirm the Android version derives correctly from `VERSION`.
3. Add the new `RELEASES.md` entry with `PENDING-FINAL-BUILD`, commit the release changes on `main`, and push them to GitHub. The local and remote `main` commits must match exactly.
4. Run `npm run release:build`. The script runs the checks/build, replaces the pending checksum with the final APK hash, commits and pushes that finalized record, pushes the unique annotated `vX.Y.Z` tag as the cross-computer release claim, and then publishes the staged local and Drive artifacts.
5. Verify the APK, SHA-256 checksum, `RELEASE_NOTES.md`, and version-named release notes in the Google Drive release folder, plus the APK/checksum in the local release folder.
6. Install and smoke-test the signed release APK on an Android phone when available.
7. Confirm the pushed tag and attach the APK to the matching GitHub Release when GitHub release tooling is available.

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
      RELEASE_NOTES.md
```

The release script refuses to overwrite either local or Drive version directories, and the remote Git tag serializes publishers across computers. A different binary requires a new version.
