package com.kyle.archive;

import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;

import com.getcapacitor.JSArray;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

import java.util.ArrayList;
import java.util.List;

@CapacitorPlugin(name = "ConnectedHealth")
public class ConnectedHealthPlugin extends Plugin {
    private static final String HEALTH_CONNECT_PACKAGE = "com.google.android.apps.healthdata";
    private static final String PLAY_STORE_URL = "https://play.google.com/store/apps/details?id=" + HEALTH_CONNECT_PACKAGE;
    private static final String[] HEALTH_CONNECT_SETTINGS_ACTIONS = {
        "android.health.connect.action.HEALTH_CONNECT_SETTINGS",
        "androidx.health.ACTION_HEALTH_CONNECT_SETTINGS",
        "androidx.health.connect.client.ACTION_HEALTH_CONNECT_SETTINGS"
    };

    @PluginMethod
    public void getStatus(PluginCall call) {
        call.resolve(buildStatusPayload());
    }

    @PluginMethod
    public void getSupportedMetrics(PluginCall call) {
        JSObject ret = new JSObject();
        JSArray metrics = new JSArray();

        metrics.put(metric("steps", "Steps", "daily", "steps"));
        metrics.put(metric("sleep", "Sleep", "nightly", "sessions"));
        metrics.put(metric("exercise", "Exercise sessions", "as completed", "workouts"));
        metrics.put(metric("distance", "Distance", "daily", "m"));
        metrics.put(metric("activeCalories", "Active calories", "daily", "kcal"));
        metrics.put(metric("heartRate", "Heart rate", "samples", "bpm"));
        metrics.put(metric("heartRateVariability", "HRV", "samples", "ms"));
        metrics.put(metric("floors", "Floors climbed", "daily", "floors"));

        ret.put("metrics", metrics);
        call.resolve(ret);
    }

    @PluginMethod
    public void openSettings(PluginCall call) {
        JSObject status = buildStatusPayload();
        List<Intent> candidates = new ArrayList<>();
        Intent settingsIntent = firstResolvableSettingsIntent();
        boolean systemIntegrated = Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE;
        boolean packageInstalled = isPackageInstalled(HEALTH_CONNECT_PACKAGE);

        if (settingsIntent != null) {
            candidates.add(settingsIntent);
        }

        if (packageInstalled) {
            Intent appDetails = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
            appDetails.setData(Uri.parse("package:" + HEALTH_CONNECT_PACKAGE));
            candidates.add(appDetails);
        }

        candidates.add(new Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=" + HEALTH_CONNECT_PACKAGE)));
        candidates.add(new Intent(Intent.ACTION_VIEW, Uri.parse(PLAY_STORE_URL)));

        for (Intent intent : candidates) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            if (!canResolve(intent)) continue;

            try {
                getActivity().startActivity(intent);
                status.put("opened", true);
                status.put("message", packageInstalled || systemIntegrated
                    ? "Opened Health Connect settings."
                    : "Opened Health Connect install page.");
                call.resolve(status);
                return;
            } catch (ActivityNotFoundException ignored) {
                // Try the next safe fallback.
            }
        }

        status.put("opened", false);
        status.put("status", "unavailable");
        status.put("message", "Archive could not find Health Connect settings or the Play Store page on this device.");
        call.resolve(status);
    }

    private JSObject metric(String id, String label, String cadence, String unit) {
        JSObject metric = new JSObject();
        metric.put("id", id);
        metric.put("label", label);
        metric.put("cadence", cadence);
        metric.put("unit", unit);
        return metric;
    }

    private JSObject buildStatusPayload() {
        boolean systemIntegrated = Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE;
        boolean packageInstalled = isPackageInstalled(HEALTH_CONNECT_PACKAGE);
        boolean settingsResolvable = firstResolvableSettingsIntent() != null;
        boolean available = systemIntegrated || packageInstalled || settingsResolvable;

        JSObject ret = new JSObject();
        ret.put("platform", "android");
        ret.put("available", available);
        ret.put("status", available ? "available" : "unavailable");
        ret.put("systemIntegrated", systemIntegrated);
        ret.put("packageInstalled", packageInstalled);
        ret.put("settingsResolvable", settingsResolvable);
        ret.put("healthConnectPackage", HEALTH_CONNECT_PACKAGE);
        ret.put("message", available
            ? "Health Connect is available. Samsung Health can share watch data here once permissions are granted."
            : "Health Connect was not found. Install or enable it, then check again.");
        return ret;
    }

    private Intent firstResolvableSettingsIntent() {
        for (String action : HEALTH_CONNECT_SETTINGS_ACTIONS) {
            Intent directIntent = new Intent(action);
            if (canResolve(directIntent)) return directIntent;

            Intent packagedIntent = new Intent(action);
            packagedIntent.setPackage(HEALTH_CONNECT_PACKAGE);
            if (canResolve(packagedIntent)) return packagedIntent;
        }

        return null;
    }

    private boolean canResolve(Intent intent) {
        PackageManager packageManager = getContext().getPackageManager();
        return intent.resolveActivity(packageManager) != null;
    }

    private boolean isPackageInstalled(String packageName) {
        try {
            getContext().getPackageManager().getPackageInfo(packageName, 0);
            return true;
        } catch (PackageManager.NameNotFoundException ignored) {
            return false;
        }
    }
}
