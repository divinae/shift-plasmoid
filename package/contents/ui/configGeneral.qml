import QtQuick
import QtQuick.Layouts
import org.kde.kcmutils as KCMUtils
import org.kde.kirigamiaddons.formcard as FormCard

KCMUtils.SimpleKCM {
    id: root

    property alias cfg_sit_minutes: sit_minutes.value
    property alias cfg_stand_minutes: stand_minutes.value
    property alias cfg_daily_goal_minutes: daily_goal_minutes.value
    property alias cfg_snooze_minutes: snooze_minutes.value
    property alias cfg_notification_enabled: notification_enabled.checked
    property alias cfg_sfx_enabled: sfx_enabled.checked
    property alias cfg_sfx_filepath: sfx_filepath.path
    property alias cfg_sound_volume: sound_volume.value
    property alias cfg_away_on_lock_enabled: away_on_lock_enabled.checked
    property alias cfg_work_hours_enabled: work_hours_enabled.checked
    property alias cfg_work_start_minutes: work_start_minutes.value
    property alias cfg_work_end_minutes: work_end_minutes.value
    property alias cfg_work_weekdays_only: work_weekdays_only.checked

    function clockText(minutes) {
        return Qt.formatTime(new Date(2000, 0, 1, Math.floor(minutes / 60), minutes % 60), Locale.ShortFormat);
    }

    // The inverse of clockText, including a 12-hour locale's AM/PM marker: without it,
    // "5:00 PM" would come back as five in the morning.
    function clockValue(text) {
        var match = /(\d{1,2})\D*(\d{2})?/.exec(text);
        if (!match)
            return 0;
        var h = parseInt(match[1], 10);
        var lower = ("" + text).toLowerCase();
        var pm = Qt.locale().pmText.toLowerCase();
        var am = Qt.locale().amText.toLowerCase();
        if (pm && lower.indexOf(pm) >= 0 && h < 12)
            h += 12;
        else if (am && lower.indexOf(am) >= 0 && h === 12)
            h = 0;
        return Math.min(1439, h * 60 + parseInt(match[2] || "0", 10));
    }

    ColumnLayout {
        spacing: 0

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }

        FormCard.FormHeader {
            title: i18n("Cycle")
        }

        FormCard.FormCard {
            FormCard.FormSpinBoxDelegate {
                id: sit_minutes

                label: i18n("Sit for (minutes)")
                from: 1
                to: 600
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormSpinBoxDelegate {
                id: stand_minutes

                label: i18n("Stand for (minutes)")
                from: 1
                to: 600
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormSpinBoxDelegate {
                id: snooze_minutes

                label: i18n("Snooze for (minutes)")
                from: 1
                to: 120
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormSpinBoxDelegate {
                id: daily_goal_minutes

                label: i18n("Daily standing goal (minutes)")
                description: i18n("0 turns the goal and the streak off.")
                from: 0
                to: 1440
            }
        }

        FormCard.FormHeader {
            title: i18n("Reminders")
        }

        FormCard.FormCard {
            FormCard.FormSwitchDelegate {
                id: notification_enabled

                text: i18n("Show a notification when it is time to switch")
                description: i18n("Repeated every 10 minutes until you switch or snooze.")
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormSwitchDelegate {
                id: sfx_enabled

                text: i18n("Play a sound")
            }

            FormCard.FormDelegateSeparator {}

            FormPathDelegate {
                id: sfx_filepath

                label: i18n("Sound")
                enabled: sfx_enabled.checked
                currentFolder: "file:///usr/share/sounds"
                nameFilters: [i18n("Sound files (*.oga *.ogg *.wav *.mp3 *.flac)"), i18n("All files (*)")]
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormSpinBoxDelegate {
                id: sound_volume

                label: i18n("Volume (%)")
                enabled: sfx_enabled.checked
                from: 0
                to: 100
            }
        }

        FormCard.FormHeader {
            title: i18n("Away")
        }

        FormCard.FormCard {
            FormCard.FormSwitchDelegate {
                id: away_on_lock_enabled

                text: i18n("Pause while the screen is locked")
                description: i18n("Away for 5 minutes or more starts the cycle over: you have moved.")
            }
        }

        FormCard.FormHeader {
            title: i18n("Working hours")
        }

        FormCard.FormCard {
            FormCard.FormSwitchDelegate {
                id: work_hours_enabled

                text: i18n("Remind only during working hours")
                description: i18n("Outside them the cycle stops and standing time is not counted. Each working day starts with a fresh cycle.")
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormSpinBoxDelegate {
                id: work_start_minutes

                label: i18n("From")
                enabled: work_hours_enabled.checked
                from: 0
                to: 1425
                stepSize: 15
                textFromValue: (value, locale) => root.clockText(value)
                valueFromText: (text, locale) => root.clockValue(text)
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormSpinBoxDelegate {
                id: work_end_minutes

                label: i18n("To")
                enabled: work_hours_enabled.checked
                from: 0
                to: 1425
                stepSize: 15
                textFromValue: (value, locale) => root.clockText(value)
                valueFromText: (text, locale) => root.clockValue(text)
            }

            FormCard.FormDelegateSeparator {}

            FormCard.FormSwitchDelegate {
                id: work_weekdays_only

                text: i18n("Monday to Friday only")
                enabled: work_hours_enabled.checked
            }
        }
    }
}
