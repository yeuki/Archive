# Local demo data

Archive keeps new-user and production state free of simulated personal history. For explicit local testing, the repository includes an opt-in demo-backup generator.

From the repository root:

```powershell
npm run demo:data
```

This creates `backups/archive-demo-backup.json`. The `backups/` directory is ignored by Git. The generated dates are relative to the day the command runs and the file is clearly marked as demo data.

Import the file through Archive's backup control in a browser preview. Import replaces the current state in that browser profile, so export any local data worth keeping first. It does not affect the Android phone, another browser profile, GitHub, or a release artifact.

The fixture exercises:

- Two weeks of complete and partial daily records.
- Truthful weekly summaries and evidence thresholds.
- A gentle return-after-absence state.
- Quick hydration, remembered increments, and exact undo.
- Watch/manual sleep provenance.
- Three completed workouts in Workout History.
- Empty workout scheduling so hydration remains the visible Home continuation.

Rerun the command whenever a current-date fixture is needed.
