# Major change: <short name>

> Copy this file to `docs/specs/YYYY-MM-DD-short-name.md`. Do not edit the template for a single change.

## Control

- **Status:** Draft | Approved | In progress | Candidate | Accepted | Rejected
- **Owner:**
- **Created:** YYYY-MM-DD
- **Baseline:** version / tag / commit
- **Working branch:** `feature/<short-description>`
- **Target release:** Unreleased (default) | explicit version
- **Related issue / task:**

## Problem and user outcome

Describe the current friction in observable terms. Then state what the user should be able to do or feel after the change.

## Approved direction

Summarize the intended solution. Include the central interaction model and why it fits Archive better than the alternatives considered.

## Preserve

List behavior, data, hierarchy, and visual identity that must remain unchanged.

-

## Non-goals

List adjacent improvements that are deliberately outside this change.

-

## Screens and states

For each affected screen, describe the default, loading, empty, error, long-content, and completed states that matter.

| Screen/state | User sees | User can do | Data/source |
| --- | --- | --- | --- |
|  |  |  |  |

## Interaction and motion

Describe gestures, transitions, focus behavior, haptics, reduced-motion behavior, and what happens if the interaction is interrupted.

## Data, persistence, and compatibility

- Persisted fields added/changed:
- Normalization or migration:
- Backup/import impact:
- Offline/restart behavior:
- Health/native/API impact:
- Security/privacy impact:

Write `None` explicitly where appropriate.

## Accessibility

Cover touch targets, labels, keyboard/focus behavior, contrast, text scaling, color independence, and reduced motion.

## Acceptance criteria

- [ ] The named user problem is resolved.
- [ ] Preserved behaviors and existing personal data remain intact.
- [ ] Loading, empty, error, and interruption states are coherent.
- [ ] No horizontal overflow occurs at 360 x 800 or 412 x 915.
- [ ] Reduced-motion behavior is verified where motion changes.
- [ ] Relevant deterministic and Android checks pass.
- [ ] Durable documentation and `[Unreleased]` notes are updated.
- [ ] Additional change-specific criterion:

## Verification plan

| Risk | Check | Expected evidence |
| --- | --- | --- |
|  |  |  |

## References

Link only the curated screenshots, approved mockups, code paths, or external primary documentation that directly constrains this change.

## Open questions

-

## Decision log

| Date | Decision / revision | Approved by |
| --- | --- | --- |
|  |  |  |
