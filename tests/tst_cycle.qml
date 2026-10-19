import QtQuick
import QtTest
import "../package/contents/ui/lib/cycle.js" as Cycle

TestCase {
    name: "Cycle"

    readonly property var cfg: ({ sitMinutes: 45, standMinutes: 15 })
    readonly property int min: 60 * 1000

    // Runs the clock forward in one-second ticks, as the engine timer does.
    function run(state, startMs, ms) {
        var t = startMs;
        while (t < startMs + ms) {
            t += 1000;
            state = Cycle.advance(state, t, 1000, cfg);
        }
        return state;
    }

    function test_freshStartsSitting() {
        var s = Cycle.fresh();
        compare(s.position, "sit");
        compare(s.elapsedMs, 0);
        compare(Cycle.status(s, 0), "sit");
    }

    function test_dueAfterTarget() {
        var s = run(Cycle.fresh("sit"), 0, 45 * min - 1000);
        compare(Cycle.status(s, 45 * min), "sit");
        s = Cycle.advance(s, 45 * min, 1000, cfg);
        compare(Cycle.status(s, 45 * min), "due");
        compare(s.dueSinceMs, 45 * min);
    }

    function test_standUsesItsOwnTarget() {
        var s = run(Cycle.fresh("stand"), 0, 15 * min);
        compare(Cycle.status(s, 15 * min), "due");
    }

    function test_suspendGapNotCounted() {
        var s = Cycle.advance(Cycle.fresh(), 60 * min, 60 * min, cfg);
        compare(s.elapsedMs, 0);
    }

    function test_advanceDoesNotMutate() {
        var s = Cycle.fresh();
        Cycle.advance(s, 1000, 1000, cfg);
        compare(s.elapsedMs, 0);
    }

    function test_moveToResets() {
        var s = run(Cycle.fresh("sit"), 0, 50 * min);
        s = Cycle.moveTo(s, "stand");
        compare(s.position, "stand");
        compare(s.elapsedMs, 0);
        compare(s.dueSinceMs, 0);
    }

    function test_moveToSamePositionKeepsCount() {
        var s = run(Cycle.fresh("sit"), 0, 10 * min);
        s = Cycle.moveTo(s, "sit");
        compare(s.elapsedMs, 10 * min);
    }

    function test_snooze() {
        var s = run(Cycle.fresh("sit"), 0, 45 * min);
        s = Cycle.snooze(s, 45 * min, 10);
        compare(Cycle.status(s, 50 * min), "snoozed");
        compare(Cycle.status(s, 55 * min), "due");
    }

    function test_awayStopsTheCount() {
        var s = run(Cycle.fresh("sit"), 0, 10 * min);
        s = Cycle.leave(s, 10 * min);
        compare(Cycle.status(s, 11 * min), "away");
        s = run(s, 10 * min, 2 * min);
        compare(s.elapsedMs, 10 * min);
    }

    function test_shortAbsenceKeepsCount() {
        var s = run(Cycle.fresh("sit"), 0, 10 * min);
        s = Cycle.leave(s, 10 * min);
        s = Cycle.returnAt(s, 12 * min);
        compare(s.elapsedMs, 10 * min);
        compare(s.awaySinceMs, 0);
    }

    function test_longAbsenceResets() {
        var s = run(Cycle.fresh("stand"), 0, 10 * min);
        s = Cycle.leave(s, 10 * min);
        s = Cycle.returnAt(s, 20 * min);
        compare(s.elapsedMs, 0);
        compare(s.position, "stand");
        compare(s.awaySinceMs, 0);
    }

    function test_positionFromHeight_data() {
        return [
            { tag: "at sit preset", h: 72, expected: "sit" },
            { tag: "at stand preset", h: 110, expected: "stand" },
            { tag: "just below midpoint", h: 90.9, expected: "sit" },
            { tag: "at midpoint", h: 91, expected: "stand" }
        ];
    }

    function test_positionFromHeight(data) {
        compare(Cycle.positionFromHeight(data.h, 72, 110), data.expected);
    }

    function test_restoreRecent() {
        var s = run(Cycle.fresh("stand"), 0, 7 * min);
        var r = Cycle.restore(Cycle.serialize(s, 7 * min), 8 * min);
        compare(r.position, "stand");
        compare(r.elapsedMs, 7 * min);
    }

    function test_restoreStaleKeepsPositionOnly() {
        var s = run(Cycle.fresh("stand"), 0, 7 * min);
        var r = Cycle.restore(Cycle.serialize(s, 7 * min), 60 * min);
        compare(r.position, "stand");
        compare(r.elapsedMs, 0);
    }

    function test_restoreGarbage() {
        compare(Cycle.restore("", 0).position, "sit");
        compare(Cycle.restore("{nope", 0).position, "sit");
        compare(Cycle.restore("null", 0).position, "sit");
    }

    function test_dayKey() {
        compare(Cycle.dayKey(new Date(2026, 0, 5)), "2026-01-05");
        compare(Cycle.dayKey(new Date(2026, 9, 19)), "2026-10-19");
    }

    function test_addStandingAccumulatesAndPrunes() {
        var h = {};
        h = Cycle.addStanding(h, "2026-10-17", 30 * min, 2);
        h = Cycle.addStanding(h, "2026-10-18", 30 * min, 2);
        h = Cycle.addStanding(h, "2026-10-18", 15 * min, 2);
        compare(h["2026-10-18"], 45);
        h = Cycle.addStanding(h, "2026-10-19", 1 * min, 2);
        compare(Object.keys(h).sort(), ["2026-10-18", "2026-10-19"]);
    }

    function test_parseHistory() {
        compare(Cycle.parseHistory(""), {});
        compare(Cycle.parseHistory("[1]"), {});
        compare(Cycle.parseHistory('{"2026-10-19": 12}')["2026-10-19"], 12);
    }

    function test_streak() {
        var h = { "2026-10-16": 120, "2026-10-17": 130, "2026-10-18": 125, "2026-10-19": 10 };
        // Today is not met yet, so the streak runs to yesterday.
        compare(Cycle.streak(h, new Date(2026, 9, 19, 9), 120), 3);
        h["2026-10-19"] = 120;
        compare(Cycle.streak(h, new Date(2026, 9, 19, 18), 120), 4);
        // A gap breaks it.
        delete h["2026-10-17"];
        compare(Cycle.streak(h, new Date(2026, 9, 19, 18), 120), 2);
        compare(Cycle.streak(h, new Date(2026, 9, 19), 0), 0);
    }

    function test_formatMinutes() {
        compare(Cycle.formatMinutes(0), "0 min");
        compare(Cycle.formatMinutes(30 * 1000), "1 min");
        compare(Cycle.formatMinutes(45 * min), "45 min");
        compare(Cycle.formatMinutes(60 * min), "1 h");
        compare(Cycle.formatMinutes(95 * min), "1 h 35 min");
    }

    function test_pauseStopsTheCount() {
        var s = run(Cycle.fresh("sit"), 0, 10 * min);
        s = Cycle.pause(s, 10 * min, 30);
        compare(Cycle.status(s, 11 * min), "paused");
        s = run(s, 10 * min, 20 * min);
        compare(s.elapsedMs, 10 * min);
        // Expires on its own.
        compare(Cycle.status(s, 40 * min), "sit");
        s = run(s, 40 * min, 5 * min);
        compare(s.elapsedMs, 15 * min);
    }

    function test_pauseUntilResumed() {
        var s = Cycle.pause(Cycle.fresh("sit"), 0, 0);
        compare(Cycle.status(s, 1000 * min), "paused");
        s = Cycle.resume(s);
        compare(Cycle.status(s, 1000 * min), "sit");
    }

    function test_pauseSurvivesMoveAndRestore() {
        var s = Cycle.pause(Cycle.fresh("sit"), 0, 0);
        s = Cycle.moveTo(s, "stand");
        compare(Cycle.status(s, min), "paused");
        // Restored even when the rest of the saved state is too old to trust.
        var r = Cycle.restore(Cycle.serialize(s, 0), 60 * min);
        compare(Cycle.status(r, 60 * min), "paused");
        var timed = Cycle.pause(Cycle.fresh("sit"), 0, 30);
        compare(Cycle.status(Cycle.restore(Cycle.serialize(timed, 0), 60 * min), 60 * min), "sit");
    }

    function test_offHoursStopsTheCount() {
        var s = Cycle.advance(Cycle.fresh("sit"), 1000, 1000, { sitMinutes: 45, standMinutes: 15, offHours: true });
        compare(s.elapsedMs, 0);
        compare(Cycle.status(s, 1000, { offHours: true }), "off");
    }

    function test_inWorkHours_data() {
        var day = { enabled: true, startMinutes: 9 * 60, endMinutes: 17 * 60, weekdaysOnly: true };
        var night = { enabled: true, startMinutes: 22 * 60, endMinutes: 6 * 60, weekdaysOnly: false };
        // 2026-10-19 is a Monday, 2026-10-24 a Saturday.
        return [
            { tag: "disabled", cfg: { enabled: false }, date: new Date(2026, 9, 24, 3, 0), expected: true },
            { tag: "inside", cfg: day, date: new Date(2026, 9, 19, 12, 0), expected: true },
            { tag: "at the start", cfg: day, date: new Date(2026, 9, 19, 9, 0), expected: true },
            { tag: "at the end", cfg: day, date: new Date(2026, 9, 19, 17, 0), expected: false },
            { tag: "before", cfg: day, date: new Date(2026, 9, 19, 8, 59), expected: false },
            { tag: "weekend", cfg: day, date: new Date(2026, 9, 24, 12, 0), expected: false },
            { tag: "across midnight, late", cfg: night, date: new Date(2026, 9, 19, 23, 0), expected: true },
            { tag: "across midnight, early", cfg: night, date: new Date(2026, 9, 20, 5, 0), expected: true },
            { tag: "across midnight, day", cfg: night, date: new Date(2026, 9, 20, 12, 0), expected: false }
        ];
    }

    function test_inWorkHours(data) {
        compare(Cycle.inWorkHours(data.date, data.cfg), data.expected);
    }

    function test_lastDays() {
        var days = Cycle.lastDays({ "2026-10-19": 30, "2026-10-13": 5, "2026-10-12": 99 }, new Date(2026, 9, 19, 10), 7);
        compare(days.length, 7);
        compare(days[0].key, "2026-10-13");
        compare(days[0].minutes, 5);
        compare(days[6].key, "2026-10-19");
        compare(days[6].minutes, 30);
        compare(days[3].minutes, 0);
    }
}
