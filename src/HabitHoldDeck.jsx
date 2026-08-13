import { useEffect, useMemo, useRef, useState } from "react";
import { isDailyFieldRecorded } from "./dailyRecords.js";

const HOLD_DURATION_MS = 620;
const HOLD_CANCEL_DISTANCE = 14;
const SUCCESS_PAUSE_MS = 520;
const UNDO_NOTICE_MS = 5200;

function localDateLabel(date) {
  const parsed = new Date(`${date}T12:00:00`);
  if (!Number.isFinite(parsed.getTime())) return "Today";
  return parsed.toLocaleDateString(undefined, { weekday: "long", month: "long", day: "numeric" });
}

function HabitChooser({ habits, completionMap, selectedHabit, onSelect, onClose }) {
  const closeRef = useRef(null);

  useEffect(() => {
    closeRef.current?.focus();
    const handleKeyDown = (event) => {
      if (event.key === "Escape") onClose();
    };
    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [onClose]);

  return (
    <div className="sheet-backdrop habit-chooser-backdrop" role="presentation" onPointerDown={onClose}>
      <section
        className="choice-sheet habit-chooser-sheet metric-habit"
        role="dialog"
        aria-modal="true"
        aria-labelledby="habit-chooser-title"
        data-no-pull-refresh
        onPointerDown={(event) => event.stopPropagation()}
      >
        <span className="sheet-handle" aria-hidden="true" />
        <div className="choice-head">
          <div>
            <h2 id="habit-chooser-title">All habits</h2>
            <p>Choose any habit. Your configured order stays unchanged.</p>
          </div>
          <button ref={closeRef} className="ghost-btn" onClick={onClose}>Close</button>
        </div>

        <div className="habit-chooser-list">
          {habits.map((habit) => {
            const complete = Boolean(completionMap[habit]);
            return (
              <button
                className={`habit-chooser-row ${complete ? "complete" : "pending"} ${selectedHabit === habit ? "selected" : ""}`}
                key={habit}
                aria-pressed={selectedHabit === habit}
                onClick={() => onSelect(habit)}
              >
                <span>
                  <strong>{habit}</strong>
                  <small>{complete ? "Completed" : "Pending"}</small>
                </span>
                <i aria-hidden="true">{complete ? "✓" : "○"}</i>
              </button>
            );
          })}
        </div>
      </section>
    </div>
  );
}

export default function HabitHoldDeck({ date, habits = [], entry, onSetCompletion }) {
  const completionMap = entry?.habits ?? {};
  const completionMapRef = useRef(completionMap);
  completionMapRef.current = completionMap;
  const pendingHabits = useMemo(
    () => habits.filter((habit) => !completionMap[habit]),
    [completionMap, habits],
  );
  const completedCount = habits.length - pendingHabits.length;
  const [focusedHabit, setFocusedHabit] = useState(() => pendingHabits[0] ?? habits[0] ?? "");
  const [reviewingCompleted, setReviewingCompleted] = useState(false);
  const [chooserOpen, setChooserOpen] = useState(false);
  const [holding, setHolding] = useState(false);
  const [successHabit, setSuccessHabit] = useState("");
  const [notice, setNotice] = useState(null);
  const holdRef = useRef(null);
  const completionLockRef = useRef(false);
  const successTimerRef = useRef(0);
  const noticeTimerRef = useRef(0);
  const suppressPointerClickRef = useRef(false);

  useEffect(() => {
    if (!habits.length) {
      setFocusedHabit("");
      setReviewingCompleted(false);
      return;
    }

    if (!focusedHabit || !habits.includes(focusedHabit)) {
      setFocusedHabit(pendingHabits[0] ?? habits[0]);
      setReviewingCompleted(false);
      return;
    }

    if (
      !successHabit
      && !reviewingCompleted
      && completionMap[focusedHabit]
      && pendingHabits.length
    ) {
      setFocusedHabit(pendingHabits[0]);
    }
  }, [completionMap, focusedHabit, habits, pendingHabits, reviewingCompleted, successHabit]);

  useEffect(() => () => {
    window.clearTimeout(holdRef.current?.timer);
    window.clearTimeout(successTimerRef.current);
    window.clearTimeout(noticeTimerRef.current);
  }, []);

  const cancelHold = () => {
    if (holdRef.current?.timer) window.clearTimeout(holdRef.current.timer);
    holdRef.current = null;
    setHolding(false);
  };

  const scheduleNoticeClear = () => {
    window.clearTimeout(noticeTimerRef.current);
    noticeTimerRef.current = window.setTimeout(() => setNotice(null), UNDO_NOTICE_MS);
  };

  const completeFocusedHabit = () => {
    const habit = focusedHabit;
    if (!habit || completionMapRef.current[habit] || successHabit || completionLockRef.current) return;

    completionLockRef.current = true;
    cancelHold();
    setSuccessHabit(habit);
    setNotice({
      habit,
      restore: {
        habitsRecorded: isDailyFieldRecorded(entry, "habits"),
        habitPresent: Boolean(entry?.habits && Object.prototype.hasOwnProperty.call(entry.habits, habit)),
        habitValue: Boolean(entry?.habits?.[habit]),
      },
    });
    setReviewingCompleted(false);
    onSetCompletion?.(date, habit, true);
    if (typeof navigator !== "undefined" && typeof navigator.vibrate === "function") {
      navigator.vibrate(12);
    }
    scheduleNoticeClear();

    window.clearTimeout(successTimerRef.current);
    successTimerRef.current = window.setTimeout(() => {
      const nextHabit = habits.find((candidate) => (
        candidate !== habit && !completionMapRef.current[candidate]
      ));
      setSuccessHabit("");
      setFocusedHabit(nextHabit ?? habit);
      setReviewingCompleted(false);
      completionLockRef.current = false;
    }, SUCCESS_PAUSE_MS);
  };

  const startHold = (event) => {
    if (!focusedHabit || completionMap[focusedHabit] || successHabit || completionLockRef.current) return;
    if (event.pointerType === "mouse" && event.button !== 0) return;

    suppressPointerClickRef.current = false;
    event.currentTarget.setPointerCapture?.(event.pointerId);
    setHolding(true);
    holdRef.current = {
      pointerId: event.pointerId,
      startX: event.clientX,
      startY: event.clientY,
      timer: window.setTimeout(() => {
        suppressPointerClickRef.current = true;
        completeFocusedHabit();
      }, HOLD_DURATION_MS),
    };
  };

  const moveHold = (event) => {
    const hold = holdRef.current;
    if (!hold || hold.pointerId !== event.pointerId) return;
    const distance = Math.hypot(event.clientX - hold.startX, event.clientY - hold.startY);
    if (distance > HOLD_CANCEL_DISTANCE) cancelHold();
  };

  const finishHold = (event) => {
    if (event.currentTarget.hasPointerCapture?.(event.pointerId)) {
      event.currentTarget.releasePointerCapture(event.pointerId);
    }
    cancelHold();
  };

  const activateWithoutPointerHold = (event) => {
    if (suppressPointerClickRef.current) {
      suppressPointerClickRef.current = false;
      event.preventDefault();
      return;
    }

    // Keyboard and assistive technologies synthesize a click without a pointer
    // detail. Give them a conventional activation path rather than a timed hold.
    if (event.detail === 0) completeFocusedHabit();
  };

  const activateWithKeyboard = (event) => {
    if ((event.key === "Enter" || event.key === " ") && !event.repeat) {
      event.preventDefault();
      completeFocusedHabit();
    }
  };

  const selectHabit = (habit) => {
    cancelHold();
    setFocusedHabit(habit);
    setReviewingCompleted(Boolean(completionMap[habit]));
    setSuccessHabit("");
    completionLockRef.current = false;
    setChooserOpen(false);
  };

  const markIncomplete = (habit, restore = null) => {
    if (!habit) return;
    window.clearTimeout(successTimerRef.current);
    window.clearTimeout(noticeTimerRef.current);
    setSuccessHabit("");
    completionLockRef.current = false;
    setNotice(null);
    setFocusedHabit(habit);
    setReviewingCompleted(false);
    onSetCompletion?.(date, habit, false, restore);
  };

  const isAllComplete = Boolean(habits.length && pendingHabits.length === 0 && !successHabit);
  const focusedComplete = Boolean(completionMap[focusedHabit]);
  const focusedIndex = Math.max(0, habits.indexOf(focusedHabit));
  const nextPendingHabit = pendingHabits.find((habit) => habit !== focusedHabit) ?? "";
  const shownHabit = successHabit || focusedHabit;
  const shownComplete = Boolean(successHabit || focusedComplete);

  return (
    <section className="habit-focus-section" aria-labelledby="habit-focus-title" data-no-pull-refresh>
      <div className="habit-focus-header">
        <div>
          <span className="canvas-eyebrow">Today</span>
          <h2 id="habit-focus-title">Daily habits</h2>
          <p>{completedCount} of {habits.length} complete · {localDateLabel(date)}</p>
        </div>
        <button
          className="habit-all-button"
          onClick={() => setChooserOpen(true)}
          disabled={!habits.length}
          aria-haspopup="dialog"
        >
          <span>All habits</span>
          <i aria-hidden="true"><b /><b /><b /></i>
        </button>
      </div>

      {!habits.length ? (
        <div className="habit-focus-card habit-focus-empty">
          <span className="habit-focus-state-mark" aria-hidden="true">○</span>
          <h3>No habits are being tracked</h3>
          <p>Use Tracking preferences below when you are ready to add a habit to your daily flow.</p>
        </div>
      ) : isAllComplete ? (
        <div className="habit-focus-card habit-focus-all-complete" role="status">
          <span className="habit-focus-state-mark" aria-hidden="true">✓</span>
          <span className="canvas-eyebrow">Today</span>
          <h3>All habits complete</h3>
          <p>{habits.length} of {habits.length} recorded. Nothing else is required.</p>
          <button className="habit-review-button" onClick={() => setChooserOpen(true)}>Review habits</button>
        </div>
      ) : (
        <>
          <article className={`habit-focus-card ${successHabit ? "success" : ""} ${reviewingCompleted ? "reviewing" : ""}`}>
            <div className="habit-focus-card-meta">
              <span>{shownComplete ? "Completed" : "Current habit"}</span>
              <strong>{focusedIndex + 1} of {habits.length}</strong>
            </div>
            <h3>{shownHabit}</h3>

            <button
              className={`habit-hold-control ${holding ? "holding" : ""} ${shownComplete ? "complete" : ""}`}
              type="button"
              aria-label={shownComplete ? `${shownHabit} completed` : `Hold to complete ${shownHabit}`}
              aria-describedby="habit-hold-instructions"
              aria-pressed={shownComplete}
              disabled={shownComplete}
              style={{ "--habit-hold-duration": `${HOLD_DURATION_MS}ms` }}
              onPointerDown={startHold}
              onPointerMove={moveHold}
              onPointerUp={finishHold}
              onPointerCancel={finishHold}
              onLostPointerCapture={cancelHold}
              onClick={activateWithoutPointerHold}
              onKeyDown={activateWithKeyboard}
              onContextMenu={(event) => event.preventDefault()}
            >
              <svg viewBox="0 0 120 120" aria-hidden="true">
                <circle className="habit-hold-track" cx="60" cy="60" r="54" pathLength="1" />
                <circle className="habit-hold-progress" cx="60" cy="60" r="54" pathLength="1" />
              </svg>
              <span className="habit-hold-label" aria-hidden="true">
                {shownComplete ? <b className="habit-hold-check">✓</b> : holding ? "Keep holding" : <>Hold to<br />complete</>}
              </span>
            </button>
            <span id="habit-hold-instructions" className="sr-only">
              Touch and hold until the ring fills. Release or scroll to cancel. Keyboard and assistive activation completes immediately.
            </span>

            {reviewingCompleted && focusedComplete && (
              <button className="habit-mark-incomplete" onClick={() => markIncomplete(focusedHabit)}>
                Mark incomplete
              </button>
            )}
          </article>

          {!successHabit && nextPendingHabit && (
            <button className="habit-focus-peek" onClick={() => selectHabit(nextPendingHabit)}>
              <span><small>Up next</small><strong>{nextPendingHabit}</strong></span>
              <i aria-hidden="true">›</i>
            </button>
          )}
        </>
      )}

      {notice && (
        <div className="habit-completion-notice" role="status" aria-live="polite">
          <span><strong>{notice.habit}</strong> completed</span>
          <button onClick={() => markIncomplete(notice.habit, notice.restore)}>Undo</button>
        </div>
      )}

      {chooserOpen && (
        <HabitChooser
          habits={habits}
          completionMap={completionMap}
          selectedHabit={focusedHabit}
          onSelect={selectHabit}
          onClose={() => setChooserOpen(false)}
        />
      )}
    </section>
  );
}
