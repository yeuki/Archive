import { Capacitor } from "@capacitor/core";
import { LocalNotifications } from "@capacitor/local-notifications";
import { enabledReminderNotifications, REMINDER_IDS } from "./reminders.js";

export function localNotificationsAvailable() {
  return typeof Capacitor.isNativePlatform === "function" && Capacitor.isNativePlatform();
}

export async function notificationPermission({ request = false } = {}) {
  if (!localNotificationsAvailable()) return "webPreview";
  const result = request
    ? await LocalNotifications.requestPermissions()
    : await LocalNotifications.checkPermissions();
  return result.display;
}

export async function syncLocalReminders(reminders) {
  if (!localNotificationsAvailable()) return { status: "webPreview", scheduled: 0 };
  const permission = await notificationPermission();
  if (permission !== "granted") return { status: permission, scheduled: 0 };

  await LocalNotifications.cancel({
    notifications: Object.values(REMINDER_IDS).map((id) => ({ id })),
  });
  const notifications = enabledReminderNotifications(reminders);
  if (notifications.length) await LocalNotifications.schedule({ notifications });
  return { status: "granted", scheduled: notifications.length };
}

export async function listenForReminderActions(listener) {
  if (!localNotificationsAvailable()) return null;
  return LocalNotifications.addListener("localNotificationActionPerformed", listener);
}
