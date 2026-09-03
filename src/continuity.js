import { isDailyFieldRecorded, normalizeRecordedFields, setDailyFieldRecorded } from "./dailyRecords.js";

export const DEFAULT_CONTINUITY = Object.freeze({
  preferredWaterMl: 250,
  lastOpenedAt: "",
  previousOpenAt: "",
  dismissedWeeklyReview: "",
  dailyDrafts: {},
});

const WATER_INCREMENTS = new Set([250, 500]);

function validTimestamp(value) {
  if (typeof value !== "string" || !value.trim()) return "";
  const parsed = Date.parse(value);
  return Number.isFinite(parsed) ? new Date(parsed).toISOString() : "";
}

export function normalizeContinuity(value = {}) {
  const source = value && typeof value === "object" ? value : {};
  const preferredWaterMl = Number(source.preferredWaterMl);
  const rawDrafts = source.dailyDrafts && typeof source.dailyDrafts === "object" ? source.dailyDrafts : {};
  const dailyDrafts = Object.fromEntries(Object.entries(rawDrafts)
    .filter(([date, draft]) => /^\d{4}-\d{2}-\d{2}$/.test(date) && draft && typeof draft === "object")
    .slice(-14)
    .map(([date, draft]) => [date, {
      water: typeof draft.water === "string" ? draft.water.slice(0, 20) : "",
      manualSleep: typeof draft.manualSleep === "string" ? draft.manualSleep.slice(0, 20) : "",
      sleepMode: draft.sleepMode === "manual" ? "manual" : "sync",
      habits: draft.habits && typeof draft.habits === "object"
        ? Object.fromEntries(Object.entries(draft.habits).map(([habit, done]) => [String(habit).slice(0, 80), Boolean(done)]))
        : {},
      updatedAt: validTimestamp(draft.updatedAt),
    }]));

  return {
    preferredWaterMl: WATER_INCREMENTS.has(preferredWaterMl) ? preferredWaterMl : DEFAULT_CONTINUITY.preferredWaterMl,
    lastOpenedAt: validTimestamp(source.lastOpenedAt),
    previousOpenAt: validTimestamp(source.previousOpenAt),
    dismissedWeeklyReview: /^\d{4}-\d{2}-\d{2}$/.test(source.dismissedWeeklyReview ?? "") ? source.dismissedWeeklyReview : "",
    dailyDrafts,
  };
}

export function addWaterToEntries(entries = [], { date, amount, habitNames = [] }) {
  const safeAmount = Math.max(0, Math.round(Number(amount) || 0));
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || !safeAmount) return entries;
  const index = entries.findIndex((entry) => entry?.date === date);
  const existing = index >= 0 ? entries[index] : null;
  const nextEntry = setDailyFieldRecorded({
    ...(existing ?? {}),
    date,
    habits: existing?.habits ?? Object.fromEntries(habitNames.map((habit) => [habit, false])),
    water: Math.max(0, Number(existing?.water) || 0) + safeAmount,
    sleep: Number(existing?.sleep) || 0,
    recordedFields: normalizeRecordedFields(existing),
  }, "water", true);
  const next = index >= 0 ? entries.map((entry, entryIndex) => entryIndex === index ? nextEntry : entry) : [...entries, nextEntry];
  return next.sort((a, b) => a.date.localeCompare(b.date));
}

export function restoreWaterInEntries(entries = [], { date, previousEntry }) {
  if (previousEntry) {
    const found = entries.some((entry) => entry?.date === date);
    const next = found ? entries.map((entry) => entry?.date === date ? previousEntry : entry) : [...entries, previousEntry];
    return next.sort((a, b) => a.date.localeCompare(b.date));
  }
  return entries.filter((entry) => entry?.date !== date);
}

