import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: "General"
        icon: "preferences-system-time"
        source: "configGeneral.qml"
    }

    ConfigCategory {
        name: "Desk"
        icon: "network-bluetooth"
        source: "configDesk.qml"
    }
}
