# Local reminders

Status: Candidate  
Branch: `feature/local-reminders`  
Baseline: `c966e2c` (`feature/truthful-home-continuity`)

## Goal

Offer small, opt-in daily reminders for habit logging and water logging. A tap must retain Archive's launch experience, then open the exact logging destination without introducing a second navigation step.

## Product contract

- Both reminders default off and have independent daily times.
- Android notification permission is requested only when a user enables a reminder.
- Notification text remains generic and exposes no habit names, measurements, or health values on the lock screen.
- A habit reminder opens the Habit page. A water reminder opens today's Daily Sheet, scrolls to the water input, and focuses it.
- Cold-start taps are queued until launch reconciliation and the smooth loading-screen transition reach `ready`.
- Reminders do not trigger, alter, or expand Health Connect reads.
- Browser preview saves and demonstrates settings but does not create browser notifications.
- Scheduling uses repeating calendar notifications and does not request exact-alarm privileges.

## Acceptance checks

- Pure reminder normalization, payloads, IDs, and tap destinations are covered by `npm run test:reminders`.
- The repository-wide `npm run verify` suite passes.
- `npm run cap:sync` installs the Capacitor 7 local-notifications plugin into Android.
- Android compilation and device-level delivery/tap tests remain required on a Java 21 + Android SDK workstation before release.
