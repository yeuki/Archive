import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import {
  DEFAULT_REMINDERS,
  enabledReminderNotifications,
  normalizeReminders,
  notificationDestination,
  REMINDER_IDS,
} from "../src/reminders.js";

const normalized = normalizeReminders({
  habits: { enabled: true, time: "09:35" },
  water: { enabled: true, time: "99:00" },
});
assert.deepEqual(normalized.habits, { enabled: true, time: "09:35" });
assert.deepEqual(normalized.water, { enabled: true, time: DEFAULT_REMINDERS.water.time });

const scheduled = enabledReminderNotifications(normalized);
assert.equal(scheduled.length, 2);
assert.deepEqual(scheduled[0].schedule, { on: { hour: 9, minute: 35 }, repeats: true });
assert.equal(scheduled[0].id, REMINDER_IDS.habits);
assert.equal(scheduled[0].extra.archiveDestination, "habits");
assert.equal(scheduled[1].extra.archiveDestination, "water");
assert.equal(enabledReminderNotifications({}).length, 0);

assert.equal(notificationDestination({ notification: { extra: { archiveDestination: "water" } } }), "water");
assert.equal(notificationDestination({ notification: { data: { archiveDestination: "habits" } } }), "habits");
assert.equal(notificationDestination({ notification: { extra: { archiveDestination: "settings" } } }), null);

const [appSource, nativeSource, manifest] = await Promise.all([
  readFile(new URL("../src/App.jsx", import.meta.url), "utf8"),
  readFile(new URL("../src/localNotifications.js", import.meta.url), "utf8"),
  readFile(new URL("../android/app/src/main/AndroidManifest.xml", import.meta.url), "utf8"),
]);
assert.match(nativeSource, /requestPermissions\(\)/);
assert.match(nativeSource, /localNotificationActionPerformed/);
assert.match(appSource, /launchPhase !== "ready" \|\| !pendingReminderDestination/);
assert.match(appSource, /initialFocus="?\{dailySheetFocus\}"?/);
assert.doesNotMatch(manifest, /SCHEDULE_EXACT_ALARM|USE_EXACT_ALARM/);

console.log("Reminder verification passed.");
