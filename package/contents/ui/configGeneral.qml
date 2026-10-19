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
    }
}
