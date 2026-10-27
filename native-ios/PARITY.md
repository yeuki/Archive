# Native migration status

This is an implementation inventory, not a device-validation claim. The React/Android app is still the full functionality baseline. A feature counts as accepted only after native build/tests and appropriate physical-device checks pass.

| Experience | First native increment | Still required for full parity |
| --- | --- | --- |
| Home / design | Warm neutral canvas, semantic pastels, system serif headings/values, watch summary, contextual habit capture, hydration and workout resume | Native screenshot comparison, dynamic greeting refinement, deeper continuity/reflection rules |
| Navigation | Centered Home, expandable Productivity/Health groups, all nine destinations, system Liquid Glass on supported iOS | On-device expansion/selection motion and large-text acceptance |
| Daily storage | Atomic document writes, partial fields, dates, persistence errors, recovery copies | Long-history performance and storage-failure injection on device |
| Habit | Hold completion, assistive completion, undo, create/rename/reorder/enable/ignore, historical date selection | Native hold gesture/VoiceOver/haptic testing |
| Water | Independent increments, undo, editable daily total and target, seven-day trend | Remembered increments, alternative display units and native reminder UI |
| Sleep | Manual fallback, watch authority, previous-local-wake-day attribution, source-labelled summaries | Real Garmin stages, travel/DST, permission revocation and corrected/deleted sessions on iPhone |
| Health import | Read-only anchored HealthKit service, source/UUID provenance, explicit deletions, launch/pull reads, quantity summaries, workouts, HR and SDNN HRV | Physical Garmin/Apple Health contract, permission/recovery UX, native diagnostic details |
| Modules / analytics | Native daily bars and trend lines; add/remove/reorder. Other configurations survive migration | All remaining module kinds, span editor, grids, correlations, distributions, scoring and muscle diagrams |
| Workout planning | Native routines, exercise library and weekly schedule adapters | Verify every editing edge, equipment/build-focus controls and muscle-volume analysis |
| Workout Mode | Focused per-set flow, immediate persistence, timestamp rest controls, pause/resume, explicit finish/history; imported session compatibility | Warm-up insertion, substitutions, completed-set correction, full skip/backfill parity and gesture/picker polish |
| Workout history | Native list/detail for completed manual and imported sessions; multiple per day | Full monthly calendar and scheduled-workout backfill |
| Coach | Imported conversation review; all message/proposal data retained | New conversations, Gemini Keychain integration, validated review/apply proposals and voice features |
| Settings / backup | Goals, HealthKit setup/import switch, validated JSON file import/export and recovery | Scoring weights UI, detailed diagnostics and full reminder configuration |
| Reminders / Garmin watch actions | Existing configurations retained in backups | Native notifications, action routing and watch habit/water communication |

No native candidate should replace an existing installation as the user's sole record store until the remaining capabilities they rely on have been ported and accepted. Export a backup before installation or migration.

Native imports preserve the existing web/Android backup and unknown fields. Native-to-native backup is lossless. Older web/Android importers normalize only their known schema and may omit native HealthKit extensions; keep the original native export rather than treating a roundtrip through an older client as a full-fidelity native backup.

Initial HealthKit history is 30 days for daily metrics, sleep and workouts, and seven days for high-frequency HR/HRV. Subsequent reads are anchored increments. The first transport has explicit record/payload budgets and fails without committing if a dense history exceeds them; large-data performance/aggregation remains device-validation work. Routine creation currently has a 100-set allocation safeguard per exercise; imported active-session arrays are not truncated. Replace that safeguard with a scalable representation before claiming unrestricted routine parity.
