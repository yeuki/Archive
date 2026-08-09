import { useEffect, useLayoutEffect, useMemo, useRef, useState } from "react";
import { createPortal } from "react-dom";
import { archivePrefersReducedMotion, runArchiveTransition } from "./motion.js";
import {
  addWorkoutSessionSet,
  adjustWorkoutSessionRest,
  completeWorkoutSessionSet,
  endWorkoutSessionEarly,
  finishWorkoutSessionRest,
  insertWorkoutWarmupSet,
  isBodyweightExercise,
  moveWorkoutSessionCursor,
  normalizeActiveWorkoutSession,
  patchWorkoutSessionExercise,
  patchWorkoutSessionSet,
  pauseWorkoutSession,
  resumeWorkoutSession,
  skipWorkoutSessionExercise,
  substituteWorkoutSessionExercise,
  toggleWorkoutRestTimer,
  workoutRestRemainingSeconds,
  workoutSessionCurrent,
  workoutSessionElapsedMs,
  workoutSessionStats,
} from "./workoutSession.js";

const WHEEL_ROW_HEIGHT = 52;
const WHEEL_RANGE = 48;
const EFFORT_OPTIONS = [
  { value: "easy", label: "Easy" },
  { value: "expected", label: "As expected" },
  { value: "hard", label: "Hard" },
  { value: "failed", label: "Failed" },
];

