import "./lib"
import "./lib/cycle.js" as Cycle
import QtQml
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    readonly property var workHours: ({
        enabled: plasmoid.configuration.work_hours_enabled,
        startMinutes: plasmoid.configuration.work_start_minutes,
        endMinutes: plasmoid.configuration.work_end_minutes,
        weekdaysOnly: plasmoid.configuration.work_weekdays_only
    })
    readonly property bool offHours: !Cycle.inWorkHours(new Date(nowMs), workHours)
    readonly property var cfg: ({
        sitMinutes: plasmoid.configuration.sit_minutes,
        standMinutes: plasmoid.configuration.stand_minutes,
        offHours: offHours
    })
    readonly property bool deskEnabled: plasmoid.configuration.desk_enabled
    readonly property int goalMinutes: plasmoid.configuration.daily_goal_minutes

    // The cycle and the standing history are plain objects from cycle.js. Each change
    // assigns a new object, which is what makes the bindings below re-evaluate.
    property var cycle: Cycle.fresh("sit")
    property var history: ({})
    property real nowMs: Date.now()
    property real lastTickMs: Date.now()
    // Standing time not yet written to config. Writing every second would rewrite the
    // applet's config file every second.
    property real unsavedStandMs: 0

    // Do Not Disturb, as the notification server reports it. Reminders wait while it is on.
    property bool dndActive: false
    // A reminder held back by Do Not Disturb, shown once it ends.
    property bool pendingRemind: false
    readonly property string dndCmd: "dbus-send --session --print-reply=literal --dest=org.freedesktop.Notifications /org/freedesktop/Notifications org.freedesktop.DBus.Properties.Get string:org.freedesktop.Notifications string:Inhibited"
    readonly property string lockCmd: "dbus-send --session --print-reply=literal --dest=org.freedesktop.ScreenSaver /ScreenSaver org.freedesktop.ScreenSaver.GetActive"

    readonly property string status: Cycle.status(cycle, nowMs, { offHours: offHours })
    // Not counting toward a switch: the panel drops the ring and dims the figure.
    readonly property bool idle: status === "away" || status === "paused" || status === "off"
    readonly property bool switchDue: status === "due"
    readonly property real remainingMs: Cycle.remainingMs(cycle, cfg)
    // Changes once a day, unlike nowMs, so what depends on the day alone - the streak,
    // the chart's days - is not recomputed every second.
    readonly property string todayKey: Cycle.dayKey(new Date(nowMs))
    readonly property real todayMinutes: Cycle.minutesOn(history, todayKey) + unsavedStandMs / 60000
    readonly property int streakDays: Cycle.streak(history, Cycle.parseDayKey(todayKey), goalMinutes)
    // The last week for the chart. Today's bar takes the live todayMinutes separately, so
    // the chart's delegates are not rebuilt every second.
    readonly property var weekDays: Cycle.lastDays(history, Cycle.parseDayKey(todayKey), 7)

    property real lastNotifiedMs: 0
    // While a switch is due and ignored, ask again this often.
    readonly property real renotifyMs: 10 * 60 * 1000

    // Theme colours are read here and only here, then handed to the views; see
    // tests/theme_audit.py for why per-delegate reads are not allowed.
    property bool paletteReady: false
    readonly property color themeTextColor: paletteReady ? Kirigami.Theme.textColor : "transparent"
    readonly property color themeDimColor: paletteReady ? Kirigami.Theme.disabledTextColor : "transparent"
    readonly property color themeAccentColor: paletteReady ? Kirigami.Theme.highlightColor : "transparent"
    readonly property color themeDueColor: paletteReady ? Kirigami.Theme.neutralTextColor : "transparent"
    readonly property color themeBackgroundColor: paletteReady ? Kirigami.Theme.backgroundColor : "transparent"
    readonly property color themeTrackColor: Qt.alpha(themeTextColor, 0.25)
    readonly property color ringColor: switchDue ? themeDueColor : themeAccentColor
    // The panel is translucent, and the accent blue measured 1.18:1 against it, so the
    // panel ring is drawn in the text colour like the other panel icons.
    readonly property color panelRingColor: switchDue ? themeDueColor : themeTextColor

    readonly property string iconName: {
        if (status === "away")
            return "system-lock-screen";
        if (status === "paused" || status === "off")
            return "media-playback-pause";
        // Installed into the icon theme by `make install`; see the Makefile.
        return cycle.position === "stand" ? "com.dv.stand-stand" : "com.dv.stand-sit";
    }

    // The posture now. Once a switch is due, the panel shows where to go instead.
    readonly property url postureIcon: Qt.resolvedUrl(cycle.position === "stand" ? "../icons/person-stand.svg" : "../icons/person-sit.svg")
    readonly property url nextArrowIcon: Qt.resolvedUrl("../icons/arrow-next.svg")
    // A switch asked for while the desk was out of reach: the user has to make it with the
    // desk's own buttons, so the count carries on in the old position until they confirm.
    property string pendingPosition: ""
    readonly property bool deskOffline: deskEnabled && !desk.reachable
    readonly property bool showNextArrow: switchDue || status === "snoozed" || pendingPosition !== ""

    function statusText() {
        switch (status) {
        case "away":
            return i18n("Away");
        case "paused":
            return i18n("Paused");
        case "off":
            return i18n("Outside working hours");
        case "due":
        case "snoozed":
            return cycle.position === "stand" ? i18n("Time to sit down") : i18n("Time to stand up");
        case "stand":
            return i18n("Standing");
        default:
            return i18n("Sitting");
        }
    }

    function countdownText() {
        if (status === "away")
            return i18n("Paused while the screen is locked");
        if (status === "paused")
            return cycle.pausedUntilMs === Cycle.UNTIL_RESUMED
                ? i18n("Until you resume")
                : i18n("Until %1", Qt.formatTime(new Date(cycle.pausedUntilMs), Locale.ShortFormat));
        if (status === "off")
            return i18n("Reminders start again at %1", formatClock(workHours.startMinutes));
        if (status === "snoozed")
            return i18n("Snoozed for %1", Cycle.formatMinutes(cycle.snoozeUntil - nowMs));
        if (cycle.dueSinceMs && dndActive)
            return i18n("Due for %1, reminder waits for Do Not Disturb to end", Cycle.formatMinutes(nowMs - cycle.dueSinceMs));
        if (cycle.dueSinceMs)
            return i18n("Due for %1", Cycle.formatMinutes(nowMs - cycle.dueSinceMs));
        return cycle.position === "stand"
            ? i18n("Sit down in %1", Cycle.formatMinutes(remainingMs))
            : i18n("Stand up in %1", Cycle.formatMinutes(remainingMs));
    }

    function formatClock(minutes) {
        return Qt.formatTime(new Date(2000, 0, 1, Math.floor(minutes / 60), minutes % 60), Locale.ShortFormat);
    }

    function todayText() {
        var stood = Cycle.formatMinutes(todayMinutes * 60000);
        if (goalMinutes <= 0)
            return i18n("Stood %1 today", stood);
        return i18n("Stood %1 of %2 today", stood, Cycle.formatMinutes(goalMinutes * 60000));
    }

    function heightText() {
        return isNaN(desk.heightCm) ? i18n("Desk height unknown") : i18n("Desk at %1 cm", Math.round(desk.heightCm));
    }

    // The user asked to be in `position`. With a desk, the desk moves and its height,
    // read back afterwards, moves the cycle. Without one, the click is the record.
    // A desk that does not answer cannot be the record, and neither can the request: the
    // switch waits for the user to say they made it.
    function goTo(position) {
        if (!deskEnabled)
            setPosition(position);
        else if (desk.reachable)
            desk.moveTo(position);
        else
            awaitManualSwitch(position);
    }

    function awaitManualSwitch(position) {
        if (position === cycle.position) {
            pendingPosition = "";
            return;
        }
        pendingPosition = position;
        if (!plasmoid.configuration.notification_enabled)
            return;
        notifications.notifyActions(position === "stand"
            ? i18n("The desk is not reachable. Raise it with its own buttons, then press Done.")
            : i18n("The desk is not reachable. Lower it with its own buttons, then press Done."), [
            { label: i18n("Done"), action: root.confirmPending },
            { label: i18n("Cancel"), action: root.cancelPending }
        ]);
    }

    function confirmPending() {
        if (pendingPosition)
            setPosition(pendingPosition);
        pendingPosition = "";
    }

    function cancelPending() {
        pendingPosition = "";
    }

    function setPosition(position) {
        pendingPosition = "";
        if (position === cycle.position)
            return;
        flushStanding();
        cycle = Cycle.moveTo(cycle, position);
        lastNotifiedMs = 0;
        saveCycle();
    }

    function snooze() {
        cycle = Cycle.snooze(cycle, Date.now(), plasmoid.configuration.snooze_minutes);
        saveCycle();
    }

    // minutes <= 0 pauses until resume().
    function pause(minutes) {
        cycle = Cycle.pause(cycle, Date.now(), minutes);
        saveCycle();
    }

    function resume() {
        cycle = Cycle.resume(cycle);
        saveCycle();
    }

    function saveCycle() {
        plasmoid.configuration.cycle_state = Cycle.serialize(cycle, Date.now());
    }

    function flushStanding() {
        if (unsavedStandMs <= 0)
            return;
        // Credited to the day it is flushed on. Flushed every minute, so at most a
        // minute of a session spanning midnight lands on the wrong day.
        history = Cycle.addStanding(history, Cycle.dayKey(new Date()), unsavedStandMs, 90);
        unsavedStandMs = 0;
        plasmoid.configuration.stand_history = JSON.stringify(history);
    }

    function tick() {
        var now = Date.now();
        var dt = now - lastTickMs;
        lastTickMs = now;
        if (Cycle.countsStanding(cycle, now, offHours) && dt > 0 && dt <= Cycle.MAX_TICK_MS)
            unsavedStandMs += dt;
        cycle = Cycle.advance(cycle, now, dt, cfg);
        nowMs = now;
        // Not while a switch is waiting for its Done: the user is already on it.
        if (switchDue && !pendingPosition && lastNotifiedMs && now - lastNotifiedMs >= renotifyMs)
            remind();
    }

    function remind() {
        lastNotifiedMs = Date.now();
        if (dndActive) {
            pendingRemind = true;
            return;
        }
        var standing = cycle.position === "stand";
        if (plasmoid.configuration.sfx_enabled && plasmoid.configuration.sfx_filepath)
            sfx.play(plasmoid.configuration.sfx_filepath, plasmoid.configuration.sound_volume / 100);
        if (!plasmoid.configuration.notification_enabled)
            return;
        var target = standing ? "sit" : "stand";
        notifications.notifyActions(standing ? i18n("Time to sit down.") : i18n("Time to stand up."), [
            { label: standing ? i18n("Sit now") : i18n("Stand now"), action: function() { root.goTo(target); } },
            { label: i18n("Snooze %1 min", plasmoid.configuration.snooze_minutes), action: root.snooze }
        ]);
    }

    onSwitchDueChanged: {
        if (!switchDue) {
            pendingRemind = false;
            return;
        }
        actOnDue();
    }

    onDndActiveChanged: {
        if (dndActive || !pendingRemind)
            return;
        pendingRemind = false;
        if (switchDue)
            actOnDue();
    }

    function actOnDue() {
        // A desk moving by itself mid-presentation is worse than a notification.
        if (dndActive) {
            pendingRemind = true;
            return;
        }
        // Counted as the reminder, so a move that fails or leaves the desk where it was
        // is followed by the usual nagging rather than a switch due forever in silence.
        if (deskEnabled && desk.reachable && plasmoid.configuration.auto_move_enabled && desk.moveTo(Cycle.opposite(cycle.position))) {
            lastNotifiedMs = Date.now();
            return;
        }
        remind();
    }

    // A desk that is off or out of range fails every poll, so a read failure notifies once
    // per run of failures, and only as a notification would: not with notifications off,
    // and not during Do Not Disturb. A failed move was asked for, so it always says so -
    // and when the switch is due, it is followed by the reminder the move stood in for.
    // A desk out of reach is shown on the panel and in the popup, not announced as an
    // error. A move the desk never got waits for the user to make it by hand and confirm.
    // What still notifies is a desk that answers but will not go: stopped short by
    // something in the way, or a command that does not exist.
    function reportDeskFailure(what, detail) {
        console.warn("Stand:", what, "failed:", detail);
        if (what === "height")
            return;
        if (!desk.reachable) {
            awaitManualSwitch(desk.target);
            return;
        }
        if (plasmoid.configuration.notification_enabled && !dndActive)
            errorNotifications.notify(i18n("Could not move the desk: %1", detail));
        if (switchDue)
            remind();
    }

    onOffHoursChanged: {
        if (!offHours) {
            cycle = Cycle.startDay(cycle);
            saveCycle();
        }
    }

    switchWidth: Kirigami.Units.gridUnit * 10
    switchHeight: Kirigami.Units.gridUnit * 10
    Plasmoid.icon: iconName
    toolTipMainText: statusText()
    toolTipSubText: countdownText() + "\n" + todayText()
        + (pendingPosition ? "\n" + (pendingPosition === "stand"
            ? i18n("Waiting for you to confirm you are standing")
            : i18n("Waiting for you to confirm you are sitting")) : "")
        + (deskOffline ? "\n" + i18n("Desk not reachable") : "")

    Component.onCompleted: {
        // A pass later, so nothing reads the theme while the shell is still attaching
        // the representations.
        Qt.callLater(function() {
            root.paletteReady = true;
        });
        var now = Date.now();
        cycle = Cycle.restore(plasmoid.configuration.cycle_state, now);
        history = Cycle.parseHistory(plasmoid.configuration.stand_history);
        nowMs = now;
        lastTickMs = now;
        if (deskEnabled)
            desk.readHeight();
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.tick()
    }

    // Flushes the standing time and the cycle, so a crash or restart loses at most a minute.
    Timer {
        interval: 60 * 1000
        running: true
        repeat: true
        onTriggered: {
            root.flushStanding();
            root.saveCycle();
        }
    }

    // GetSessionIdleTime would be the better signal, but KDE's Wayland session answers it
    // with NotSupported, so the lock is what marks the user as gone. Plasma locks after
    // its own idle timeout, so in practice this follows idleness too.
    Timer {
        interval: 15 * 1000
        running: plasmoid.configuration.away_on_lock_enabled
        repeat: true
        triggeredOnStart: true
        onTriggered: executable.exec(root.lockCmd, function(cmd, exitCode, exitStatus, stdout) {
            if (exitCode !== 0)
                return;
            var locked = /true/.test(stdout);
            if (locked && !root.cycle.awaySinceMs) {
                root.flushStanding();
                root.cycle = Cycle.leave(root.cycle, Date.now());
            } else if (!locked && root.cycle.awaySinceMs) {
                root.cycle = Cycle.returnAt(root.cycle, Date.now());
                root.lastNotifiedMs = 0;
                if (root.deskEnabled)
                    desk.readHeight();
            }
        })
    }

    Timer {
        interval: 30 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: executable.exec(root.dndCmd, function(cmd, exitCode, exitStatus, stdout) {
            // No notification server, or one without the property: nothing to wait for.
            root.dndActive = exitCode === 0 && /true/.test(stdout);
        })
    }

    onCycleChanged: {
        // Turning the lock check off mid-absence must not leave the cycle paused for good.
        if (cycle.awaySinceMs && !plasmoid.configuration.away_on_lock_enabled)
            cycle = Cycle.returnAt(cycle, Date.now());
    }

    Timer {
        interval: plasmoid.configuration.desk_poll_seconds * 1000
        running: root.deskEnabled && !root.cycle.awaySinceMs
        repeat: true
        onTriggered: desk.readHeight()
    }

    Desk {
        id: desk

        sitCmd: plasmoid.configuration.desk_sit_cmd
        standCmd: plasmoid.configuration.desk_stand_cmd
        heightCmd: plasmoid.configuration.desk_height_cmd
        sitHeightCm: plasmoid.configuration.sit_height_cm
        standHeightCm: plasmoid.configuration.stand_height_cm
        // The height is the truth, so it settles any switch still waiting for a Done.
        onHeightRead: cm => root.setPosition(Cycle.positionFromHeight(cm, sitHeightCm, standHeightCm))
        onFailed: (what, detail) => root.reportDeskFailure(what, detail)
    }

    ExecUtil {
        id: executable
    }

    Sfx {
        id: sfx
    }

    NotificationManager {
        id: notifications
    }

    // Its own notification, so an error does not replace a reminder and take its
    // Stand now / Snooze buttons with it.
    NotificationManager {
        id: errorNotifications
    }

    compactRepresentation: MouseArea {
        id: compact

        // Even, so the ring's centre lands on a pixel boundary and both sides are as sharp.
        readonly property real size: Math.floor(Math.min(width, height) / 2) * 2

        clip: true
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        // Middle click switches to the other position without opening the popup: the desk
        // moves, or without one the switch is recorded.
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) {
                // With a switch waiting for its Done, a second middle click is the Done.
                if (root.pendingPosition)
                    root.confirmPending();
                else if (!desk.moving)
                    root.goTo(Cycle.opposite(root.cycle.position));
                return;
            }
            root.expanded = !root.expanded;
        }

        ProgressCircle {
            anchors.centerIn: parent
            size: compact.size
            // Whole pixels, so the ring stays sharp at panel sizes (~22px gives 2px).
            lineWidth: Math.max(2, Math.round(size / 10))
            arcBegin: 0
            arcEnd: 360 * Cycle.progress(root.cycle, root.cfg)
            showBackground: true
            colorCircle: root.panelRingColor
            colorBackground: root.themeTrackColor
            // The tool reports nothing until the desk stops, so the ring says "moving"
            // rather than how far.
            indeterminate: desk.moving
            visible: !root.idle
        }

        Kirigami.Icon {
            anchors.centerIn: parent
            // Leaves a gap inside the ring, so the figure does not touch the arc. Even, like
            // the ring, so centring lands on whole pixels instead of blurring by half of one.
            width: Math.round(compact.size * 0.3) * 2
            height: width
            // A switch due swaps the figure for the way to go, at full size: a corner badge on
            // a 22px icon was a few pixels of arrow, and covered half the figure besides.
            source: root.showNextArrow ? root.nextArrowIcon : root.postureIcon
            rotation: root.showNextArrow && root.cycle.position === "stand" ? 180 : 0
            isMask: true
            color: root.themeTextColor
            opacity: root.idle ? 0.5 : 1
            active: compact.containsMouse
        }

        // The desk is out of reach: Sit and Stand only record, and switches wait for a Done.
        // Breeze's unplugged plug, the one disconnect icon that still reads at this size (the
        // Bluetooth ones are drawn faded on purpose), on a disc of the background colour so it
        // does not run into the ring. Bottom right, nudged out where the panel leaves room.
        Rectangle {
            readonly property real spareX: (compact.width - compact.size) / 2
            readonly property real spareY: (compact.height - compact.size) / 2

            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: spareX - Math.min(3, spareX)
            anchors.bottomMargin: spareY - Math.min(3, spareY)
            width: offlineIcon.width + 2
            height: width
            radius: width / 2
            color: root.themeBackgroundColor
            visible: root.deskOffline

            Kirigami.Icon {
                id: offlineIcon

                anchors.centerIn: parent
                width: Math.max(10, Math.round(compact.size * 0.27) * 2)
                height: width
                source: "network-disconnect-symbolic"
            }
        }
    }

    fullRepresentation: Item {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 16
        Layout.preferredWidth: Kirigami.Units.gridUnit * 18
        // As tall as the content. Given more - a resized popup, a tiling window manager
        // around plasmawindowed - the rows stay together at the top instead of spreading.
        Layout.minimumHeight: content.implicitHeight + 2 * content.anchors.margins
        Layout.preferredHeight: content.implicitHeight + 2 * content.anchors.margins
        // Also the most: Plasma reopens a popup at the size it last had, and one saved while
        // the rows were spread out would come back with empty space below them.
        Layout.maximumHeight: content.implicitHeight + 2 * content.anchors.margins

        ColumnLayout {
            id: content

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            // Room for the buttons' focus rings, which the popup edge would otherwise clip.
            anchors.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.largeSpacing

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing

                ProgressCircle {
                    size: Kirigami.Units.gridUnit * 4
                    lineWidth: Kirigami.Units.smallSpacing * 1.5
                    arcBegin: 0
                    arcEnd: 360 * Cycle.progress(root.cycle, root.cfg)
                    showBackground: true
                    colorCircle: root.ringColor
                    colorBackground: root.themeTrackColor
                    indeterminate: desk.moving

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: parent.width * 0.5
                        height: width
                        source: root.postureIcon
                        isMask: true
                        color: root.themeTextColor
                        opacity: root.idle ? 0.5 : 1
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Heading {
                        Layout.fillWidth: true
                        level: 3
                        text: root.statusText()
                        wrapMode: Text.Wrap
                    }

                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: root.countdownText()
                        color: root.themeDimColor
                        wrapMode: Text.Wrap
                    }
                }
            }

            Kirigami.InlineMessage {
                Layout.fillWidth: true
                visible: root.pendingPosition !== ""
                type: Kirigami.MessageType.Information
                text: root.pendingPosition === "stand"
                    ? i18n("The desk is not reachable. Raise it with its own buttons, then confirm.")
                    : i18n("The desk is not reachable. Lower it with its own buttons, then confirm.")
                actions: [
                    Kirigami.Action {
                        text: i18n("Done")
                        icon.name: "dialog-ok"
                        onTriggered: root.confirmPending()
                    },
                    Kirigami.Action {
                        text: i18n("Cancel")
                        icon.name: "dialog-cancel"
                        onTriggered: root.cancelPending()
                    }
                ]
            }

            RowLayout {
                Layout.fillWidth: true

                // Offline, these say where the user is rather than ask the desk to go there,
                // so a click on one is its own confirmation.
                PlasmaComponents.Button {
                    Layout.fillWidth: true
                    icon.source: Qt.resolvedUrl("../icons/person-sit.svg")
                    icon.color: root.themeTextColor
                    text: root.deskOffline ? i18n("I'm sitting") : i18n("Sit")
                    highlighted: root.cycle.position === "sit"
                    enabled: !desk.moving
                    onClicked: root.deskOffline ? root.setPosition("sit") : root.goTo("sit")
                }

                PlasmaComponents.Button {
                    Layout.fillWidth: true
                    icon.source: Qt.resolvedUrl("../icons/person-stand.svg")
                    icon.color: root.themeTextColor
                    text: root.deskOffline ? i18n("I'm standing") : i18n("Stand")
                    highlighted: root.cycle.position === "stand"
                    enabled: !desk.moving
                    onClicked: root.deskOffline ? root.setPosition("stand") : root.goTo("stand")
                }
            }

            RowLayout {
                Layout.fillWidth: true

                PlasmaComponents.Button {
                    Layout.fillWidth: true
                    visible: root.switchDue
                    icon.name: "chronometer-pause"
                    text: i18n("Snooze %1 min", plasmoid.configuration.snooze_minutes)
                    onClicked: root.snooze()
                }

                PlasmaComponents.Button {
                    Layout.fillWidth: true
                    visible: root.status === "paused"
                    icon.name: "media-playback-start"
                    text: i18n("Resume")
                    onClicked: root.resume()
                }

                PlasmaComponents.Button {
                    id: pauseButton

                    Layout.fillWidth: true
                    visible: root.status !== "paused"
                    icon.name: "media-playback-pause"
                    text: i18n("Pause…")
                    onClicked: pauseMenu.open()

                    PlasmaComponents.Menu {
                        id: pauseMenu

                        y: pauseButton.height

                        PlasmaComponents.MenuItem {
                            text: i18n("For 30 minutes")
                            onTriggered: root.pause(30)
                        }

                        PlasmaComponents.MenuItem {
                            text: i18n("For 1 hour")
                            onTriggered: root.pause(60)
                        }

                        PlasmaComponents.MenuItem {
                            text: i18n("For 2 hours")
                            onTriggered: root.pause(120)
                        }

                        PlasmaComponents.MenuItem {
                            text: i18n("Until I resume")
                            onTriggered: root.pause(0)
                        }
                    }
                }
            }

            Kirigami.Heading {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                level: 5
                text: i18n("Today")
                color: root.themeDimColor
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: root.todayText()
                wrapMode: Text.Wrap
            }

            PlasmaComponents.ProgressBar {
                Layout.fillWidth: true
                visible: root.goalMinutes > 0
                from: 0
                to: root.goalMinutes
                value: Math.min(root.todayMinutes, root.goalMinutes)
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                visible: root.goalMinutes > 0
                text: i18np("Goal met %1 day in a row", "Goal met %1 days in a row", root.streakDays)
                color: root.themeDimColor
            }

            WeekChart {
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
                Layout.topMargin: Kirigami.Units.smallSpacing
                days: root.weekDays
                todayMinutes: root.todayMinutes
                goalMinutes: root.goalMinutes
                barColor: root.themeAccentColor
                trackColor: root.themeTrackColor
                lineColor: root.themeDimColor
                labelColor: root.themeDimColor
            }

            Kirigami.Heading {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                visible: root.deskEnabled
                level: 5
                text: i18n("Desk")
                color: root.themeDimColor
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.deskEnabled

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: !desk.moving && !desk.reachable ? i18n("Desk not reachable. Switches wait for you to confirm them.")
                        : !desk.moving ? root.heightText()
                        : desk.attempt > 1 ? i18n("Desk stopped short, trying again (%1 of %2)…", desk.attempt, desk.maxAttempts)
                        : isNaN(desk.startCm) ? i18n("Desk moving…")
                        : i18n("Moving %1 → %2 cm…", Math.round(desk.startCm), Math.round(desk.targetCm))
                    wrapMode: Text.Wrap
                }

                PlasmaComponents.Button {
                    visible: !desk.reachable && !desk.moving
                    enabled: !desk.reading
                    icon.name: "view-refresh"
                    text: i18n("Try again")
                    onClicked: desk.readHeight()
                }

                PlasmaComponents.Button {
                    visible: desk.moving && desk.attempt > 1
                    icon.name: "process-stop"
                    text: i18n("Stop retrying")
                    onClicked: desk.cancel()
                }
            }
        }
    }
}
