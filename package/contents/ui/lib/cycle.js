.pragma library

// The sit/stand cycle, kept free of QML so the tests can drive it with a fake clock.
//
// The state is a plain object, and every function here returns a new one rather than
// changing its argument, so main.qml can assign the result to a property and get the
// change notification for free:
//
//   position     "sit" or "stand" - where the user is now
//   elapsedMs    time spent in that position, counting only while present
//   dueSinceMs   wall clock when the switch fell due, 0 while it is not due
//   snoozeUntil  wall clock before which a due switch stays quiet
//   awaySinceMs  wall clock when the user left (screen locked), 0 while present
//   pausedUntilMs  wall clock the pause ends at, UNTIL_RESUMED, or 0 when not paused

// A tick longer than this is the machine having slept, not time spent at the desk.
var MAX_TICK_MS = 2 * 60 * 1000;
// Away this long and the user has moved, whichever position they left in, so the
// cycle starts over. A shorter absence - fetching a coffee - leaves it alone.
var AWAY_RESET_MS = 5 * 60 * 1000;
// A state saved longer ago than this is from another sitting: the applet was off,
// so nothing is known about what happened in between.
var RESTORE_MAX_AGE_MS = 5 * 60 * 1000;
// A pause with no end. Not Infinity, which JSON would save as null.
var UNTIL_RESUMED = -1;

function fresh(position) {
    return {
        position: position === "stand" ? "stand" : "sit",
        elapsedMs: 0,
        dueSinceMs: 0,
        snoozeUntil: 0,
        awaySinceMs: 0,
        pausedUntilMs: 0
    };
}

function copy(state) {
    return {
        position: state.position,
        elapsedMs: state.elapsedMs,
        dueSinceMs: state.dueSinceMs,
        snoozeUntil: state.snoozeUntil,
        awaySinceMs: state.awaySinceMs,
        pausedUntilMs: state.pausedUntilMs || 0
    };
}

function opposite(position) {
    return position === "stand" ? "sit" : "stand";
}

// cfg is { sitMinutes, standMinutes }.
function targetMs(position, cfg) {
    return (position === "stand" ? cfg.standMinutes : cfg.sitMinutes) * 60 * 1000;
}

function remainingMs(state, cfg) {
    return Math.max(0, targetMs(state.position, cfg) - state.elapsedMs);
}

// 0..1 toward the next switch, for the progress ring.
function progress(state, cfg) {
    var target = targetMs(state.position, cfg);
    return target > 0 ? Math.min(1, state.elapsedMs / target) : 1;
}

// Moves the clock on by dtMs. Time only counts while the user is present, not paused
// and inside working hours (cfg.offHours), and a gap longer than MAX_TICK_MS is dropped
// as a suspend.
function advance(state, nowMs, dtMs, cfg) {
    var next = copy(state);
    if (next.awaySinceMs || isPaused(next, nowMs) || cfg.offHours || dtMs <= 0 || dtMs > MAX_TICK_MS)
        return next;
    next.elapsedMs += dtMs;
    if (!next.dueSinceMs && next.elapsedMs >= targetMs(next.position, cfg))
        next.dueSinceMs = nowMs;
    return next;
}

// The user is now in `position`, whether by a button, a notification action or the desk
// reporting a new height. A change of position starts the count over; reporting the
// position the user is already in changes nothing, so the desk poll can call this freely.
function moveTo(state, position) {
    if (position === state.position)
        return copy(state);
    var next = fresh(position);
    next.awaySinceMs = state.awaySinceMs;
    next.pausedUntilMs = state.pausedUntilMs || 0;
    return next;
}

function snooze(state, nowMs, minutes) {
    var next = copy(state);
    next.snoozeUntil = nowMs + minutes * 60 * 1000;
    return next;
}

// minutes <= 0 pauses until resume().
function pause(state, nowMs, minutes) {
    var next = copy(state);
    next.pausedUntilMs = minutes > 0 ? nowMs + minutes * 60 * 1000 : UNTIL_RESUMED;
    return next;
}

function resume(state) {
    var next = copy(state);
    next.pausedUntilMs = 0;
    return next;
}

function isPaused(state, nowMs) {
    return state.pausedUntilMs === UNTIL_RESUMED || nowMs < state.pausedUntilMs;
}

function leave(state, nowMs) {
    var next = copy(state);
    if (!next.awaySinceMs)
        next.awaySinceMs = nowMs;
    return next;
}

function returnAt(state, nowMs) {
    if (!state.awaySinceMs)
        return copy(state);
    if (nowMs - state.awaySinceMs >= AWAY_RESET_MS) {
        var reset = fresh(state.position);
        reset.pausedUntilMs = state.pausedUntilMs || 0;
        return reset;
    }
    var next = copy(state);
    next.awaySinceMs = 0;
    return next;
}

