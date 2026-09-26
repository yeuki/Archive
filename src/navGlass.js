// Bounded light tracking: CSS variables only, no React renders or idle loop.
export function createNavGlassLight(nav, host = window) {
  const neutral = { x: 50, y: 12 };
  let current = { ...neutral };
  let target = { ...neutral };
  let point = null;
  let frame = 0;
  let lastTime = 0;
  let startTime = null;
  let disposed = false;

  const paint = () => {
    nav.style.setProperty("--glass-light-x", `${current.x.toFixed(2)}%`);
    nav.style.setProperty("--glass-light-y", `${current.y.toFixed(2)}%`);
  };
  const reduced = () => host.matchMedia?.("(prefers-reduced-motion: reduce)").matches;
  const tick = (time) => {
    frame = 0;
    if (disposed) return;
    if (point) {
      const bounds = nav.querySelector(".nav-shell")?.getBoundingClientRect();
      if (bounds?.width && bounds.height) {
        target = {
          x: Math.max(0, Math.min(100, (point.x - bounds.left) / bounds.width * 100)),
          y: Math.max(0, Math.min(100, (point.y - bounds.top) / bounds.height * 100)),
        };
      }
      point = null;
    }
    startTime ??= time;
    const dt = lastTime ? Math.min(64, Math.max(1, time - lastTime)) : 16;
    lastTime = time;
    const blend = 1 - Math.exp(-dt / 65);
    current.x += (target.x - current.x) * blend;
    current.y += (target.y - current.y) * blend;
    const settled = Math.abs(target.x - current.x) + Math.abs(target.y - current.y) < 0.12;
    if (reduced() || settled || time - startTime >= 480) {
      current = { ...target };
      paint();
      lastTime = 0;
      startTime = null;
      return;
    }
    paint();
    frame = host.requestAnimationFrame(tick);
  };
  const schedule = () => {
    startTime = null;
    if (!point && Math.abs(current.x - target.x) + Math.abs(current.y - target.y) < 0.12) return;
    if (!frame) frame = host.requestAnimationFrame(tick);
  };
  return {
    move(event) {
      if (disposed || reduced()) return;
      // Touch movement only tracks an actual press; mouse hover can preview light.
      if (event.pointerType === "touch" && !nav.classList.contains("is-touching")) return;
      point = { x: event.clientX, y: event.clientY };
      schedule();
    },
    press(event) {
      if (disposed) return;
      nav.classList.add("is-touching");
      this.move(event);
    },
    settle() {
      if (disposed) return;
      nav.classList.remove("is-touching");
      point = null;
      target = { ...neutral };
      if (reduced()) {
        if (frame) host.cancelAnimationFrame(frame);
        frame = 0;
        current = { ...neutral };
        paint();
      } else schedule();
    },
    dispose() {
      disposed = true;
      if (frame) host.cancelAnimationFrame(frame);
      frame = 0;
      nav.classList.remove("is-touching");
      nav.style.removeProperty("--glass-light-x");
      nav.style.removeProperty("--glass-light-y");
    },
  };
}
