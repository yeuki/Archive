export const REMINDER_IDS = Object.freeze({ habits: 41001, water: 41002 });

export const DEFAULT_REMINDERS = Object.freeze({
  habits: Object.freeze({ enabled: false, time: "20:00" }),
  water: Object.freeze({ enabled: false, time: "14:00" }),
});

const VALID_DESTINATIONS = new Set(Object.keys(REMINDER_IDS));

function normalizeTime(value, fallback) {
  const match = /^(\d{2}):(\d{2})$/.exec(String(value ?? ""));
  if (!match) return fallback;
  const hour = Number(match[1]);
  const minute = Number(match[2]);
  return hour < 24 && minute < 60 ? `${match[1]}:${match[2]}` : fallback;
}

export function normalizeReminders(value = {}) {
  return Object.fromEntries(Object.entries(DEFAULT_REMINDERS).map(([kind, defaults]) => [kind, {
    enabled: Boolean(value?.[kind]?.enabled),
    time: normalizeTime(value?.[kind]?.time, defaults.time),
  }]));
}

export function reminderNotification(kind, settings) {
  if (!VALID_DESTINATIONS.has(kind)) return null;
  const normalized = normalizeReminders({ [kind]: settings })[kind];
  const [hour, minute] = normalized.time.split(":").map(Number);
  const copy = kind === "habits"
    ? { title: "Archive reminder", body: "Take a quiet moment to check today's habits." }
    : { title: "Archive reminder", body: "Take a quiet moment to add some water." };

  return {
    id: REMINDER_IDS[kind],
    ...copy,
    schedule: { on: { hour, minute }, repeats: true },
    extra: { archiveDestination: kind },
  };
}

export function enabledReminderNotifications(value) {
  const reminders = normalizeReminders(value);
  return Object.entries(reminders)
    .filter(([, settings]) => settings.enabled)
    .map(([kind, settings]) => reminderNotification(kind, settings));
}

export function notificationDestination(action) {
  const destination = action?.notification?.extra?.archiveDestination
    ?? action?.notification?.data?.archiveDestination;
  return VALID_DESTINATIONS.has(destination) ? destination : null;
}
