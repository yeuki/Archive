export const WORKOUT_SESSION_SCHEMA_VERSION = 1;

const SESSION_STATUSES = new Set(["active", "resting", "paused", "summary"]);
const SET_STATUSES = new Set(["pending", "completed", "failed", "skipped"]);
const SET_TYPES = new Set(["working", "warmup"]);
const EFFORT_VALUES = new Set(["", "easy", "expected", "hard", "failed"]);

function finiteNumber(value, fallback = 0) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function nonNegativeNumber(value, fallback = 0) {
  return Math.max(0, finiteNumber(value, fallback));
}

function timestamp(value = Date.now()) {
  const parsed = value instanceof Date ? value : new Date(value);
  return Number.isNaN(parsed.getTime()) ? new Date().toISOString() : parsed.toISOString();
}

function timestampMs(value) {
  const parsed = Date.parse(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

function localDateKey(value = Date.now()) {
  const parsed = value instanceof Date ? value : new Date(value);
  const safeDate = Number.isNaN(parsed.getTime()) ? new Date() : parsed;
  const year = safeDate.getFullYear();
  const month = String(safeDate.getMonth() + 1).padStart(2, "0");
  const day = String(safeDate.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function lookupKey(value) {
  return String(value ?? "")
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

function exerciseMatches(loggedExercise = {}, targetExercise = {}) {
  const loggedKeys = [loggedExercise.exerciseId, loggedExercise.name].map(lookupKey).filter(Boolean);
  return [targetExercise.id, targetExercise.exerciseId, targetExercise.name]
    .map(lookupKey)
    .filter(Boolean)
    .some((key) => loggedKeys.includes(key));
}

function previousSetsForExercise(workouts = [], targetExercise = {}) {
  const latestWorkout = workouts
    .map((workout, index) => ({ workout, index }))
    .sort((a, b) => (
      String(b.workout?.date ?? "").localeCompare(String(a.workout?.date ?? ""))
      || b.index - a.index
    ))
    .find(({ workout }) => workout?.exercises?.some((exercise) => (
      exerciseMatches(exercise, targetExercise) && exercise.sets?.some(isWorkoutSetCounted)
    )))
    ?.workout;

  return latestWorkout?.exercises
    ?.find((exercise) => exerciseMatches(exercise, targetExercise))
    ?.sets
    ?.filter(isWorkoutSetCounted) ?? [];
}

function parseRepValue(value) {
  const match = String(value ?? "").match(/\d+(?:\.\d+)?/);
  if (!match) return 0;
  const amount = Number(match[0]);
  return /\b(?:min|mins|minute|minutes)\b/i.test(String(value ?? "")) ? amount * 60 : amount;
}

function setStatus(set = {}) {
  if (SET_STATUSES.has(set.status)) return set.status;
  if (set.done === true) return "completed";
  if (set.done === false) return "skipped";
  return "pending";
}

function normalizeSessionSet(set = {}, fallback = {}, id = "set") {
  const reps = String(set.reps ?? fallback.reps ?? "8").trim() || "8";
  const weight = nonNegativeNumber(set.weight, nonNegativeNumber(fallback.weight, 0));
  const status = setStatus(set);
  return {
    id: String(set.id ?? id),
    plannedWeight: nonNegativeNumber(set.plannedWeight, nonNegativeNumber(fallback.plannedWeight, weight)),
    plannedReps: String(set.plannedReps ?? fallback.plannedReps ?? reps).trim() || reps,
    previousWeight: set.previousWeight !== "" && set.previousWeight != null && Number.isFinite(Number(set.previousWeight))
      ? nonNegativeNumber(set.previousWeight, 0)
      : "",
    previousReps: String(set.previousReps ?? "").trim(),
    weight,
    reps,
    rpe: String(set.rpe ?? "").trim() && Number.isFinite(Number(set.rpe)) ? Number(set.rpe) : "",
    effort: EFFORT_VALUES.has(set.effort) ? set.effort : "",
    setType: SET_TYPES.has(set.setType) ? set.setType : "working",
    blockId: String(set.blockId ?? ""),
    round: set.round == null || set.round === "" ? "" : Math.max(1, Math.round(finiteNumber(set.round, 1))),
    status,
    completedAt: status === "pending" ? "" : String(set.completedAt ?? ""),
  };
}

function normalizeCursor(exercises, cursor = {}) {
  if (!exercises.length) return { exerciseIndex: 0, setIndex: 0 };
  const exerciseIndex = Math.min(
    exercises.length - 1,
    Math.max(0, Math.round(finiteNumber(cursor.exerciseIndex, 0))),
  );
  const sets = exercises[exerciseIndex].sets;
  return {
    exerciseIndex,
    setIndex: sets.length
      ? Math.min(sets.length - 1, Math.max(0, Math.round(finiteNumber(cursor.setIndex, 0))))
      : 0,
  };
}

function sessionSetAt(session, cursor = session?.cursor) {
  return session?.exercises?.[cursor?.exerciseIndex]?.sets?.[cursor?.setIndex] ?? null;
}

function flattenSessionSets(session) {
  return (session?.exercises ?? []).flatMap((exercise, exerciseIndex) => (
    (exercise.sets ?? []).map((set, setIndex) => ({ exercise, set, exerciseIndex, setIndex }))
  ));
}

function firstPendingCursor(session) {
  const item = flattenSessionSets(session).find(({ set }) => set.status === "pending");
  return item ? { exerciseIndex: item.exerciseIndex, setIndex: item.setIndex } : null;
}

function nextPendingCursor(session, cursor = session?.cursor) {
  const flat = flattenSessionSets(session);
  const currentIndex = flat.findIndex(({ exerciseIndex, setIndex }) => (
    exerciseIndex === cursor?.exerciseIndex && setIndex === cursor?.setIndex
  ));
  const item = flat.slice(Math.max(0, currentIndex + 1)).find(({ set }) => set.status === "pending");
  return item ? { exerciseIndex: item.exerciseIndex, setIndex: item.setIndex } : null;
}

function withSavedAt(session, now = Date.now()) {
  return { ...session, lastSavedAt: timestamp(now) };
}

export function inferWorkoutMetricKind(reps, exercise = {}) {
  const repText = String(reps ?? "").trim().toLowerCase();
  if (/^\d+(?:\.\d+)?\s*(?:s|sec|secs|second|seconds|min|mins|minute|minutes)$/.test(repText)) {
    return "duration";
  }
  return "reps";
}

export function isBodyweightExercise(exercise = {}, set = {}) {
  if (nonNegativeNumber(set.weight, 0) > 0) return false;
  const descriptor = `${exercise.equipment ?? ""} ${exercise.name ?? ""}`.toLowerCase();
  return /body\s*weight|bodyweight|push-up|push up|plank/.test(descriptor);
}

export function isWorkoutSetCounted(set = {}) {
  const status = setStatus(set);
  return status !== "pending"
    && status !== "skipped"
    && (SET_TYPES.has(set.setType) ? set.setType : "working") !== "warmup"
    && set.done !== false;
}

export function normalizeActiveWorkoutSession(session) {
  if (!session || typeof session !== "object" || !session.id) return null;
  const startedAt = timestamp(session.startedAt ?? session.createdAt ?? Date.now());
  const exercises = (Array.isArray(session.exercises) ? session.exercises : []).map((exercise, exerciseIndex) => {
    const fallbackSets = Array.isArray(exercise.sets) ? exercise.sets : [];
    const sets = fallbackSets.map((set, setIndex) => normalizeSessionSet(
      set,
      {},
      `${session.id}-exercise-${exerciseIndex + 1}-set-${setIndex + 1}`,
    ));
    const referenceSet = sets[0] ?? {};
    return {
      exerciseId: String(exercise.exerciseId ?? `session-exercise-${exerciseIndex + 1}`),
      name: String(exercise.name ?? `Exercise ${exerciseIndex + 1}`).trim() || `Exercise ${exerciseIndex + 1}`,
      equipment: String(exercise.equipment ?? ""),
      movement: String(exercise.movement ?? ""),
      primaryMuscles: Array.isArray(exercise.primaryMuscles) ? exercise.primaryMuscles.map(String) : [],
      secondaryMuscles: Array.isArray(exercise.secondaryMuscles) ? exercise.secondaryMuscles.map(String) : [],
      substitutedForExerciseId: String(exercise.substitutedForExerciseId ?? ""),
      substitutedForName: String(exercise.substitutedForName ?? ""),
      metricKind: exercise.metricKind === "duration"
        ? "duration"
        : inferWorkoutMetricKind(referenceSet.reps, exercise),
      restSec: Math.round(nonNegativeNumber(exercise.restSec, 90)),
      notes: String(exercise.notes ?? ""),
      sets,
    };
  });
  const cursor = normalizeCursor(exercises, session.cursor);
  const requestedStatus = SESSION_STATUSES.has(session.status) ? session.status : "active";
  const hasSets = exercises.some((exercise) => exercise.sets.length);
  const pendingCursor = firstPendingCursor({ exercises });
  const status = !hasSets || (!pendingCursor && requestedStatus !== "paused") ? "summary" : requestedStatus;
  const restDuration = Math.round(nonNegativeNumber(session.rest?.durationSec, 0));
  const restRemaining = Math.round(nonNegativeNumber(session.rest?.remainingSec, restDuration));
  const rest = session.rest && (status === "resting" || session.pauseReturnStatus === "resting")
    ? {
        durationSec: restDuration,
        remainingSec: restRemaining,
        endsAt: String(session.rest.endsAt ?? ""),
        paused: Boolean(session.rest.paused),
        fromExerciseName: String(session.rest.fromExerciseName ?? ""),
        fromSetLabel: String(session.rest.fromSetLabel ?? ""),
      }
    : null;

  return {
    schemaVersion: WORKOUT_SESSION_SCHEMA_VERSION,
    id: String(session.id),
    date: String(session.date ?? localDateKey(startedAt)),
    routineId: String(session.routineId ?? ""),
    routineName: String(session.routineName ?? "Workout").trim() || "Workout",
    startedAt,
    lastSavedAt: timestamp(session.lastSavedAt ?? startedAt),
    status,
    pauseReturnStatus: session.pauseReturnStatus === "resting" ? "resting" : "active",
    pausedAt: String(session.pausedAt ?? ""),
    accumulatedPausedMs: nonNegativeNumber(session.accumulatedPausedMs, 0),
    cursor: pendingCursor && sessionSetAt({ exercises }, cursor)?.status !== "pending" ? pendingCursor : cursor,
    exercises,
    notes: String(session.notes ?? ""),
    rest,
    summaryAt: String(session.summaryAt ?? ""),
  };
}

export function createWorkoutSession({ routine, exercises = [], workouts = [], now = Date.now() }) {
  if (!routine) return null;
  const startedAt = timestamp(now);
  const sessionId = `session-${Date.parse(startedAt)}-${Math.random().toString(36).slice(2, 8)}`;
  const exerciseMap = new Map(exercises.map((exercise) => [exercise.id, exercise]));
  const sessionExercises = (routine.exerciseIds ?? []).map((exerciseId, exerciseIndex) => {
    const exercise = exerciseMap.get(exerciseId) ?? { id: exerciseId, name: "Exercise" };
    const plan = routine.plan?.[exerciseId] ?? { sets: 3, reps: "8", weight: 0, rest: 90 };
    const plannedSetCount = Math.max(1, Math.round(finiteNumber(plan.sets, 3)));
    const previousSets = previousSetsForExercise(workouts, exercise);
    const sets = Array.from({ length: plannedSetCount }, (_, setIndex) => {
      const previous = previousSets[setIndex] ?? previousSets.at(-1);
      const reps = String(previous?.reps ?? plan.reps ?? "8").trim() || "8";
      const weight = nonNegativeNumber(previous?.weight, nonNegativeNumber(plan.weight, 0));
      return {
        id: `${sessionId}-exercise-${exerciseIndex + 1}-set-${setIndex + 1}`,
        plannedWeight: nonNegativeNumber(plan.weight, weight),
        plannedReps: String(plan.reps ?? reps).trim() || reps,
        previousWeight: previous ? nonNegativeNumber(previous.weight, 0) : "",
        previousReps: previous ? String(previous.reps ?? "").trim() : "",
        weight,
        reps,
        rpe: "",
        effort: "",
        setType: "working",
        blockId: "",
        round: "",
        status: "pending",
        completedAt: "",
      };
    });
    return {
      exerciseId: String(exercise.id ?? exerciseId),
      name: String(exercise.name ?? "Exercise"),
      equipment: String(exercise.equipment ?? ""),
      movement: String(exercise.movement ?? ""),
      primaryMuscles: Array.isArray(exercise.primaryMuscles) ? [...exercise.primaryMuscles] : [],
      secondaryMuscles: Array.isArray(exercise.secondaryMuscles) ? [...exercise.secondaryMuscles] : [],
      substitutedForExerciseId: "",
      substitutedForName: "",
      metricKind: inferWorkoutMetricKind(sets[0]?.reps, exercise),
      restSec: Math.round(nonNegativeNumber(plan.rest, 90)),
      notes: "",
      sets,
    };
  });

  return normalizeActiveWorkoutSession({
    schemaVersion: WORKOUT_SESSION_SCHEMA_VERSION,
    id: sessionId,
    date: localDateKey(now),
    routineId: String(routine.id ?? ""),
    routineName: String(routine.name ?? "Workout"),
    startedAt,
    lastSavedAt: startedAt,
    status: sessionExercises.some((exercise) => exercise.sets.length) ? "active" : "summary",
    pauseReturnStatus: "active",
    pausedAt: "",
    accumulatedPausedMs: 0,
    cursor: { exerciseIndex: 0, setIndex: 0 },
    exercises: sessionExercises,
    notes: "",
    rest: null,
    summaryAt: sessionExercises.some((exercise) => exercise.sets.length) ? "" : startedAt,
  });
}

export function workoutSessionCurrent(session) {
  const normalized = normalizeActiveWorkoutSession(session);
  if (!normalized) return null;
  const exercise = normalized.exercises[normalized.cursor.exerciseIndex] ?? null;
  const set = exercise?.sets?.[normalized.cursor.setIndex] ?? null;
  return exercise && set ? { exercise, set, cursor: normalized.cursor } : null;
}

export function patchWorkoutSessionSet(session, cursor, patch, now = Date.now()) {
  const normalized = normalizeActiveWorkoutSession(session);
  if (!normalized) return null;
  const safeCursor = normalizeCursor(normalized.exercises, cursor);
  const exercises = normalized.exercises.map((exercise, exerciseIndex) => (
    exerciseIndex !== safeCursor.exerciseIndex ? exercise : {
      ...exercise,
      sets: exercise.sets.map((set, setIndex) => (
        setIndex !== safeCursor.setIndex ? set : normalizeSessionSet({ ...set, ...patch }, set, set.id)
      )),
    }
  ));
  return withSavedAt({ ...normalized, exercises }, now);
}

export function patchWorkoutSessionExercise(session, exerciseIndex, patch, now = Date.now()) {
  const normalized = normalizeActiveWorkoutSession(session);
  if (!normalized || !normalized.exercises[exerciseIndex]) return normalized;
  return withSavedAt({
    ...normalized,
    exercises: normalized.exercises.map((exercise, index) => (
      index === exerciseIndex ? { ...exercise, ...patch } : exercise
    )),
  }, now);
}

export function completeWorkoutSessionSet(session, outcome = {}, now = Date.now()) {
  const normalized = normalizeActiveWorkoutSession(session);
  if (!normalized) return null;
  const current = workoutSessionCurrent(normalized);
  if (!current) return withSavedAt({ ...normalized, status: "summary", summaryAt: timestamp(now) }, now);
  const outcomeStatus = outcome.status === "failed" ? "failed" : outcome.status === "skipped" ? "skipped" : "completed";
  const effort = outcomeStatus === "failed"
    ? "failed"
    : EFFORT_VALUES.has(outcome.effort) ? outcome.effort : current.set.effort;
  let nextSession = patchWorkoutSessionSet(normalized, current.cursor, {
    status: outcomeStatus,
    effort,
    completedAt: timestamp(now),
  }, now);
  const nextCursor = nextPendingCursor(nextSession, current.cursor);
  if (!nextCursor) {
    return withSavedAt({
      ...nextSession,
      status: "summary",
      rest: null,
      summaryAt: timestamp(now),
    }, now);
  }

  if (outcomeStatus === "skipped") {
    return withSavedAt({ ...nextSession, status: "active", cursor: nextCursor, rest: null }, now);
  }

  const baseRest = current.set.setType === "warmup"
    ? Math.min(current.exercise.restSec, 45)
    : current.exercise.restSec;
  const durationSec = Math.round(nonNegativeNumber(outcome.restSec, baseRest));
  if (!durationSec) {
    return withSavedAt({ ...nextSession, status: "active", cursor: nextCursor, rest: null }, now);
  }

  return withSavedAt({
    ...nextSession,
    status: "resting",
    cursor: nextCursor,
    rest: {
      durationSec,
      remainingSec: durationSec,
      endsAt: timestamp(new Date(new Date(now).getTime() + durationSec * 1000)),
      paused: false,
      fromExerciseName: current.exercise.name,
      fromSetLabel: current.set.setType === "warmup" ? "Warm-up" : `Set ${current.cursor.setIndex + 1}`,
    },
  }, now);
}

export function workoutRestRemainingSeconds(session, now = Date.now()) {
  const normalized = normalizeActiveWorkoutSession(session);
  if (!normalized?.rest) return 0;
  if (normalized.rest.paused || !normalized.rest.endsAt) return Math.max(0, normalized.rest.remainingSec);
  return Math.max(0, Math.ceil((timestampMs(normalized.rest.endsAt) - new Date(now).getTime()) / 1000));
}

export function finishWorkoutSessionRest(session, now = Date.now()) {
  const normalized = normalizeActiveWorkoutSession(session);
  if (!normalized) return null;
  return withSavedAt({ ...normalized, status: "active", rest: null }, now);
}

export function adjustWorkoutSessionRest(session, deltaSec, now = Date.now()) {
  const normalized = normalizeActiveWorkoutSession(session);
  if (!normalized?.rest) return normalized;
  const remainingSec = Math.max(0, workoutRestRemainingSeconds(normalized, now) + finiteNumber(deltaSec, 0));
  if (!remainingSec) return finishWorkoutSessionRest(normalized, now);
  return withSavedAt({
    ...normalized,
    rest: {
      ...normalized.rest,
      remainingSec,
      endsAt: normalized.rest.paused
        ? ""
        : timestamp(new Date(new Date(now).getTime() + remainingSec * 1000)),
    },
  }, now);
}

export function toggleWorkoutRestTimer(session, now = Date.now()) {
  const normalized = normalizeActiveWorkoutSession(session);
  if (!normalized?.rest) return normalized;
  if (normalized.rest.paused) {
    const remainingSec = Math.max(0, normalized.rest.remainingSec);
    return withSavedAt({
      ...normalized,
      rest: {
        ...normalized.rest,
        paused: false,
        endsAt: timestamp(new Date(new Date(now).getTime() + remainingSec * 1000)),
      },
    }, now);
  }
  return withSavedAt({
    ...normalized,
    rest: {
      ...normalized.rest,
      paused: true,
      remainingSec: workoutRestRemainingSeconds(normalized, now),
      endsAt: "",
    },
  }, now);
}

export function pauseWorkoutSession(session, now = Date.now()) {
  const normalized = normalizeActiveWorkoutSession(session);
  if (!normalized || normalized.status === "paused" || normalized.status === "summary") return normalized;
  const pauseReturnStatus = normalized.status === "resting" ? "resting" : "active";
  const rest = normalized.rest && pauseReturnStatus === "resting"
    ? { ...normalized.rest, paused: true, remainingSec: workoutRestRemainingSeconds(normalized, now), endsAt: "" }
    : normalized.rest;
  return withSavedAt({
    ...normalized,
    status: "paused",
    pauseReturnStatus,
    pausedAt: timestamp(now),
    rest,
  }, now);
}

export function resumeWorkoutSession(session, now = Date.now()) {
  const normalized = normalizeActiveWorkoutSession(session);
  if (!normalized || normalized.status !== "paused") return normalized;
  const pausedDuration = Math.max(0, new Date(now).getTime() - timestampMs(normalized.pausedAt));
  const returnStatus = normalized.pauseReturnStatus === "resting" && normalized.rest ? "resting" : "active";
  const rest = normalized.rest && returnStatus === "resting"
    ? {
        ...normalized.rest,
        paused: false,
        endsAt: timestamp(new Date(new Date(now).getTime() + normalized.rest.remainingSec * 1000)),
      }
    : normalized.rest;
  return withSavedAt({
    ...normalized,
    status: returnStatus,
    pausedAt: "",
    accumulatedPausedMs: normalized.accumulatedPausedMs + pausedDuration,
    rest,
  }, now);
}

export function skipWorkoutSessionExercise(session, now = Date.now()) {
  const normalized = normalizeActiveWorkoutSession(session);
  if (!normalized) return null;
  const exerciseIndex = normalized.cursor.exerciseIndex;
  const exercises = normalized.exercises.map((exercise, index) => (
    index !== exerciseIndex ? exercise : {
      ...exercise,
      sets: exercise.sets.map((set) => (
        set.status === "pending" ? { ...set, status: "skipped", completedAt: timestamp(now) } : set
      )),
    }
  ));
  const nextSession = withSavedAt({ ...normalized, exercises, rest: null }, now);
  const nextCursor = firstPendingCursor(nextSession);
  return nextCursor
    ? withSavedAt({ ...nextSession, status: "active", cursor: nextCursor }, now)
    : withSavedAt({ ...nextSession, status: "summary", summaryAt: timestamp(now) }, now);
}

export function addWorkoutSessionSet(session, exerciseIndex, now = Date.now()) {
  const normalized = normalizeActiveWorkoutSession(session);
  const exercise = normalized?.exercises?.[exerciseIndex];
  if (!exercise) return normalized;
  const source = [...exercise.sets].reverse().find((set) => set.status !== "skipped")
    ?? exercise.sets.at(-1)
    ?? { weight: 0, reps: "8", plannedWeight: 0, plannedReps: "8" };
  const nextSet = normalizeSessionSet({
    ...source,
    id: `${normalized.id}-exercise-${exerciseIndex + 1}-set-${exercise.sets.length + 1}-${Date.now()}`,
    setType: "working",
    status: "pending",
    effort: "",
    rpe: "",
    completedAt: "",
  }, source);
  return withSavedAt({
    ...normalized,
    exercises: normalized.exercises.map((item, index) => (
      index === exerciseIndex ? { ...item, sets: [...item.sets, nextSet] } : item
    )),
    status: normalized.status === "summary" ? "active" : normalized.status,
    summaryAt: normalized.status === "summary" ? "" : normalized.summaryAt,
    cursor: normalized.status === "summary"
      ? { exerciseIndex, setIndex: exercise.sets.length }
      : normalized.cursor,
  }, now);
}

export function insertWorkoutWarmupSet(session, now = Date.now()) {
  const normalized = normalizeActiveWorkoutSession(session);
  const current = workoutSessionCurrent(normalized);
  if (!current) return normalized;
  const warmupWeight = Math.max(0, Math.round((current.set.weight * 0.5) / 2.5) * 2.5);
  const warmup = normalizeSessionSet({
    ...current.set,
    id: `${normalized.id}-warmup-${Date.now()}`,
    plannedWeight: warmupWeight,
    weight: warmupWeight,
    setType: "warmup",
    blockId: "",
    round: "",
    status: "pending",
    effort: "",
    rpe: "",
    completedAt: "",
  }, current.set);
  return withSavedAt({
    ...normalized,
    status: "active",
    rest: null,
    exercises: normalized.exercises.map((exercise, exerciseIndex) => (
      exerciseIndex !== current.cursor.exerciseIndex ? exercise : {
        ...exercise,
        sets: [
          ...exercise.sets.slice(0, current.cursor.setIndex),
          warmup,
          ...exercise.sets.slice(current.cursor.setIndex),
        ],
      }
    )),
    cursor: current.cursor,
  }, now);
}

export function moveWorkoutSessionCursor(session, cursor, now = Date.now()) {
  const normalized = normalizeActiveWorkoutSession(session);
  if (!normalized) return null;
  const safeCursor = normalizeCursor(normalized.exercises, cursor);
  if (sessionSetAt(normalized, safeCursor)?.status !== "pending") return normalized;
  const pausedDuration = normalized.status === "paused"
    ? Math.max(0, new Date(now).getTime() - timestampMs(normalized.pausedAt))
    : 0;
  return withSavedAt({
    ...normalized,
    status: "active",
    cursor: safeCursor,
    rest: null,
    pausedAt: "",
    accumulatedPausedMs: normalized.accumulatedPausedMs + pausedDuration,
    summaryAt: "",
  }, now);
}

export function substituteWorkoutSessionExercise(session, exerciseIndex, replacement, now = Date.now()) {
  const normalized = normalizeActiveWorkoutSession(session);
  const current = normalized?.exercises?.[exerciseIndex];
  if (!current || !replacement) return normalized;
  return withSavedAt({
    ...normalized,
    exercises: normalized.exercises.map((exercise, index) => (
      index !== exerciseIndex ? exercise : {
        ...exercise,
        exerciseId: String(replacement.id ?? replacement.exerciseId ?? exercise.exerciseId),
        name: String(replacement.name ?? exercise.name),
        equipment: String(replacement.equipment ?? ""),
        movement: String(replacement.movement ?? ""),
        primaryMuscles: Array.isArray(replacement.primaryMuscles) ? [...replacement.primaryMuscles] : [],
        secondaryMuscles: Array.isArray(replacement.secondaryMuscles) ? [...replacement.secondaryMuscles] : [],
        substitutedForExerciseId: exercise.substitutedForExerciseId || exercise.exerciseId,
        substitutedForName: exercise.substitutedForName || exercise.name,
        metricKind: inferWorkoutMetricKind(exercise.sets[normalized.cursor.setIndex]?.reps, replacement),
      }
    )),
  }, now);
}

export function endWorkoutSessionEarly(session, now = Date.now()) {
  const normalized = normalizeActiveWorkoutSession(session);
  if (!normalized) return null;
  const pausedDuration = normalized.status === "paused"
    ? Math.max(0, new Date(now).getTime() - timestampMs(normalized.pausedAt))
    : 0;
  return withSavedAt({
    ...normalized,
    status: "summary",
    rest: null,
    pausedAt: "",
    accumulatedPausedMs: normalized.accumulatedPausedMs + pausedDuration,
    summaryAt: timestamp(now),
  }, now);
}

export function workoutSessionElapsedMs(session, now = Date.now()) {
  const normalized = normalizeActiveWorkoutSession(session);
  if (!normalized) return 0;
  const start = timestampMs(normalized.startedAt);
  const end = timestampMs(normalized.summaryAt) || new Date(now).getTime();
  const livePause = normalized.status === "paused"
    ? Math.max(0, new Date(now).getTime() - timestampMs(normalized.pausedAt))
    : 0;
  return Math.max(0, end - start - normalized.accumulatedPausedMs - livePause);
}

export function workoutSessionStats(session) {
  const normalized = normalizeActiveWorkoutSession(session);
  const flat = flattenSessionSets(normalized);
  const completed = flat.filter(({ set }) => set.status === "completed").length;
  const failed = flat.filter(({ set }) => set.status === "failed").length;
  const skipped = flat.filter(({ set }) => set.status === "skipped").length;
  const warmups = flat.filter(({ set }) => set.setType === "warmup" && ["completed", "failed"].includes(set.status)).length;
  const workingSets = flat.filter(({ set }) => set.setType === "working" && ["completed", "failed"].includes(set.status)).length;
  const resolved = completed + failed + skipped;
  const total = flat.length;
  const volume = flat.reduce((sum, { set }) => {
    if (!isWorkoutSetCounted(set)) return sum;
    const reps = parseRepValue(set.reps);
    const weight = nonNegativeNumber(set.weight, 0);
    return sum + (weight > 0 ? weight * reps : reps);
  }, 0);
  const exercisesCompleted = (normalized?.exercises ?? []).filter((exercise) => (
    exercise.sets.length && exercise.sets.every((set) => set.status !== "pending")
  )).length;
  return {
    total,
    resolved,
    completed,
    failed,
    skipped,
    warmups,
    workingSets,
    pending: Math.max(0, total - resolved),
    volume,
    progress: total ? (resolved / total) * 100 : 100,
    exercisesCompleted,
    exerciseTotal: normalized?.exercises?.length ?? 0,
  };
}

export function workoutLogFromSession(session, now = Date.now()) {
  const normalized = normalizeActiveWorkoutSession(session);
  if (!normalized) return null;
  return {
    id: normalized.id,
    sessionId: normalized.id,
    date: normalized.date,
    routineId: normalized.routineId,
    routineName: normalized.routineName,
    duration: Math.max(1, Math.round(workoutSessionElapsedMs(normalized, now) / 60000)),
    notes: normalized.notes,
    exercises: normalized.exercises.map((exercise) => ({
      exerciseId: exercise.exerciseId,
      name: exercise.name,
      substitutedForExerciseId: exercise.substitutedForExerciseId,
      substitutedForName: exercise.substitutedForName,
      notes: exercise.notes,
      sets: exercise.sets.map((set) => ({
        weight: set.weight,
        reps: set.reps,
        rpe: set.rpe,
        effort: set.effort,
        setType: set.setType,
        blockId: set.blockId,
        round: set.round,
        status: set.status,
        completedAt: set.completedAt,
        done: set.status === "completed" || set.status === "failed",
      })),
    })),
  };
}
