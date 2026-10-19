import "./lib"
import "./lib/desk.js" as DeskLogic
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCMUtils
import org.kde.kirigamiaddons.formcard as FormCard

KCMUtils.SimpleKCM {
    id: root

    property alias cfg_desk_enabled: desk_enabled.checked
    property alias cfg_desk_sit_cmd: desk_sit_cmd.text
    property alias cfg_desk_stand_cmd: desk_stand_cmd.text
    property alias cfg_desk_height_cmd: desk_height_cmd.text
    property alias cfg_desk_save_cmd: desk_save_cmd.text
    property alias cfg_sit_height_cm: sit_height_cm.value
    property alias cfg_stand_height_cm: stand_height_cm.value
    property alias cfg_desk_poll_seconds: desk_poll_seconds.value
    property alias cfg_auto_move_enabled: auto_move_enabled.checked

    property string testResult: ""
    property string sitSaveResult: ""
    property string standSaveResult: ""

    function setSaveResult(position, text) {
        if (position === "stand")
            standSaveResult = text;
        else
            sitSaveResult = text;
    }

    // Takes the desk's height as the preset, and stores it in the desk tool too, so the
    // tool's sit/stand commands and the widget agree on where the desk should end up.
    function useCurrentHeight(position) {
        setSaveResult(position, i18n("Reading the height…"));
        exec.exec(DeskLogic.wrap(desk_height_cmd.text, 20), function(cmd, exitCode, exitStatus, stdout, stderr) {
            var cm = DeskLogic.parseHeightCm(stdout);
            if (exitCode !== 0 || isNaN(cm)) {
                root.setSaveResult(position, i18n("Could not read the height (exit code %1).", exitCode));
                return;
            }
            (position === "stand" ? stand_height_cm : sit_height_cm).value = Math.round(cm);
            var shown = Math.round(cm * 10) / 10;
            if (!desk_save_cmd.text.trim()) {
                root.setSaveResult(position, i18n("Set to %1 cm. Apply to keep it.", shown));
                return;
            }
            exec.exec(DeskLogic.wrap(DeskLogic.fillTemplate(desk_save_cmd.text, cm, position), 20), function(cmd2, saveExit, saveStatus, saveOut, saveErr) {
                root.setSaveResult(position, saveExit === 0
                    ? i18n("Set to %1 cm and saved in the desk tool. Apply to keep it here too.", shown)
                    : i18n("Set to %1 cm, but saving it in the desk tool failed: %2", shown, (("" + saveErr).trim() || ("" + saveOut).trim() || saveExit)));
            });
        });
    }

    // Runs the height command as typed, before it is applied, so a wrong command shows up
    // here rather than as a failure notification later.
    function testConnection() {
        testResult = i18n("Connecting…");
        exec.exec(DeskLogic.wrap(desk_height_cmd.text, 20), function(cmd, exitCode, exitStatus, stdout, stderr) {
            var cm = DeskLogic.parseHeightCm(stdout);
            if (exitCode === 0 && !isNaN(cm))
                root.testResult = i18n("The desk is at %1 cm.", Math.round(cm * 10) / 10);
            else if (exitCode === 124)
                root.testResult = i18n("The desk did not answer in 20 seconds.");
            else if (exitCode === 127)
                root.testResult = i18n("Command not found.");
            else
                root.testResult = i18n("No height in the output (exit code %1): %2", exitCode, (("" + stderr).trim() || ("" + stdout).trim()));
        });
    }

    ExecUtil {
        id: exec
    }

    ColumnLayout {
        spacing: 0

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }

        FormCard.FormCard {
            Layout.topMargin: Kirigami.Units.largeSpacing

            FormCard.FormSwitchDelegate {
                id: desk_enabled

                text: i18n("Control a motorized desk")
                description: i18n("Without this, the Sit and Stand buttons only record where you are.")
            }
        }

        FormCard.FormHeader {
            title: i18n("Commands")
        }

        FormCard.FormCard {
            enabled: desk_enabled.checked

            FormCard.FormTextFieldDelegate {
                id: desk_sit_cmd

                label: i18n("Sit")
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormTextFieldDelegate {
                id: desk_stand_cmd

                label: i18n("Stand")
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormTextFieldDelegate {
                id: desk_height_cmd

                label: i18n("Read height")
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormTextFieldDelegate {
                id: desk_save_cmd

                label: i18n("Save height as preset")
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormButtonDelegate {
                text: i18n("Test connection")
                description: root.testResult
                icon.name: "network-bluetooth"
                onClicked: root.testConnection()
            }
        }

        FormCard.FormSectionText {
            text: i18n("Each command runs with sh. {cm}, {mm} and {m} are replaced with the preset height, so a tool that moves to a height can use the presets below, for example \"linak-controller --move-to {mm}\". {position} is replaced with sit or stand. The defaults use idasen, which keeps its own sit and stand heights; \"Use current height\" below saves them there too.")
        }

        FormCard.FormHeader {
            title: i18n("Heights")
        }

        FormCard.FormCard {
            enabled: desk_enabled.checked

            FormCard.FormSpinBoxDelegate {
                id: sit_height_cm

                label: i18n("Sitting height (cm)")
                from: 40
                to: 160
            }

            FormCard.FormButtonDelegate {
                text: i18n("Use current height for sitting")
                description: root.sitSaveResult
                icon.name: "document-save"
                onClicked: root.useCurrentHeight("sit")
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormSpinBoxDelegate {
                id: stand_height_cm

                label: i18n("Standing height (cm)")
                from: 40
                to: 160
            }

            FormCard.FormButtonDelegate {
                text: i18n("Use current height for standing")
                description: root.standSaveResult
                icon.name: "document-save"
                onClicked: root.useCurrentHeight("stand")
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormSpinBoxDelegate {
                id: desk_poll_seconds

                label: i18n("Read the height every (seconds)")
                description: i18n("Catches the desk's own buttons, so standing time stays right.")
                from: 10
                to: 3600
            }
        }

        FormCard.FormSectionText {
            text: i18n("Move the desk to the height you want, then use the button: the widget and the desk tool then agree on it. A height typed in by hand has to match the desk tool's own preset too. Above the midpoint of the two heights counts as standing.")
        }

        FormCard.FormHeader {
            title: i18n("Moving on its own")
        }

        FormCard.FormCard {
            enabled: desk_enabled.checked

            FormCard.FormSwitchDelegate {
                id: auto_move_enabled

                text: i18n("Move the desk when it is time to switch")
                description: i18n("Instead of a reminder. Check that nothing can be caught by the desk before turning this on.")
            }
        }
    }
}
