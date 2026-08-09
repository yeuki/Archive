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

  let transition;
  try {
    transition = document.startViewTransition(() => flushSync(update));
  } catch {
    if (root.dataset.archiveTransitionToken === token) {
      delete root.dataset.archiveTransition;
      delete root.dataset.archiveDirection;
      delete root.dataset.archiveTransitionToken;
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
