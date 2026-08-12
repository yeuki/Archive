# Archive product contract

This document describes the product Archive is intended to be. It is the durable reference for scope, hierarchy, and user-facing behavior. Historical release notes explain what changed; this document explains what should be true now.

## Purpose

Archive is a private, local-first personal system for understanding productivity, health, and training without turning daily tracking into administrative work. It should help one person record a day, notice useful patterns, complete a workout, and review history through a calm and coherent mobile experience.

## Product principles

1. **Personal before social.** Archive has no feeds, rankings, advertising, or public profile.
2. **Fast capture, rich review.** Recording should be brief; deeper information appears when the user asks for it.
3. **Truthful data.** New users receive useful structure but no fabricated personal history.
4. **Local ownership.** Core data remains usable without an account or backend and can be exported as JSON.
5. **Progressive disclosure.** A screen should foreground its primary task instead of showing every available metric or control.
6. **Stable mental model.** Navigation and data meaning should not drift as adjacent features are added.
7. **Review before automation.** AI-proposed changes remain visible and require approval before application.

## Information architecture

The center Home control is surrounded by two expandable navigation groups. These destinations remain separate unless a later approved specification explicitly changes the hierarchy.

| Group | Destination | Primary purpose |
| --- | --- | --- |
| Center | Home | Today's concise overview, daily capture, and curated modules |
| Productivity | Workout | Schedule, routines, exercise library, and focused Workout Mode |
| Productivity | Workout History | Calendar and complete records of finished workouts |
| Productivity | Habit | Habit records, trends, and configurable habit modules |
| Productivity | AI Coach | Conversation, analysis, and reviewable app changes |
| Health | Water | Hydration records, goal progress, and water modules |
| Health | Sleep | Manual/watch sleep records, trends, and sleep modules |
| Health | Stats | Cross-metric summaries, comparisons, and correlations |
| Health | Settings | Goals, Health Connect, data layers, backup, and app configuration |

## Core experiences

### Record a day

- The user can record or edit habits, hydration, and sleep for a selected date.
- Sleep offers watch sync as the primary path and manual entry as a fallback.
- A synced sleep record supersedes a conflicting manual record.
- A sleep session is attributed to the calendar day before its wake date, independent of the clock hour.
- Historical records remain editable and are not deleted when a habit is disabled.

### Understand patterns

- Home and metric pages use configurable modules for summaries, grids, trends, distributions, comparisons, and correlations.
- Modules can be added from a gallery, configured, removed, and reordered.
- A visualization must retain an understandable value, date span, and detail path; visual polish cannot obscure meaning.
- Semantic colors identify Habit, Sleep, Water, and Move consistently.

### Plan and complete training

- The user maintains an exercise library, routines, equipment profile, build focus, and weekly schedule.
- Starting a routine enters a focused full-page Workout Mode that presents one set at a time.
- Weight, repetitions, and optional effort are touch-friendly and inherit sensible recent values.
- Completing a set saves immediately and begins the configured rest flow.
- The active session autosaves and resumes after navigation, app suspension, or process restart.
- Only **Finish workout** creates a workout-history entry.
- History supports multiple workouts per date and preserves each exercise, set, weight, repetition, effort, duration, and note.

### Connect watch data

- Android Health Connect is the current bridge for supported Samsung Health data and future compatible providers.
- User-facing synchronization has exactly two triggers: launch initialization and a completed pull-to-refresh gesture.
- Launch synchronization is hidden behind the centered Archive A loading treatment; pull-to-refresh remains non-blocking.
- Imported records retain provenance and are reconciled so corrections and deletions do not leave stale summaries.

### Work with the coach

- The coach can use the user's local health, productivity, workout, schedule, equipment, and build-focus context.
- It can explain patterns and prepare supported workout/configuration proposals.
- Every mutation is reviewable; invalid suggestions are shown as skipped with a reason.
- The Gemini API key is optional, local, and excluded from normal backups.

## Data ownership and privacy

- App state is persisted locally in browser/Capacitor storage.
- JSON export is the portable user-controlled backup and import normalizes supported older formats.
- Personal backups, credentials, signing material, and local Android configuration are never repository content.
- Archive currently has no public account system, shared cloud database, or public multi-user backend.

## Product boundaries

Archive is not currently intended to be:

- A medical diagnostic tool or a substitute for clinical advice.
- A social fitness network.
- A live coaching service that silently changes plans.
- A cloud-first service that requires connectivity for core records.
- A collection of dense dashboards with every metric visible at once.

## Standard for change

A major change must identify the user problem, what remains unchanged, intended screens and states, acceptance criteria, and release impact. Use [`docs/specs/TEMPLATE.md`](specs/TEMPLATE.md) and the approval flow in [`docs/DEVELOPMENT_WORKFLOW.md`](DEVELOPMENT_WORKFLOW.md).
