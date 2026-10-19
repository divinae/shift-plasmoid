import QtQuick
import QtTest
import "../package/contents/ui/lib/desk.js" as Desk

TestCase {
    name: "Desk"

    function test_parseHeightCm_data() {
        return [
            { tag: "idasen metres", out: "0.7200 meters\n", expected: 72 },
            { tag: "metre short", out: "1.1 m", expected: 110 },
            { tag: "millimetres", out: "Height: 720mm Speed: 0mm/s", expected: 72 },
            { tag: "centimetres", out: "height 108.5 cm", expected: 108.5 },
            { tag: "comma decimal", out: "0,72 m", expected: 72 },
            { tag: "bare metres", out: "0.72", expected: 72 },
            { tag: "bare millimetres", out: "1100", expected: 110 },
            { tag: "bare centimetres", out: "95", expected: 95 },
            { tag: "skips a MAC address", out: "Connected to E8:5B:5B:24:22:E4\n0.7200 meters", expected: 72 },
            { tag: "skips a speed", out: "speed 0 mm/s height 720 mm", expected: 72 }
        ];
    }

    function test_parseHeightCm(data) {
        fuzzyCompare(Desk.parseHeightCm(data.out), data.expected, 0.001);
    }

    function test_parseHeightCm_nothing() {
        verify(isNaN(Desk.parseHeightCm("")));
        verify(isNaN(Desk.parseHeightCm("Failed to connect")));
    }

    function test_fillTemplate() {
        compare(Desk.fillTemplate("idasen sit", 72), "idasen sit");
        compare(Desk.fillTemplate("linak-controller --move-to {mm}", 72), "linak-controller --move-to 720");
        compare(Desk.fillTemplate("desk {cm} {cm}", 108.5), "desk 108.5 108.5");
        compare(Desk.fillTemplate("desk {m}", 110), "desk 1.100");
        compare(Desk.fillTemplate("idasen save {position}", 67.5, "sit"), "idasen save sit");
    }

    function test_wrapQuotes() {
        compare(Desk.wrap("idasen sit", 30), "timeout 30 sh -c 'idasen sit'");
        compare(Desk.wrap("echo 'a'", 5), "timeout 5 sh -c 'echo '\"'\"'a'\"'\"''");
    }

    function test_afterMove_data() {
        var opts = { maxAttempts: 8, maxStalls: 2 };
        return [
            { tag: "arrived", target: 72, cm: 72.4, prev: 110, attempt: 1, stalls: 0, opts: opts, expected: "done" },
            { tag: "stopped halfway", target: 72, cm: 90, prev: 110, attempt: 1, stalls: 0, opts: opts, expected: "retry" },
            { tag: "first move went nowhere", target: 72, cm: 110, prev: 110, attempt: 1, stalls: 0, opts: opts, expected: "retry" },
            { tag: "second move in a row went nowhere", target: 72, cm: 90, prev: 90.2, attempt: 3, stalls: 1, opts: opts, expected: "stuck" },
            { tag: "out of attempts", target: 72, cm: 80, prev: 85, attempt: 8, stalls: 0, opts: opts, expected: "stuck" },
            { tag: "height unknown before", target: 72, cm: 90, prev: NaN, attempt: 1, stalls: 0, opts: opts, expected: "retry" },
            { tag: "raising", target: 110, cm: 109, prev: 72, attempt: 1, stalls: 0, opts: opts, expected: "done" }
        ];
    }

    function test_afterMove(data) {
        compare(Desk.afterMove(data.target, data.cm, data.prev, data.attempt, data.stalls, data.opts), data.expected);
    }
}
