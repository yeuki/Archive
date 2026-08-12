# Archive development workflow

This is the concise operating flow for Codex-assisted changes. It separates exploration, implementation, acceptance, and release so an experiment cannot silently become the new product baseline.

## 1. Classify the change

- **Small:** documentation, test/tooling work, or a contained correction that does not alter navigation, data meaning, architecture, core behavior, or the established visual hierarchy.
- **Major:** UI redesign, navigation/hierarchy change, substantial feature, persistence/schema change, native integration, project restructuring, or other significant behavior.

If uncertain, treat the work as major.

## 2. Major-change flow

1. **Specify:** Copy [`docs/specs/TEMPLATE.md`](specs/TEMPLATE.md) to a dated file and define the problem, preserved behavior, non-goals, states, and acceptance criteria.
2. **Approve direction:** The user approves the specification or explicitly asks to implement an equivalently detailed request.
3. **Branch:** Create `feature/<short-description>` from current `main`. Do not publish a release from this branch.
4. **Implement narrowly:** Update code, tests, the durable document affected by the change, and `[Unreleased]` notes. Avoid adjacent redesign.
5. **Verify:** Run `npm run verify`, relevant Android checks, and interactive phone-size checks proportional to risk.
6. **Review candidate:** Summarize behavior, evidence, limitations, and any device check still needed. The user accepts, requests revision, or rejects it.
7. **Merge:** After acceptance, merge/push to `main`. Choose the semantic version now unless the user already designated it.
8. **Release separately:** Update version/release records and use the immutable release process only with explicit publication authorization.

## 3. Approval gates

- **Direction gate:** Required before implementing a proposed major change unless the user already said to implement that defined change.
- **Acceptance gate:** Required before treating an experiment as the baseline or assigning/finalizing its release.
- **Publication gate:** Required before creating a tag, Drive/local release artifact, GitHub Release, or phone installation.

An instruction to implement does not automatically authorize a release. An instruction to release does not authorize unrelated scope changes.

## 4. Branches and commits

```powershell
git switch main
git pull --ff-only origin main
git switch -c feature/short-description

# Work and verify
npm run verify
git add <intentional-files>
git commit -m "Describe the completed change"
git push -u origin feature/short-description
```

Use focused commits that each describe a coherent outcome. A small, explicitly requested, low-risk change may be committed directly to `main` after verification; major changes use a branch.

## 5. Revisions, rejection, and recovery

- Revision stays on the same feature branch and updates the specification when the approved direction changes.
- Rejected work is not merged. Preserve the branch only if it has diagnostic/reference value; otherwise leave `main` untouched.
- Never use destructive Git cleanup to erase unrelated user work.
- A released baseline is recovered from its Git tag and immutable APK rather than by overwriting the release.

## 6. Definition of ready for release

- The user accepted the implementation.
- `npm run verify` passes.
- Required Android/unit/lint/device checks pass.
- Durable docs and `[Unreleased]` accurately describe the result.
- `main` is clean, pushed, and matches `origin/main`.
- A new semantic version has been chosen and no existing release path/tag will be overwritten.

Documentation and workflow-only changes that do not alter the packaged app stop after commit/push; they do not require a version bump or APK.
