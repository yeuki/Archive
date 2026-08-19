import { useCallback, useEffect, useRef, useState } from "react";

const DEFAULT_IDLE_TIMEOUT_MS = 420;
const DEFAULT_FALLBACK_DELAY_MS = 90;
const revealedChartKeys = new Set();

function defaultHost() {
  return typeof window === "undefined" ? null : window;
}

function defaultDocument() {
  return typeof document === "undefined" ? null : document;
}

function defaultStorage() {
  try {
    return typeof localStorage === "undefined" ? null : localStorage;
  } catch {
    return null;
  }
}

export function createStatePersistence({
  storageKey,
  storage = defaultStorage(),
  host = defaultHost(),
  documentTarget = defaultDocument(),
  idleTimeoutMs = DEFAULT_IDLE_TIMEOUT_MS,
  fallbackDelayMs = DEFAULT_FALLBACK_DELAY_MS,
} = {}) {
  let pendingState;
  let hasPendingState = false;
  let scheduledHandle = null;
  let scheduledMode = "";

  const cancelScheduledWrite = () => {
    if (scheduledHandle === null) return;
    if (scheduledMode === "idle") host?.cancelIdleCallback?.(scheduledHandle);
    if (scheduledMode === "timer") host?.clearTimeout?.(scheduledHandle);
    scheduledHandle = null;
    scheduledMode = "";
  };

  const flush = () => {
    cancelScheduledWrite();
    if (!hasPendingState) return true;

    const stateToWrite = pendingState;
    pendingState = undefined;
    hasPendingState = false;

    try {
      storage?.setItem?.(storageKey, JSON.stringify(stateToWrite));
      return Boolean(storage);
    } catch {
      return false;
    }
  };

  const schedule = (nextState, { immediate = false } = {}) => {
    pendingState = nextState;
    hasPendingState = true;
    if (immediate) return flush();
    if (scheduledHandle !== null) return true;

    if (typeof host?.requestIdleCallback === "function") {
      scheduledMode = "idle";
      scheduledHandle = host.requestIdleCallback(flush, { timeout: idleTimeoutMs });
    } else if (typeof host?.setTimeout === "function") {
      scheduledMode = "timer";
      scheduledHandle = host.setTimeout(flush, fallbackDelayMs);
    } else {
      return flush();
    }

    return true;
  };

  const attachLifecycle = () => {
    if (!host?.addEventListener || !documentTarget?.addEventListener) return () => flush();

    const handlePageHide = () => flush();
    const handleVisibilityChange = () => {
      if (documentTarget.visibilityState === "hidden") flush();
    };

    host.addEventListener("pagehide", handlePageHide);
    documentTarget.addEventListener("visibilitychange", handleVisibilityChange);

    return () => {
      host.removeEventListener("pagehide", handlePageHide);
      documentTarget.removeEventListener("visibilitychange", handleVisibilityChange);
      flush();
    };
  };

  return {
    attachLifecycle,
    flush,
    hasPending: () => hasPendingState,
    schedule,
  };
}

export function useEventCallback(callback) {
  const callbackRef = useRef(callback);
  callbackRef.current = callback;
  return useCallback((...args) => callbackRef.current?.(...args), []);
}

export function chartRevealKey(prefix, values = [], labels = []) {
  const valueKey = values.map((value) => (
    Number.isFinite(Number(value)) ? Number(value).toFixed(2) : "missing"
  )).join(",");
  return `${prefix}:${labels.join("|")}:${valueKey}`;
}

export function useChartReveal(key) {
  const normalizedKey = String(key ?? "chart");
  const [revealing, setRevealing] = useState(false);

  useEffect(() => {
    const reduceMotion = typeof window !== "undefined"
      && Boolean(window.matchMedia?.("(prefers-reduced-motion: reduce)").matches);
    if (reduceMotion || revealedChartKeys.has(normalizedKey)) {
      setRevealing(false);
      return undefined;
    }

    setRevealing(true);
    const markTimer = window.setTimeout(() => {
      revealedChartKeys.add(normalizedKey);
    }, 0);
    return () => window.clearTimeout(markTimer);
  }, [normalizedKey]);

  return revealing;
}
