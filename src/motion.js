import { useLayoutEffect, useRef } from "react";
import { flushSync } from "react-dom";

const ARCHIVE_LAYOUT_DURATION = 460;
const ARCHIVE_LAYOUT_EASING = "cubic-bezier(0.16, 1, 0.3, 1)";

let activeViewTransition = null;
let transitionToken = 0;

export function archivePrefersReducedMotion() {
  return typeof window !== "undefined"
    && Boolean(window.matchMedia?.("(prefers-reduced-motion: reduce)").matches);
}

export function runArchiveTransition(update, { kind = "content", direction = "forward" } = {}) {
  if (typeof update !== "function") return null;
  if (
    typeof document === "undefined"
    || typeof document.startViewTransition !== "function"
    || archivePrefersReducedMotion()
  ) {
    update();
    return null;
  }

  activeViewTransition?.skipTransition?.();
  const root = document.documentElement;
  const token = String(++transitionToken);
  root.dataset.archiveTransition = kind;
  root.dataset.archiveDirection = direction;
  root.dataset.archiveTransitionToken = token;

  const clearTransitionChrome = () => {
    root.style.removeProperty("--archive-nav-snapshot-inset");
    root.style.removeProperty("--archive-nav-snapshot-end-inset");
    root.style.removeProperty("--archive-nav-snapshot-duration");
  };
  const captureTransitionChrome = () => {
    if (root.dataset.archiveTransitionToken !== token) return;
    clearTransitionChrome();
    if (kind !== "page") return;
    const nav = document.querySelector(".bottom-nav");
    const shell = nav?.querySelector(".nav-shell");
    if (!shell) return;
    // One geometry capture per transition, never a frame loop. The snapshot spans
    // the viewport width; its live backdrop must be clipped to the capsule.
    const bounds = nav.getBoundingClientRect();
    const vessel = shell.getBoundingClientRect();
    const insets = [vessel.top - bounds.top, bounds.right - vessel.right, bounds.bottom - vessel.bottom, vessel.left - bounds.left];
    const formatInsets = (values) => values.map((value) => `${Math.max(0, value).toFixed(2)}px`).join(" ");
    root.style.setProperty("--archive-nav-snapshot-inset", formatInsets(insets));
    // Mirror an in-flight true-width expansion/collapse in CSS, rather than
    // leaving a fixed blur footprint behind a shrinking vessel or reading it
    // every frame. Geometry tokens are the same ones used by the live dock.
    const style = getComputedStyle(nav);
    const compact = Boolean(nav.closest(".chrome-compact"));
    const expanded = nav.classList.contains("expanded");
    const width = compact ? 68 * 0.94 : Number.parseFloat(style.getPropertyValue(expanded ? "--dock-expanded-width" : "--dock-collapsed-width"));
    const shift = !compact && expanded ? Number.parseFloat(style.getPropertyValue("--dock-expanded-shift")) * (nav.classList.contains("health") ? 1 : -1) : 0;
    const verticalInset = compact ? bounds.height * 0.03 : 0;
    root.style.setProperty("--archive-nav-snapshot-end-inset", formatInsets([verticalInset, bounds.width / 2 - shift - width / 2, verticalInset, bounds.width / 2 + shift - width / 2]));
    const remaining = Math.max(0, ...shell.getAnimations().filter((animation) => ["width", "transform"].includes(animation.transitionProperty)).map((animation) => Number(animation.effect.getTiming().duration) - Number(animation.currentTime)));
    root.style.setProperty("--archive-nav-snapshot-duration", `${remaining.toFixed(2)}ms`);
  };

  let transition;
  try {
    transition = document.startViewTransition(() => {
      flushSync(update);
      captureTransitionChrome();
    });
  } catch {
    if (root.dataset.archiveTransitionToken === token) {
      delete root.dataset.archiveTransition;
      delete root.dataset.archiveDirection;
      delete root.dataset.archiveTransitionToken;
      clearTransitionChrome();
    }
    update();
    return null;
  }

  activeViewTransition = transition;
  transition.finished
    .catch(() => {})
    .finally(() => {
      if (activeViewTransition === transition) activeViewTransition = null;
      if (root.dataset.archiveTransitionToken === token) {
        delete root.dataset.archiveTransition;
        delete root.dataset.archiveDirection;
        delete root.dataset.archiveTransitionToken;
        clearTransitionChrome();
      }
    });

  return transition;
}

export function useFlipLayout(layoutKey, selector, dataKey) {
  const containerRef = useRef(null);
  const previousRectsRef = useRef(new Map());
  const animationsRef = useRef(new Map());

  useLayoutEffect(() => {
    const container = containerRef.current;
    if (!container) return undefined;

    const nodes = Array.from(container.querySelectorAll(selector));
    const nextRects = new Map();
    const reduceMotion = archivePrefersReducedMotion();

    nodes.forEach((node) => {
      const key = node.dataset[dataKey];
      if (!key) return;
      const nextRect = node.getBoundingClientRect();
      const previousRect = previousRectsRef.current.get(key);
      nextRects.set(key, nextRect);

      if (!previousRect || reduceMotion || typeof node.animate !== "function") return;
      const deltaX = previousRect.left - nextRect.left;
      const deltaY = previousRect.top - nextRect.top;
      if (Math.abs(deltaX) < 0.5 && Math.abs(deltaY) < 0.5) return;

      animationsRef.current.get(key)?.cancel?.();
      node.style.willChange = "translate";
      const animation = node.animate(
        [
          { translate: `${deltaX}px ${deltaY}px` },
          { translate: "0px 0px" },
        ],
        {
          duration: ARCHIVE_LAYOUT_DURATION,
          easing: ARCHIVE_LAYOUT_EASING,
          fill: "both",
        },
      );
      animationsRef.current.set(key, animation);
      animation.finished
        .catch(() => {})
        .finally(() => {
          if (animationsRef.current.get(key) !== animation) return;
          animationsRef.current.delete(key);
          node.style.removeProperty("will-change");
        });
    });

    previousRectsRef.current = nextRects;
    return undefined;
  }, [dataKey, layoutKey, selector]);

  useLayoutEffect(() => () => {
    animationsRef.current.forEach((animation) => animation.cancel?.());
    animationsRef.current.clear();
  }, []);

  return containerRef;
}
