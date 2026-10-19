.pragma library

// Talking to the desk goes through whatever command-line tool drives it, because Qt 6
// has no QML API for Bluetooth. This file only builds those commands and reads their
// output; Desk.qml runs them.

// Commands can take the preset height in whichever unit the tool wants:
// {cm}, {mm} or {m}. "idasen sit" needs none; "linak-controller --move-to {mm}" does.
// {position} is "sit" or "stand", for a command that names the preset, like idasen save.
function fillTemplate(template, heightCm, position) {
    var cm = Math.round(heightCm * 10) / 10;
    return ("" + template)
        .replace(/\{position\}/g, position || "")
        .replace(/\{cm\}/g, "" + cm)
        .replace(/\{mm\}/g, "" + Math.round(cm * 10))
        .replace(/\{m\}/g, (cm / 100).toFixed(3));
}

// A command that hangs - the desk out of range, the adapter off - must not hold the
// widget's next poll forever. coreutils timeout bounds it, and sh -c lets the user's
// template be a full shell command line.
function wrap(command, timeoutSeconds) {
    var quoted = "'" + ("" + command).replace(/'/g, "'\"'\"'") + "'";
    return "timeout " + timeoutSeconds + " sh -c " + quoted;
}

// The height out of a tool's output, in centimetres, or NaN when there is none.
//
// Tools differ: idasen prints metres, linak-controller millimetres, others plain
// centimetres. A unit next to the number is believed. A bare number is placed by its
// size, since no desk spans a range where the three readings could be confused:
// under 3 is metres, over 300 is millimetres.
//
// Output can carry other numbers too - a MAC address, a speed, a log timestamp - so the
// first reading that is a plausible desk height wins, not simply the first number.
var MIN_CM = 40;
var MAX_CM = 160;

function parseHeightCm(output) {
    var pattern = /(\d+(?:[.,]\d+)?)\s*(mm|cm|m(?:et(?:er|re)s?)?)?\b/gi;
    var match;
    while ((match = pattern.exec("" + output)) !== null) {
        var cm = toCm(parseFloat(match[1].replace(",", ".")), (match[2] || "").toLowerCase());
        if (cm >= MIN_CM && cm <= MAX_CM)
            return cm;
    }
    return NaN;
}

function toCm(value, unit) {
    if (unit === "mm")
        return value / 10;
    if (unit === "cm")
        return value;
    if (unit.charAt(0) === "m")
        return value * 100;
    if (value < 3)
        return value * 100;
    if (value > 300)
        return value / 10;
    return value;
}

// What to do after a move and the height read back from it: "done", "retry" or
// "stuck". Linak desks often stop part of the way, and running the move again finishes
// it. A move that does not shift the desk at all is another matter: something may be in
// the way, and the desk stopping is its anti-collision doing its job. So the retries
// end after `maxStalls` moves in a row that went nowhere, and after `maxAttempts` in all.
//
// `stalls` counts the moves before this one that went nowhere; the caller keeps it.
var ARRIVED_CM = 1.5;
var STALL_CM = 0.5;

function afterMove(targetCm, cm, previousCm, attempt, stalls, opts) {
    if (Math.abs(cm - targetCm) <= ARRIVED_CM)
        return "done";
    var stalled = !isNaN(previousCm) && Math.abs(cm - previousCm) < STALL_CM;
    if (stalled && stalls + 1 >= opts.maxStalls)
        return "stuck";
    if (attempt >= opts.maxAttempts)
        return "stuck";
    return "retry";
}