function numericValue(value, fallback = 0) {
  const parsed = Number(String(value ?? "").match(/\d+(?:\.\d+)?/)?.[0]);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function durationSeconds(value, fallback = 30) {
  const amount = numericValue(value, fallback);
  return /\b(?:min|mins|minute|minutes)\b/i.test(String(value ?? "")) ? amount * 60 : amount;
}

function formatNumber(value) {
  return Number.isInteger(value) ? String(value) : String(Number(value.toFixed(2)));
}

function formatTimer(totalSeconds) {
  const safeSeconds = Math.max(0, Math.round(totalSeconds));
  const minutes = Math.floor(safeSeconds / 60);
  const seconds = safeSeconds % 60;
  return `${minutes}:${String(seconds).padStart(2, "0")}`;
}

function formatElapsed(milliseconds) {
  const totalMinutes = Math.max(0, Math.floor(milliseconds / 60000));
  const hours = Math.floor(totalMinutes / 60);
  const minutes = totalMinutes % 60;
  return hours ? `${hours}h ${minutes}m` : `${minutes} min`;
}

function setStatusLabel(set) {
  if (set.status === "completed") return "Complete";
  if (set.status === "failed") return "Failed";
  if (set.status === "skipped") return "Skipped";
  return "Up next";
}

function setKindLabel(exercise, set, setIndex) {
  const sameKindBefore = exercise.sets.slice(0, setIndex).filter((item) => item.setType === set.setType).length;
  const sameKindTotal = exercise.sets.filter((item) => item.setType === set.setType).length;
  return set.setType === "warmup"
    ? `Warm-up ${sameKindBefore + 1} of ${sameKindTotal}`
    : `Set ${sameKindBefore + 1} of ${sameKindTotal}`;
}

function setValueLabel(exercise, set) {
  const value = exercise.metricKind === "duration" ? `${durationSeconds(set.reps)} sec` : `${set.reps} reps`;
  if (isBodyweightExercise(exercise, set)) return `Bodyweight · ${value}`;
  return `${formatNumber(Number(set.weight) || 0)} · ${value}`;
}

function workoutHaptic(duration = 9) {
  if (typeof navigator !== "undefined" && typeof navigator.vibrate === "function") {
    navigator.vibrate(duration);
  }
}

function WorkoutValueWheel({ label, value, min = 0, step = 1, unit, onChange }) {
  const scrollRef = useRef(null);
  const settleTimerRef = useRef(null);
  const paintFrameRef = useRef(0);
  const selected = Math.max(min, numericValue(value, min));
  const precision = String(step).includes(".") ? String(step).split(".")[1].length : 0;
  const alignedSelected = Number((Math.round(selected / step) * step).toFixed(precision));
  const [rangeAnchor, setRangeAnchor] = useState(alignedSelected);
  const options = useMemo(() => {
    const alignedAnchor = Number((Math.round(rangeAnchor / step) * step).toFixed(precision));
    const start = Math.max(min, alignedAnchor - WHEEL_RANGE * step);
    return Array.from({ length: WHEEL_RANGE * 2 + 1 }, (_, index) => (
      Number((start + index * step).toFixed(precision))
    ));
  }, [min, precision, rangeAnchor, step]);
  const selectedIndex = options.reduce((closest, option, index) => (
    Math.abs(option - selected) < Math.abs(options[closest] - selected) ? index : closest
  ), 0);

  const paintWheel = () => {
    const node = scrollRef.current;
    if (!node) return;
    const visualIndex = node.scrollTop / WHEEL_ROW_HEIGHT;
    Array.from(node.children).forEach((row, index) => {
      const offset = index - visualIndex;
      const distance = Math.min(3.25, Math.abs(offset));
      row.style.setProperty("--wheel-scale", `${1 - distance * 0.105}`);
      row.style.setProperty("--wheel-opacity", `${Math.max(0.2, 1 - distance * 0.25)}`);
      row.style.setProperty("--wheel-tilt", `${Math.max(-14, Math.min(14, offset * -5.5))}deg`);
      row.classList.toggle("wheel-current", Math.abs(offset) < 0.46);
    });
  };

  const scheduleWheelPaint = () => {
    if (paintFrameRef.current) return;
    paintFrameRef.current = window.requestAnimationFrame(() => {
      paintFrameRef.current = 0;
      paintWheel();
    });
  };

  useLayoutEffect(() => {
    const first = options[0];
    const last = options[options.length - 1];
    if (selected < first || selected > last) {
      setRangeAnchor(alignedSelected);
      return;
    }

    const node = scrollRef.current;
    if (!node) return;
    const targetTop = selectedIndex * WHEEL_ROW_HEIGHT;
    if (Math.abs(node.scrollTop - targetTop) > 1) node.scrollTop = targetTop;
    paintWheel();
  }, [alignedSelected, options, selected, selectedIndex]);

  useEffect(() => () => {
    window.clearTimeout(settleTimerRef.current);
    if (paintFrameRef.current) window.cancelAnimationFrame(paintFrameRef.current);
  }, []);

  const commitScrollValue = () => {
    const node = scrollRef.current;
    if (!node) return;
    const index = Math.max(0, Math.min(options.length - 1, Math.round(node.scrollTop / WHEEL_ROW_HEIGHT)));
    const nextValue = options[index];
    node.classList.remove("is-scrolling");
    if (nextValue !== selected) onChange(nextValue);
    if ((index < 7 && options[0] > min) || index > options.length - 8) setRangeAnchor(nextValue);
  };

  const nudge = (direction) => {
    const nextValue = Math.max(min, Number((selected + direction * step).toFixed(precision)));
    if (nextValue === selected) return;
    workoutHaptic(5);
    const nextIndex = options.findIndex((option) => option === nextValue);
    if (nextIndex < 0) {
      setRangeAnchor(nextValue);
      onChange(nextValue);
      return;
    }
    scrollRef.current?.scrollTo({
      top: nextIndex * WHEEL_ROW_HEIGHT,
      behavior: archivePrefersReducedMotion() ? "auto" : "smooth",
    });
  };

  const chooseOption = (option, index) => {
    if (option === selected) return;
    workoutHaptic(5);
    scrollRef.current?.scrollTo({
      top: index * WHEEL_ROW_HEIGHT,
      behavior: archivePrefersReducedMotion() ? "auto" : "smooth",
    });
  };

  return (
    <div className="workout-value-control">
      <div className="workout-value-label">
        <span>{label}</span>
        <small>{unit}</small>
      </div>
      <div className="workout-wheel-shell">
        <button type="button" className="workout-wheel-nudge" aria-label={`Decrease ${label}`} onClick={() => nudge(-1)}>−</button>
        <div className="workout-wheel-window">
          <div className="workout-wheel-focus" aria-hidden="true" />
          <div
            ref={scrollRef}
            className="workout-value-wheel"
            role="listbox"
            aria-label={label}
            tabIndex="0"
            onScroll={() => {
              scrollRef.current?.classList.add("is-scrolling");
              scheduleWheelPaint();
              window.clearTimeout(settleTimerRef.current);
              settleTimerRef.current = window.setTimeout(commitScrollValue, 130);
            }}
            onKeyDown={(event) => {
              if (event.key === "ArrowUp") {
                event.preventDefault();
                nudge(-1);
              }
              if (event.key === "ArrowDown") {
                event.preventDefault();
                nudge(1);
              }
            }}
          >
            {options.map((option, index) => (
              <button
                type="button"
                role="option"
                aria-selected={index === selectedIndex}
                className={index === selectedIndex ? "selected" : ""}
                onClick={() => chooseOption(option, index)}
                key={`${label}-${option}`}
              >
                {formatNumber(option)}
              </button>
            ))}
          </div>
        </div>
        <button type="button" className="workout-wheel-nudge" aria-label={`Increase ${label}`} onClick={() => nudge(1)}>+</button>
      </div>
    </div>
  );
}

function WorkoutModeHeader({ session, onLeave, onOutline, onOptions }) {
  const stats = workoutSessionStats(session);
  return (
    <header className="workout-mode-header">
      <button type="button" className="workout-mode-icon" onClick={onLeave} aria-label="Return to Archive">×</button>
      <button type="button" className="workout-mode-progress" onClick={onOutline} aria-label="Review workout progress">
        <span>
          <strong>{session.routineName}</strong>
          <small>{stats.resolved} of {stats.total} sets</small>
        </span>
        <i aria-hidden="true"><b style={{ width: `${stats.progress}%` }} /></i>
      </button>
      {onOptions
        ? <button type="button" className="workout-mode-icon" onClick={onOptions} aria-label="Workout options">•••</button>
        : <span className="workout-mode-header-spacer" aria-hidden="true" />}
    </header>
  );
}

function EffortControl({ value, onChange, expanded, onExpand }) {
  if (!expanded && !value) {
    return <button type="button" className="workout-effort-reveal" onClick={onExpand}>Add effort note</button>;
  }
  return (
    <div className="workout-effort-control" aria-label="Optional set effort">
      <span>Effort <small>optional</small></span>
      <div>
        {EFFORT_OPTIONS.map((option) => (
          <button
            type="button"
            className={value === option.value ? "active" : ""}
            aria-pressed={value === option.value}
            onClick={() => onChange(value === option.value ? "" : option.value)}
            key={option.value}
          >
            {option.label}
          </button>
        ))}
      </div>
    </div>
  );
}

function WorkoutSetScreen({ session, current, effortExpanded, onEffortExpand, onPatchSet, onComplete }) {
  const { exercise, set, cursor } = current;
  const bodyweight = isBodyweightExercise(exercise, set);
  const valueKind = exercise.metricKind === "duration" ? "Duration" : "Repetitions";
  const repValue = exercise.metricKind === "duration" ? durationSeconds(set.reps, 30) : numericValue(set.reps, 8);
  const previousLabel = set.previousReps
    ? `Last time: ${Number(set.previousWeight) > 0 ? `${formatNumber(Number(set.previousWeight))} × ` : ""}${set.previousReps}`
    : `Plan: ${Number(set.plannedWeight) > 0 ? `${formatNumber(Number(set.plannedWeight))} × ` : ""}${set.plannedReps}`;

  return (
    <section className="workout-mode-stage workout-set-stage" key={set.id}>
      <div className="workout-current-heading">
        <span>Exercise {cursor.exerciseIndex + 1} of {session.exercises.length}</span>
        <strong>{exercise.name}</strong>
        <div>
          <b>{setKindLabel(exercise, set, cursor.setIndex)}</b>
          {set.setType === "warmup" && <i>Warm-up</i>}
          {exercise.substitutedForName && <i>Replaces {exercise.substitutedForName}</i>}
        </div>
        <small>{previousLabel}</small>
      </div>

      <div className={`workout-picker-grid ${bodyweight ? "single-value" : ""}`}>
        {!bodyweight ? (
          <WorkoutValueWheel
            label="Weight"
            value={set.weight}
            min={0}
            step={2.5}
            unit="load"
            onChange={(weight) => onPatchSet({ weight })}
          />
        ) : (
          <div className="workout-bodyweight-value">
            <span>Load</span>
            <strong>Bodyweight</strong>
            <button type="button" onClick={() => onPatchSet({ weight: 2.5 })}>Add load</button>
          </div>
        )}
        <WorkoutValueWheel
          label={valueKind}
          value={repValue}
          min={exercise.metricKind === "duration" ? 5 : 1}
          step={exercise.metricKind === "duration" ? 5 : 1}
          unit={exercise.metricKind === "duration" ? "seconds" : "reps"}
          onChange={(value) => onPatchSet({ reps: exercise.metricKind === "duration" ? `${value}s` : String(value) })}
        />
      </div>

      <EffortControl
        value={set.effort}
        expanded={effortExpanded}
        onExpand={onEffortExpand}
        onChange={(effort) => onPatchSet({ effort })}
      />

      <div className="workout-mode-primary-wrap">
        <button type="button" className="workout-mode-primary" onClick={onComplete}>
          {set.effort === "failed" ? "Record failed set" : `Complete ${set.setType === "warmup" ? "warm-up" : "set"}`}
        </button>
        <small>Saved immediately · rest starts automatically</small>
      </div>
    </section>
  );
}

function WorkoutRestScreen({ session, remaining, onAdjust, onToggle, onSkip }) {
  const current = workoutSessionCurrent(session);
  const nextLabel = current ? setKindLabel(current.exercise, current.set, current.cursor.setIndex) : "Workout summary";
  const percent = session.rest?.durationSec
    ? Math.max(0, Math.min(100, (remaining / session.rest.durationSec) * 100))
    : 0;
  return (
    <section className="workout-mode-stage workout-rest-stage">
      <div className="workout-rest-eyebrow">Rest</div>
      <div className="workout-rest-clock" role="timer" aria-live="off">
        <strong>{formatTimer(remaining)}</strong>
        <span>{session.rest?.paused ? "Timer paused" : "Recover, then keep moving"}</span>
        <i aria-hidden="true"><b style={{ width: `${percent}%` }} /></i>
      </div>
      <div className="workout-rest-adjustments">
        <button type="button" onClick={() => onAdjust(-15)}>−15 sec</button>
        <button type="button" className="timer-toggle" onClick={onToggle}>
          <span aria-hidden="true">{session.rest?.paused ? "▶" : "Ⅱ"}</span>
          {session.rest?.paused ? "Resume timer" : "Pause timer"}
        </button>
        <button type="button" onClick={() => onAdjust(15)}>+15 sec</button>
      </div>
      <small className="workout-timer-note">This pauses only the rest timer. The workout remains active.</small>
      {current && (
        <div className="workout-next-preview">
          <span>Up next</span>
          <strong>{current.exercise.name}</strong>
          <small>{nextLabel} · {setValueLabel(current.exercise, current.set)}</small>
        </div>
      )}
      <button type="button" className="workout-mode-secondary wide" onClick={onSkip}>Skip rest</button>
    </section>
  );
}

function WorkoutPausedScreen({ session, onResume, onLeave, onEnd }) {
  return (
    <section className="workout-mode-stage workout-paused-stage">
      <div className="workout-paused-mark" aria-hidden="true">Ⅱ</div>
      <span>Workout paused</span>
      <strong>{session.routineName}</strong>
      <p>Your place, entered values, and remaining rest time are saved.</p>
      <button type="button" className="workout-mode-primary" onClick={onResume}>Resume workout</button>
      <button type="button" className="workout-mode-secondary wide" onClick={onLeave}>Return to Archive</button>
      <button type="button" className="workout-mode-text-action" onClick={onEnd}>End workout early</button>
    </section>
  );
}

function WorkoutSummaryScreen({ session, clock, onNotes, onReview, onFinish, onDiscard }) {
  const stats = workoutSessionStats(session);
  return (
    <section className="workout-mode-stage workout-summary-stage">
      <div className="workout-summary-mark" aria-hidden="true">✓</div>
      <span>Session review</span>
      <h2>{session.routineName}</h2>
      <p>{stats.pending ? `${stats.pending} planned set${stats.pending === 1 ? "" : "s"} left incomplete.` : "Every planned set has been reviewed."}</p>
      <div className="workout-summary-metrics">
        <div><strong>{formatElapsed(workoutSessionElapsedMs(session, clock))}</strong><span>Duration</span></div>
        <div><strong>{stats.workingSets}</strong><span>Working sets</span></div>
        <div><strong>{Math.round(stats.volume).toLocaleString()}</strong><span>Volume</span></div>
      </div>
      {(stats.warmups > 0 || stats.failed > 0 || stats.skipped > 0) && (
        <div className="workout-summary-details">
          {stats.warmups > 0 && <span>{stats.warmups} warm-up{stats.warmups === 1 ? "" : "s"}</span>}
          {stats.failed > 0 && <span>{stats.failed} failed</span>}
          {stats.skipped > 0 && <span>{stats.skipped} skipped</span>}
        </div>
      )}
      <label className="workout-summary-notes">
        <span>Workout note <small>optional</small></span>
        <textarea value={session.notes} onChange={(event) => onNotes(event.target.value)} placeholder="Anything worth remembering?" />
      </label>
      <button type="button" className="workout-mode-secondary wide" onClick={onReview}>Review sets</button>
      <button type="button" className="workout-mode-primary" onClick={onFinish}>Finish workout</button>
      <button type="button" className="workout-mode-text-action danger" onClick={onDiscard}>Discard session</button>
    </section>
  );
}

function WorkoutSheet({ title, subtitle, onClose, children, className = "" }) {
  return (
    <div className="workout-mode-scrim" role="presentation" onPointerDown={(event) => event.target === event.currentTarget && onClose()}>
      <section className={`workout-mode-sheet ${className}`} role="dialog" aria-modal="true" aria-label={title} data-no-pull-refresh>
        <div className="workout-mode-sheet-handle" aria-hidden="true" />
        <div className="workout-mode-sheet-head">
          <div><h2>{title}</h2>{subtitle && <p>{subtitle}</p>}</div>
          <button type="button" onClick={onClose} aria-label={`Close ${title}`}>×</button>
        </div>
        {children}
      </section>
    </div>
  );
}

function WorkoutOptionsSheet({ session, onClose, onWarmup, onNotes, onSubstitute, onSkipSet, onFailSet, onSkipExercise, onExit }) {
  const current = workoutSessionCurrent(session);
  if (!current) return null;
  return (
    <WorkoutSheet title="Set options" subtitle={current.exercise.name} onClose={onClose} className="workout-action-sheet">
      <div className="workout-sheet-actions">
        <button type="button" onClick={onWarmup}><span>Add warm-up set</span><small>Insert before the current set</small></button>
        <button type="button" onClick={onNotes}><span>Exercise note</span><small>Optional context for this movement</small></button>
        <button type="button" onClick={onSubstitute}><span>Substitute exercise</span><small>Change this session only</small></button>
        <button type="button" onClick={onFailSet}><span>Record failed set</span><small>Keep the actual values entered</small></button>
        <button type="button" onClick={onSkipSet}><span>Skip this set</span><small>Continue without starting rest</small></button>
        <button type="button" onClick={onSkipExercise}><span>Skip remaining exercise</span><small>Move to the next exercise</small></button>
        <button type="button" className="separated" onClick={onExit}><span>Pause or end workout</span><small>Leave safely without losing progress</small></button>
      </div>
    </WorkoutSheet>
  );
}

function WorkoutExitSheet({ onClose, onLeave, onPause, onEnd, onDiscard }) {
  return (
    <WorkoutSheet title="Leave Workout Mode?" subtitle="Choose what should happen to this session." onClose={onClose} className="workout-exit-sheet">
      <div className="workout-sheet-actions">
        <button type="button" onClick={onLeave}><span>Return to Archive</span><small>Keep the workout active; a running rest timer continues</small></button>
        <button type="button" onClick={onPause}><span>Pause workout</span><small>Freeze workout time and the rest timer</small></button>
        <button type="button" onClick={onEnd}><span>End workout early</span><small>Review completed, failed, and skipped sets</small></button>
        <button type="button" className="danger separated" onClick={onDiscard}><span>Discard workout</span><small>Permanently remove this active session</small></button>
      </div>
    </WorkoutSheet>
  );
}

function WorkoutDiscardSheet({ onClose, onDiscard }) {
  return (
    <WorkoutSheet title="Discard this workout?" subtitle="Completed sets and notes from this active session will be removed." onClose={onClose} className="workout-confirm-sheet">
      <div className="workout-confirm-actions">
        <button type="button" className="workout-mode-secondary wide" onClick={onClose}>Keep workout</button>
        <button type="button" className="workout-danger-button" onClick={onDiscard}>Discard permanently</button>
      </div>
    </WorkoutSheet>
  );
}

function WorkoutNotesSheet({ exercise, onChange, onClose }) {
  const [notes, setNotes] = useState(exercise.notes);
  return (
    <WorkoutSheet title="Exercise note" subtitle={exercise.name} onClose={onClose} className="workout-notes-sheet">
      <label>
        <span>Optional note</span>
        <textarea value={notes} onChange={(event) => setNotes(event.target.value)} placeholder="Setup, form cue, or anything unusual" autoFocus />
      </label>
      <button type="button" className="workout-mode-primary" onClick={() => { onChange(notes); onClose(); }}>Save note</button>
    </WorkoutSheet>
  );
}

function WorkoutSubstituteSheet({ currentExercise, exercises, onChoose, onClose }) {
  const [query, setQuery] = useState("");
  const matches = exercises.filter((exercise) => (
    exercise.id !== currentExercise.exerciseId
    && `${exercise.name} ${exercise.equipment} ${exercise.movement}`.toLowerCase().includes(query.trim().toLowerCase())
  ));
  return (
    <WorkoutSheet title="Substitute exercise" subtitle={`Replace ${currentExercise.name} for this session only.`} onClose={onClose} className="workout-substitute-sheet">
      <input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search exercises" aria-label="Search exercises" autoFocus />
      <div className="workout-substitute-list">
        {matches.map((exercise) => (
          <button type="button" onClick={() => onChoose(exercise)} key={exercise.id}>
            <span>{exercise.name}</span>
            <small>{exercise.equipment}{exercise.primaryMuscles?.length ? ` · ${exercise.primaryMuscles.join(", ")}` : ""}</small>
          </button>
        ))}
        {!matches.length && <p>No exercises match this search.</p>}
      </div>
    </WorkoutSheet>
  );
}

function WorkoutOutlineSheet({ session, onClose, onGoToSet, onEditSet, onAddSet }) {
  return (
    <WorkoutSheet title="Workout outline" subtitle="Review progress or correct a completed set." onClose={onClose} className="workout-outline-sheet">
      <div className="workout-outline-list">
        {session.exercises.map((exercise, exerciseIndex) => {
          const resolved = exercise.sets.filter((set) => set.status !== "pending").length;
          return (
            <article key={`${exercise.exerciseId}-${exerciseIndex}`}>
              <div className="workout-outline-exercise-head">
                <div>
                  <strong>{exercise.name}</strong>
                  <small>{resolved} of {exercise.sets.length} reviewed</small>
                </div>
                <button type="button" onClick={() => onAddSet(exerciseIndex)}>+ Set</button>
              </div>
              <div className="workout-outline-sets">
                {exercise.sets.map((set, setIndex) => {
                  const active = session.cursor.exerciseIndex === exerciseIndex && session.cursor.setIndex === setIndex && session.status !== "summary";
                  return (
                    <button
                      type="button"
                      className={`${set.status} ${active ? "active" : ""}`}
                      onClick={() => set.status === "pending"
                        ? onGoToSet({ exerciseIndex, setIndex })
                        : onEditSet({ exerciseIndex, setIndex })}
                      key={set.id}
                    >
                      <i aria-hidden="true" />
                      <span>{setKindLabel(exercise, set, setIndex)}</span>
                      <small>{setValueLabel(exercise, set)} · {setStatusLabel(set)}</small>
                    </button>
                  );
                })}
              </div>
            </article>
          );
        })}
        {!session.exercises.length && <p className="workout-outline-empty">This routine has no exercises. You can still finish and save the session duration.</p>}
      </div>
    </WorkoutSheet>
  );
}

function WorkoutEditSetSheet({ session, cursor, onPatch, onClose }) {
  const exercise = session.exercises[cursor.exerciseIndex];
  const set = exercise?.sets[cursor.setIndex];
  if (!exercise || !set) return null;
  const bodyweight = isBodyweightExercise(exercise, set);
  return (
    <WorkoutSheet title="Edit set" subtitle={`${exercise.name} · ${setKindLabel(exercise, set, cursor.setIndex)}`} onClose={onClose} className="workout-edit-set-sheet">
      <div className={`workout-picker-grid compact ${bodyweight ? "single-value" : ""}`}>
        {!bodyweight && (
          <WorkoutValueWheel label="Weight" value={set.weight} min={0} step={2.5} unit="load" onChange={(weight) => onPatch({ weight })} />
        )}
        <WorkoutValueWheel
          label={exercise.metricKind === "duration" ? "Duration" : "Repetitions"}
          value={exercise.metricKind === "duration" ? durationSeconds(set.reps, 30) : numericValue(set.reps, 1)}
          min={exercise.metricKind === "duration" ? 5 : 1}
          step={exercise.metricKind === "duration" ? 5 : 1}
          unit={exercise.metricKind === "duration" ? "seconds" : "reps"}
          onChange={(value) => onPatch({ reps: exercise.metricKind === "duration" ? `${value}s` : String(value) })}
        />
      </div>
      <div className="workout-edit-status">
        <span>Set status</span>
        <div>
          {["completed", "failed", "skipped"].map((status) => (
            <button type="button" className={set.status === status ? "active" : ""} onClick={() => onPatch({
              status,
              effort: status === "failed" ? "failed" : set.effort === "failed" ? "" : set.effort,
            })} key={status}>
              {status[0].toUpperCase() + status.slice(1)}
            </button>
          ))}
        </div>
      </div>
      <EffortControl value={set.effort} expanded onExpand={() => {}} onChange={(effort) => onPatch({ effort })} />
      <button type="button" className="workout-mode-primary" onClick={onClose}>Done</button>
    </WorkoutSheet>
  );
}

export default function WorkoutMode({ session, exercises, onChange, onLeave, onFinish, onDiscard }) {
  const data = normalizeActiveWorkoutSession(session);
  const [clock, setClock] = useState(Date.now());
  const [panel, setPanel] = useState(null);
  const [editCursor, setEditCursor] = useState(null);
  const [effortExpanded, setEffortExpanded] = useState(false);
  const modeRef = useRef(null);
  const current = workoutSessionCurrent(data);
  const remaining = workoutRestRemainingSeconds(data, clock);

  useEffect(() => {
    const appShell = document.querySelector(".app-shell");
    const previousAriaHidden = appShell?.getAttribute("aria-hidden");
    const previousInert = appShell?.inert ?? false;
    document.body.classList.add("workout-mode-active");
    appShell?.setAttribute("aria-hidden", "true");
    if (appShell) appShell.inert = true;
    window.requestAnimationFrame(() => modeRef.current?.querySelector("button")?.focus({ preventScroll: true }));
    return () => {
      document.body.classList.remove("workout-mode-active");
      if (appShell) {
        appShell.inert = previousInert;
        if (previousAriaHidden == null) appShell.removeAttribute("aria-hidden");
        else appShell.setAttribute("aria-hidden", previousAriaHidden);
      }
    };
  }, []);

  useEffect(() => {
    setPanel(null);
    setEditCursor(null);
    setEffortExpanded(false);
  }, [data?.id]);

  useEffect(() => {
    const timer = window.setInterval(() => setClock(Date.now()), 500);
    return () => window.clearInterval(timer);
  }, []);

  useEffect(() => {
    if (data?.status !== "resting" || data.rest?.paused || remaining > 0) return;
    onChange((currentSession) => {
      const normalized = normalizeActiveWorkoutSession(currentSession);
      if (normalized?.status !== "resting" || normalized.rest?.paused || workoutRestRemainingSeconds(normalized) > 0) return normalized;
      workoutHaptic(18);
      return finishWorkoutSessionRest(normalized);
    });
  }, [data?.rest?.paused, data?.status, onChange, remaining]);

  if (!data) return null;

  const updateSession = (updater) => onChange((currentSession) => {
    const normalized = normalizeActiveWorkoutSession(currentSession);
    return typeof updater === "function" ? updater(normalized) : updater;
  });
  const changePanel = (nextPanel, direction = nextPanel ? "open" : "close") => {
    runArchiveTransition(() => setPanel(nextPanel), { kind: "workout-sheet", direction });
  };
  const transitionSession = (updater, direction = "forward") => {
    runArchiveTransition(() => updateSession(updater), { kind: "workout-stage", direction });
  };
  const leaveWorkoutMode = () => {
    runArchiveTransition(onLeave, { kind: "workout-mode", direction: "close" });
  };
  const patchCurrentSet = (patch) => {
    const cursor = data.cursor;
    updateSession((currentSession) => patchWorkoutSessionSet(currentSession, cursor, patch));
  };
  const completeCurrentSet = (status = "completed") => {
    const outcomeStatus = status === "completed" && current?.set.effort === "failed" ? "failed" : status;
    workoutHaptic(outcomeStatus === "failed" ? 22 : 11);
    runArchiveTransition(() => {
      updateSession((currentSession) => completeWorkoutSessionSet(currentSession, { status: outcomeStatus }));
      setPanel(null);
      setEffortExpanded(false);
    }, { kind: "workout-stage", direction: "forward" });
  };
  const updateNotes = (notes) => updateSession((currentSession) => ({
    ...currentSession,
    notes,
    lastSavedAt: new Date().toISOString(),
  }));
  const openExit = () => changePanel("exit");

  return createPortal(
    <div
      ref={modeRef}
      className={`workout-mode-screen phase-${data.status}`}
      role="dialog"
      aria-modal="true"
      aria-label="Workout Mode"
      data-no-pull-refresh
    >
      <div className="workout-mode-ambient" aria-hidden="true" />
      <WorkoutModeHeader
        session={data}
        onLeave={leaveWorkoutMode}
        onOutline={() => changePanel("outline")}
        onOptions={data.status === "active"
          ? () => changePanel("options")
          : data.status === "resting" ? openExit : null}
      />

      <div className="workout-mode-content" aria-live="polite">
        {data.status === "active" && current && (
          <WorkoutSetScreen
            session={data}
            current={current}
            effortExpanded={effortExpanded}
            onEffortExpand={() => setEffortExpanded(true)}
            onPatchSet={patchCurrentSet}
            onComplete={() => completeCurrentSet("completed")}
          />
        )}
        {data.status === "resting" && (
          <WorkoutRestScreen
            session={data}
            remaining={remaining}
            onAdjust={(seconds) => updateSession((currentSession) => adjustWorkoutSessionRest(currentSession, seconds))}
            onToggle={() => updateSession((currentSession) => toggleWorkoutRestTimer(currentSession))}
            onSkip={() => transitionSession((currentSession) => finishWorkoutSessionRest(currentSession))}
          />
        )}
        {data.status === "paused" && (
          <WorkoutPausedScreen
            session={data}
            onResume={() => transitionSession((currentSession) => resumeWorkoutSession(currentSession))}
            onLeave={leaveWorkoutMode}
            onEnd={() => transitionSession((currentSession) => endWorkoutSessionEarly(currentSession))}
          />
        )}
        {data.status === "summary" && (
          <WorkoutSummaryScreen
            session={data}
            clock={clock}
            onNotes={updateNotes}
            onReview={() => changePanel("outline")}
            onFinish={() => runArchiveTransition(() => onFinish(data), { kind: "workout-mode", direction: "close" })}
            onDiscard={() => changePanel("discard")}
          />
        )}
      </div>

      {panel === "options" && (
        <WorkoutOptionsSheet
          session={data}
          onClose={() => changePanel(null)}
          onWarmup={() => runArchiveTransition(() => {
            updateSession((currentSession) => insertWorkoutWarmupSet(currentSession));
            setPanel(null);
          }, { kind: "workout-stage", direction: "forward" })}
          onNotes={() => changePanel("notes", "forward")}
          onSubstitute={() => changePanel("substitute", "forward")}
          onSkipSet={() => completeCurrentSet("skipped")}
          onFailSet={() => completeCurrentSet("failed")}
          onSkipExercise={() => runArchiveTransition(() => {
            updateSession((currentSession) => skipWorkoutSessionExercise(currentSession));
            setPanel(null);
          }, { kind: "workout-stage", direction: "forward" })}
          onExit={openExit}
        />
      )}
      {panel === "exit" && (
        <WorkoutExitSheet
          onClose={() => changePanel(null)}
          onLeave={leaveWorkoutMode}
          onPause={() => runArchiveTransition(() => {
            updateSession((currentSession) => pauseWorkoutSession(currentSession));
            onLeave();
          }, { kind: "workout-mode", direction: "close" })}
          onEnd={() => runArchiveTransition(() => {
            updateSession((currentSession) => endWorkoutSessionEarly(currentSession));
            setPanel(null);
          }, { kind: "workout-stage", direction: "forward" })}
          onDiscard={() => changePanel("discard", "forward")}
        />
      )}
      {panel === "discard" && (
        <WorkoutDiscardSheet
          onClose={() => changePanel(null)}
          onDiscard={() => runArchiveTransition(onDiscard, { kind: "workout-mode", direction: "close" })}
        />
      )}
      {panel === "notes" && current && (
        <WorkoutNotesSheet
          exercise={current.exercise}
          onClose={() => changePanel(null)}
          onChange={(notes) => updateSession((currentSession) => patchWorkoutSessionExercise(currentSession, current.cursor.exerciseIndex, { notes }))}
        />
      )}
      {panel === "substitute" && current && (
        <WorkoutSubstituteSheet
          currentExercise={current.exercise}
          exercises={exercises}
          onClose={() => changePanel(null)}
          onChoose={(replacement) => {
            runArchiveTransition(() => {
              updateSession((currentSession) => substituteWorkoutSessionExercise(currentSession, current.cursor.exerciseIndex, replacement));
              setPanel(null);
            }, { kind: "workout-stage", direction: "forward" });
          }}
        />
      )}
      {panel === "outline" && (
        <WorkoutOutlineSheet
          session={data}
          onClose={() => changePanel(null)}
          onGoToSet={(cursor) => runArchiveTransition(() => {
            updateSession((currentSession) => moveWorkoutSessionCursor(currentSession, cursor));
            setPanel(null);
          }, { kind: "workout-stage", direction: "backward" })}
          onEditSet={(cursor) => runArchiveTransition(() => {
            setEditCursor(cursor);
            setPanel("edit");
          }, { kind: "workout-sheet", direction: "forward" })}
          onAddSet={(exerciseIndex) => updateSession((currentSession) => addWorkoutSessionSet(currentSession, exerciseIndex))}
        />
      )}
      {panel === "edit" && editCursor && (
        <WorkoutEditSetSheet
          session={data}
          cursor={editCursor}
          onClose={() => runArchiveTransition(() => {
            setEditCursor(null);
            setPanel("outline");
          }, { kind: "workout-sheet", direction: "backward" })}
          onPatch={(patch) => updateSession((currentSession) => patchWorkoutSessionSet(currentSession, editCursor, patch))}
        />
      )}
    </div>,
    document.body,
  );
}
