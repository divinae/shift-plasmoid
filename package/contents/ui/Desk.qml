import "./lib"
import "./lib/desk.js" as DeskLogic
import QtQuick

// Drives the desk through its command-line tool. Knows nothing about the cycle: it
// reports heights and failures, and main.qml decides what they mean.
Item {
    id: desk

    property string sitCmd
    property string standCmd
    property string heightCmd
    property real sitHeightCm
    property real standHeightCm

    // NaN until the first successful read.
    property real heightCm: NaN
    // A move takes the desk up to twenty seconds; a read is a connect and a query.
    readonly property int moveTimeout: 45
    readonly property int readTimeout: 20
    property bool moving: false
    property bool reading: false

    signal heightRead(real cm)
    signal failed(string what, string detail)

    // A move that stops short is run again; see DeskLogic.afterMove for when that ends.
    readonly property int maxAttempts: 8
    readonly property int maxStalls: 2
    // Short: every idasen command opens a new Bluetooth connection (about 6 s), and a retry
    // already pays for two - the height read, then the move - before the desk moves again.
    readonly property int retryDelayMs: 500
    // 1 for the first try of a move, more while retrying. 0 when idle.
    property int attempt: 0
    property real targetCm: NaN
    property string target: ""
    property real heightBeforeCm: NaN
    // Where the whole move started, for the popup. heightBeforeCm moves on with each retry.
    property real startCm: NaN
    property int stalls: 0
    property string lastMoveError: ""
    property bool cancelled: false
    // A move asked for while a height read was still talking to the desk. It starts once
    // the read is done: two connections at once can fail, and the read-back after the move
    // would otherwise reuse the command still in flight.
    property string queuedPosition: ""

    function readHeight() {
        if (reading || moving || !heightCmd)
            return;
        read(function(cm) {});
    }

    // Reads the height and reports it; `done` gets the height, or NaN on failure.
    function read(done) {
        reading = true;
        const started = Date.now();
        exec.exec(DeskLogic.wrap(heightCmd, readTimeout), function(cmd, exitCode, exitStatus, stdout, stderr) {
            desk.reading = false;
            if (desk.moving)
                console.log("Stand: height read took", Date.now() - started, "ms:", ("" + stdout).trim());
            var cm = DeskLogic.parseHeightCm(stdout);
            if (exitCode !== 0 || isNaN(cm)) {
                desk.failed("height", desk.detail(exitCode, stdout, stderr));
                done(NaN);
            } else {
                desk.heightCm = cm;
                desk.heightRead(cm);
                done(cm);
            }
            if (desk.queuedPosition) {
                const position = desk.queuedPosition;
                desk.queuedPosition = "";
                desk.startMove(position);
            }
        });
    }

    // Returns whether a move was started (or queued behind a read), so the caller can
    // fall back to a reminder when the desk cannot be asked to move.
    function moveTo(position) {
        var template = position === "stand" ? standCmd : sitCmd;
        if (moving || !template)
            return false;
        if (reading) {
            moving = true;
            queuedPosition = position;
            return true;
        }
        startMove(position);
        return true;
    }

    function startMove(position) {
        moving = true;
        cancelled = false;
        target = position;
        targetCm = position === "stand" ? standHeightCm : sitHeightCm;
        attempt = 0;
        stalls = 0;
        heightBeforeCm = heightCm;
        startCm = heightCm;
        runMove();
    }

    // Stops retrying. A move already running finishes; idasen has no stop command.
    function cancel() {
        cancelled = true;
        if (queuedPosition) {
            queuedPosition = "";
            finish();
            return;
        }
        if (retryTimer.running) {
            retryTimer.stop();
            finish();
        }
    }

    function runMove() {
        attempt += 1;
        const started = Date.now();
        console.log("Stand: move to", target, "attempt", attempt);
        var template = target === "stand" ? standCmd : sitCmd;
        exec.exec(DeskLogic.wrap(DeskLogic.fillTemplate(template, targetCm, target), moveTimeout), function(cmd, exitCode, exitStatus, stdout, stderr) {
            desk.lastMoveError = exitCode !== 0 ? desk.detail(exitCode, stdout, stderr) : "";
            console.log("Stand: move command took", Date.now() - started, "ms, exit", exitCode);
            // Not found will not get better by trying again.
            if (exitCode === 127) {
                desk.failed("move", desk.lastMoveError);
                desk.finish();
                return;
            }
            // Read back either way: the desk may have moved part of the way, and the
            // height, not the command, says where the user is.
            desk.read(desk.checkArrival);
        });
    }

    function checkArrival(cm) {
        if (cancelled) {
            finish();
            return;
        }
        if (isNaN(cm)) {
            // The read already reported its failure.
            finish();
            return;
        }
        var next = DeskLogic.afterMove(targetCm, cm, heightBeforeCm, attempt, stalls, {
            maxAttempts: maxAttempts,
            maxStalls: maxStalls
        });
        if (next === "done") {
            finish();
            return;
        }
        if (next === "stuck") {
            failed("move", lastMoveError || i18n("The desk stopped at %1 cm, short of %2 cm.", Math.round(cm), Math.round(targetCm)));
            finish();
            return;
        }
        stalls = Math.abs(cm - heightBeforeCm) < DeskLogic.STALL_CM ? stalls + 1 : 0;
        heightBeforeCm = cm;
        retryTimer.start();
    }

    function finish() {
        moving = false;
        attempt = 0;
    }

    // The useful line out of a failure, for a notification. timeout exits 124.
    function detail(exitCode, stdout, stderr) {
        if (exitCode === 124)
            return i18n("The desk did not answer in time.");
        if (exitCode === 127)
            return i18n("The desk command was not found.");
        var lines = (("" + stderr).trim() || ("" + stdout).trim()).split("\n");
        return lines[lines.length - 1] || i18n("The command exited with code %1.", exitCode);
    }

    Timer {
        id: retryTimer

        interval: desk.retryDelayMs
        onTriggered: desk.runMove()
    }

    ExecUtil {
        id: exec
    }
}
