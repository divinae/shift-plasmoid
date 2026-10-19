import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

// Standing minutes per day, oldest on the left, with the goal as a line across.
// Colours come in from main.qml's palette block; see tests/theme_audit.py for why the
// bars must not read the theme themselves.
Item {
    id: chart

    // [{ key, date, minutes }] from Cycle.lastDays, today last.
    property var days: []
    property real goalMinutes: 0
    property color barColor
    property color trackColor
    property color lineColor
    property color labelColor

    readonly property real barsHeight: Kirigami.Units.gridUnit * 3
    // The goal sits below the top, so a day that met it still has room to show by how much.
    readonly property real scaleMinutes: Math.max(goalMinutes * 1.25, 1, ...days.map(d => d.minutes))

    implicitHeight: barsHeight + Kirigami.Units.gridUnit * 1.5

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Kirigami.Units.smallSpacing

        Repeater {
            model: chart.days

            delegate: ColumnLayout {
                id: day

                required property var modelData
                required property int index
                readonly property bool met: chart.goalMinutes > 0 && modelData.minutes >= chart.goalMinutes
                readonly property bool isToday: index === chart.days.length - 1

                // Equal shares: without a common preferred width the columns follow their
                // labels, and a wide day name gets a wider bar.
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                spacing: Kirigami.Units.smallSpacing / 2

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: chart.barsHeight

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.max(4, parent.width * 0.6)
                        // A sliver for an empty day, so the day still reads as part of the row.
                        height: Math.max(2, Math.round(chart.barsHeight * day.modelData.minutes / chart.scaleMinutes))
                        radius: Math.min(3, width / 4)
                        color: day.modelData.minutes <= 0 ? chart.trackColor
                            : day.met ? chart.barColor : Qt.alpha(chart.barColor, 0.45)
                    }

                    MouseArea {
                        id: hover

                        anchors.fill: parent
                        hoverEnabled: true
                    }

                    PlasmaComponents.ToolTip {
                        visible: hover.containsMouse
                        text: Qt.formatDate(day.modelData.date, "dddd") + ": " + Math.round(day.modelData.minutes) + " min"
                    }
                }

                PlasmaComponents.Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.locale().dayName(day.modelData.date.getDay(), Locale.NarrowFormat)
                    color: chart.labelColor
                    font.bold: day.isToday
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                }
            }
        }
    }

    // Goal line across all the bars.
    Rectangle {
        visible: chart.goalMinutes > 0
        x: 0
        width: chart.width
        height: 1
        y: Math.round(chart.barsHeight - chart.barsHeight * chart.goalMinutes / chart.scaleMinutes)
        color: chart.lineColor
    }
}
