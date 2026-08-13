export const DAILY_RECORD_FIELDS = ["habits", "water", "sleep"];

function emptyRecordedFields() {
  return {
    habits: false,
    water: false,
    sleep: false,
  };
}

export function normalizeRecordedFields(entry) {
  if (!entry || typeof entry !== "object") return emptyRecordedFields();

  if (entry.recordedFields && typeof entry.recordedFields === "object") {
    return {
      habits: Boolean(entry.recordedFields.habits),
      water: Boolean(entry.recordedFields.water),
      sleep: Boolean(entry.recordedFields.sleep),
    };
  }

  // Before partial records, every stored daily entry represented a submitted
  // report. Treat all of its fields as intentional so older data is unchanged.
  return {
    habits: true,
    water: true,
    sleep: true,
  };
}

export function isDailyFieldRecorded(entry, field) {
  if (!DAILY_RECORD_FIELDS.includes(field)) return false;
  return normalizeRecordedFields(entry)[field];
}

export function hasAnyDailyField(entry) {
  const fields = normalizeRecordedFields(entry);
  return DAILY_RECORD_FIELDS.some((field) => fields[field]);
}

export function setDailyFieldRecorded(entry, field, recorded = true) {
  if (!entry || !DAILY_RECORD_FIELDS.includes(field)) return entry;
  return {
    ...entry,
    recordedFields: {
      ...normalizeRecordedFields(entry),
      [field]: Boolean(recorded),
    },
  };
}

export function setHabitCompletionInEntries(entries = [], { date, habit, completed, restore = null }) {
  const safeDate = String(date ?? "").trim();
  const safeHabit = String(habit ?? "").trim();
  if (!safeDate || !safeHabit) return entries;

  const existingIndex = entries.findIndex((entry) => entry?.date === safeDate);
  const existing = existingIndex >= 0 ? entries[existingIndex] : null;
  if (!existing && !completed) return entries;

  const habits = { ...(existing?.habits ?? {}) };
  if (restore?.habitPresent) habits[safeHabit] = Boolean(restore.habitValue);
  else if (restore) delete habits[safeHabit];
  else habits[safeHabit] = Boolean(completed);
  const recordedFields = restore
    ? {
        ...normalizeRecordedFields(existing),
        habits: Boolean(restore.habitsRecorded),
      }
    : {
        ...normalizeRecordedFields(existing),
        habits: true,
      };

  // Undoing the only action on a newly-created habit-only day should restore
  // the absence of a record instead of recording a synthetic zero-percent day.
  if (
    (!completed || restore)
    && !Object.values(habits).some(Boolean)
    && !recordedFields.water
    && !recordedFields.sleep
  ) {
    return entries.filter((entry) => entry?.date !== safeDate);
  }

  const nextEntry = {
    ...(existing ?? {}),
    date: safeDate,
    habits,
    water: Number.isFinite(Number(existing?.water)) ? Number(existing.water) : 0,
    sleep: Number.isFinite(Number(existing?.sleep)) ? Number(existing.sleep) : 0,
    recordedFields,
  };

  const nextEntries = existingIndex >= 0
    ? entries.map((entry, index) => (index === existingIndex ? nextEntry : entry))
    : [...entries, nextEntry];

  return nextEntries.sort((first, second) => first.date.localeCompare(second.date));
}