export function chooseHomeContinuation({ todayEntry, habitNames = [], goals = {}, workout = {}, scheduledRoutine = null }) {
  const active = workout?.activeSession;
  if (active) {
    const stats = active.exercises?.flatMap((exercise) => exercise.sets ?? []) ?? [];
    const completed = stats.filter((set) => ["complete", "failed", "skipped"].includes(set.status)).length;
    return {
      kind: active.status === "summary" ? "workout-summary" : "active-workout",
      eyebrow: active.status === "summary" ? "Ready to finish" : "Continue workout",
      title: active.routineName || "Active workout",
      copy: active.status === "summary" ? "Review the saved session and finish when it looks right." : `Resume at your exact saved position · ${completed} sets completed.`,
      actionLabel: active.status === "summary" ? "Review" : "Resume",
      status: "active",
    };
  }

  if (scheduledRoutine) {
    return { kind: "scheduled-workout", eyebrow: "Scheduled today", title: scheduledRoutine.name, copy: "Your planned routine is ready without any setup steps.", actionLabel: "Start workout", status: "active" };
  }

  const habitsRecorded = isDailyFieldRecorded(todayEntry, "habits");
  const pendingHabit = habitNames.find((habit) => !todayEntry?.habits?.[habit]);
  if (!habitsRecorded || pendingHabit) {
    return { kind: "habit", eyebrow: "Next habit", title: pendingHabit || "Record habits", copy: "Open the focused hold interaction. Other daily fields stay untouched.", actionLabel: "Open habit", status: "active" };
  }

  const waterRecorded = isDailyFieldRecorded(todayEntry, "water");
  const water = Number(todayEntry?.water) || 0;
  if (!waterRecorded || water < Number(goals.waterTarget || 0)) {
    return { kind: "water", eyebrow: waterRecorded ? "Hydration" : "Quick capture", title: waterRecorded ? `${Math.round(water)} mL recorded` : "Add water", copy: waterRecorded ? `${Math.max(0, Math.round(Number(goals.waterTarget || 0) - water))} mL remains to your chosen target.` : "Record only hydration; habits and sleep remain unchanged.", actionLabel: "Add water", status: "active" };
  }

  return { kind: "caught-up", eyebrow: "Archive", title: "Caught up for now", copy: "Nothing needs your attention. Expected-later sleep will arrive after your next sleep session.", actionLabel: "", status: "complete" };
}

export function buildWeeklyReflection(entries = [], { today = new Date() } = {}) {
  const end = new Date(today);
  const recentStart = new Date(today);
  recentStart.setDate(recentStart.getDate() - 6);
  const previousStart = new Date(today);
  previousStart.setDate(previousStart.getDate() - 13);
  const dateKey = (date) => date.toISOString().slice(0, 10);
  const recent = entries.filter((entry) => entry.date >= dateKey(recentStart) && entry.date <= dateKey(end));
  const previous = entries.filter((entry) => entry.date >= dateKey(previousStart) && entry.date < dateKey(recentStart));
  const recordedSleep = (items) => items.filter((entry) => isDailyFieldRecorded(entry, "sleep") && Number.isFinite(Number(entry.sleep)));
  const recentSleep = recordedSleep(recent);
  const previousSleep = recordedSleep(previous);
  if (recent.length < 5 || recentSleep.length < 3) return { available: false, coverage: recent.length, required: 5 };
  const average = (items) => items.reduce((sum, entry) => sum + Number(entry.sleep), 0) / items.length;
  const currentAverage = average(recentSleep);
  const priorAverage = previousSleep.length >= 3 ? average(previousSleep) : null;
  return {
    available: true,
    coverage: recent.length,
    title: "Your week in Archive",
    copy: priorAverage === null
      ? `Sleep averaged ${currentAverage.toFixed(1)} hours across ${recentSleep.length} recorded nights.`
      : `Sleep averaged ${Math.abs(currentAverage - priorAverage).toFixed(1)} hours ${currentAverage >= priorAverage ? "more" : "less"} than your previous recorded week.`,
  };
}
