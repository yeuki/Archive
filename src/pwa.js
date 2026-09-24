export function registerArchivePWA() {
  if (!import.meta.env.PROD || typeof window === "undefined" || !("serviceWorker" in navigator)) return;
  if (["localhost", "127.0.0.1"].includes(window.location.hostname)) return;

  window.addEventListener("load", () => {
    navigator.serviceWorker.register("./sw.js", { scope: "./" }).catch(() => {
      // Offline support is an enhancement. Archive remains usable if the host
      // or browser does not permit service-worker registration.
    });
  }, { once: true });
}