// What the widget should show and do now. ctx is { offHours }.
//
//   "away"      the user is not at the desk
//   "paused"    the user paused the cycle
//   "off"       outside working hours
//   "snoozed"   a switch is due, and the user asked for a few more minutes
//   "due"       time to switch
//   "sit" / "stand"  counting toward the next switch
function status(state, nowMs, ctx) {
    if (state.awaySinceMs)
        return "away";
    if (isPaused(state, nowMs))
        return "paused";
    if (ctx && ctx.offHours)
        return "off";
    if (!state.dueSinceMs)
        return state.position;
    if (nowMs < state.snoozeUntil)
        return "snoozed";
    return "due";
}

// Whether `date` falls in the working hours. cfg is
// { enabled, startMinutes, endMinutes, weekdaysOnly }, minutes counted from midnight.
// An end before the start is a window across midnight.
function inWorkHours(date, cfg) {
    if (!cfg.enabled)
        return true;
    var day = date.getDay();
    if (cfg.weekdaysOnly && (day === 0 || day === 6))
        return false;
    var m = date.getHours() * 60 + date.getMinutes();
    if (cfg.startMinutes <= cfg.endMinutes)
        return m >= cfg.startMinutes && m < cfg.endMinutes;
    return m >= cfg.startMinutes || m < cfg.endMinutes;
}

// The desk's height says where the user is. Midway between the two presets is the
// line: anything a desk is likely to be left at sits clearly on one side of it.
function positionFromHeight(heightCm, sitCm, standCm) {
    return heightCm >= (sitCm + standCm) / 2 ? "stand" : "sit";
}

// Saved state, so a Plasma restart does not lose the count.

function serialize(state, nowMs) {
    var saved = copy(state);
    saved.savedAt = nowMs;
    return JSON.stringify(saved);
}

function restore(text, nowMs) {
    var saved;
    try {
        saved = JSON.parse(text);
    } catch (e) {
        return fresh("sit");
    }
    if (!saved || typeof saved !== "object")
        return fresh("sit");
    var state = fresh(saved.position);
    // A pause outlives a restart: it is what the user asked for, not a count that went
    // stale while the applet was off.
    if (saved.pausedUntilMs === UNTIL_RESUMED || (typeof saved.pausedUntilMs === "number" && saved.pausedUntilMs > nowMs))
        state.pausedUntilMs = saved.pausedUntilMs;
    if (typeof saved.savedAt !== "number" || nowMs - saved.savedAt > RESTORE_MAX_AGE_MS
            || nowMs < saved.savedAt)
        return state;
    if (typeof saved.elapsedMs === "number" && saved.elapsedMs > 0)
        state.elapsedMs = saved.elapsedMs;
    if (typeof saved.dueSinceMs === "number")
        state.dueSinceMs = saved.dueSinceMs;
    if (typeof saved.snoozeUntil === "number")
        state.snoozeUntil = saved.snoozeUntil;
    return state;
}

// Daily standing time: a map of local day ("2026-10-19") to minutes stood.

function dayKey(date) {
    var m = date.getMonth() + 1;
    var d = date.getDate();
    return date.getFullYear() + "-" + (m < 10 ? "0" : "") + m + "-" + (d < 10 ? "0" : "") + d;
}

function parseHistory(text) {
    try {
        var parsed = JSON.parse(text);
        return parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : {};
    } catch (e) {
        return {};
    }
}

// Adds standing time to a day, and drops days older than keepDays so the stored
// string does not grow forever.
function addStanding(history, key, ms, keepDays) {
    var next = {};
    for (var k in history)
        next[k] = history[k];
    next[key] = (next[key] || 0) + ms / 60000;
    // The keys are ISO dates, so sorting them as strings sorts them by day.
    var all = Object.keys(next).sort();
    while (all.length > keepDays)
        delete next[all.shift()];
    return next;
}

function minutesOn(history, key) {
    return history[key] || 0;
}

// The last `count` days ending today, oldest first, for the week chart.
function lastDays(history, today, count) {
    var days = [];
    for (var i = count - 1; i >= 0; i--) {
        var d = new Date(today.getFullYear(), today.getMonth(), today.getDate() - i);
        days.push({ key: dayKey(d), date: d, minutes: minutesOn(history, dayKey(d)) });
    }
    return days;
}

// Days in a row that met the goal, ending today. Today counts once it is met; until
// then the streak runs to yesterday, so it does not read 0 every morning.
function streak(history, today, goalMinutes) {
    if (goalMinutes <= 0)
        return 0;
    var day = new Date(today.getFullYear(), today.getMonth(), today.getDate());
    if (minutesOn(history, dayKey(day)) < goalMinutes)
        day.setDate(day.getDate() - 1);
    var count = 0;
    while (minutesOn(history, dayKey(day)) >= goalMinutes) {
        count++;
        day.setDate(day.getDate() - 1);
    }
    return count;
}

function formatMinutes(ms) {
    var total = Math.ceil(ms / 60000);
    if (total < 60)
        return total + " min";
    var h = Math.floor(total / 60);
    var m = total % 60;
    return h + " h" + (m ? " " + m + " min" : "");
}
