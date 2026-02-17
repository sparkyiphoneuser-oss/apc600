import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.components 2.0 as PlasmaComponents
import org.kde.plasma.extras 2.0 as PlasmaExtras

Item {
    id: root

    property int lastRefreshAt: 0
    property var upsModel: ({})
    property bool isOnline: false

    Layout.fillWidth: true
    Layout.fillHeight: true

    Plasmoid.toolTipTextFormat: Text.RichText

    Component.onCompleted: {
        refreshUPS()
        plasmoid.setAction("refresh", i18n("Refresh"), "view-refresh")
    }

    Timer {
        id: refreshTimer
        interval: 10000 // 30 секунд
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: refreshUPS()
    }

    Plasmoid.compactRepresentation: Item {
        PlasmaCore.IconItem {
            anchors.fill: parent
            source: isOnline ? "battery-charging" : "battery-missing"
        }

        PlasmaComponents.Label {
            anchors {
                right: parent.right
                bottom: parent.bottom
            }
            text: upsModel.bcharge ? Math.round(upsModel.bcharge) + "%" : ""
            font.pointSize: 8
            color: PlasmaCore.Theme.textColor
            visible: isOnline && upsModel.bcharge
        }

        MouseArea {
            anchors.fill: parent
            onClicked: plasmoid.expanded = !plasmoid.expanded
        }
    }

    Plasmoid.fullRepresentation: Item {
        Layout.preferredWidth: 300
        Layout.preferredHeight: 350

        ColumnLayout {
            anchors {
                fill: parent
                margins: 10
            }
            spacing: 8

            // Заголовок
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                PlasmaCore.IconItem {
                    source: "battery"
                    width: 32
                    height: 32
                }

                PlasmaExtras.Heading {
                    text: "APC UPS Монитор"
                    level: 2
                }

                Item { Layout.fillWidth: true }

                PlasmaComponents.ToolButton {
                    iconSource: "view-refresh"
                    onClicked: refreshUPS()
                }
            }

            // Статус
            Rectangle {
                Layout.fillWidth: true
                height: 40
                radius: 5
                color: isOnline ? "#4caf50" : "#f44336"

                PlasmaComponents.Label {
                    anchors.centerIn: parent
                    text: isOnline ? "✅ От Сети" : "❌ Нет Сети"
                    font.bold: true
                    color: "white"
                }
            }

            // Информация
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 10
                rowSpacing: 8

                // Статус
                PlasmaComponents.Label { text: "<b>Статус:</b>" }
                PlasmaComponents.Label { text: upsModel.status || "N/A" }

                // Напряжение сети
                PlasmaComponents.Label { text: "<b>Напряжение:</b>" }
                PlasmaComponents.Label { text: upsModel.linev ? upsModel.linev + " В" : "—" }

                // Нагрузка
                PlasmaComponents.Label { text: "<b>Нагрузка:</b>" }
                PlasmaComponents.Label { text: upsModel.loadpct ? upsModel.loadpct + "%" : "—" }

                // Заряд батареи
                PlasmaComponents.Label { text: "<b>Заряд:</b>" }
                RowLayout {
                    PlasmaComponents.Label { text: upsModel.bcharge ? upsModel.bcharge + "%" : "—" }
                    PlasmaComponents.ProgressBar {
                        Layout.preferredWidth: 100
                        value: upsModel.bcharge ? upsModel.bcharge / 100 : 0
                    }
                }

                // Время работы
                PlasmaComponents.Label { text: "<b>Время:</b>" }
                PlasmaComponents.Label { text: upsModel.timeleft ? upsModel.timeleft + " мин" : "—" }

                // Температура
                PlasmaComponents.Label { text: "<b>Температура:</b>" }
                PlasmaComponents.Label { text: upsModel.itemp ? upsModel.itemp + "°C" : "—" }

                // Модель
                PlasmaComponents.Label { text: "<b>Модель:</b>" }
                PlasmaComponents.Label {
                    text: upsModel.model || "—"
                    elide: Text.ElideRight
                    Layout.maximumWidth: 150
                }

                // Серийный номер
                PlasmaComponents.Label { text: "<b>S/N:</b>" }
                PlasmaComponents.Label { text: upsModel.serialno || "—" }
            }

            // Разделитель (используем Rectangle вместо Separator)
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: PlasmaCore.Theme.textColor
                opacity: 0.2
                Layout.topMargin: 5
                Layout.bottomMargin: 5
            }

            // Информация о батарее
            RowLayout {
                Layout.fillWidth: true

                PlasmaComponents.Label { text: "<b>Батарея:</b>" }
                PlasmaComponents.Label {
                    text: {
                        if (!upsModel.battdate) return "—"
                        return "Произведена: " + upsModel.battdate
                    }
                }
            }


        }
    }

    PlasmaCore.DataSource {
        id: executableDS
        engine: "executable"
        connectedSources: []

        onNewData: {
            var exitCode = data["exit code"]
            var stdout = data["stdout"]
            var stderr = data["stderr"]

            if (exitCode === 0 && stdout) {
                parseUPSData(stdout)
            } else {
                console.log("Error running apcaccess:", stderr)
                isOnline = false
            }
            disconnectSource(sourceName)
        }
    }

    function refreshUPS() {
        executableDS.connectSource("apcaccess status")
        lastRefreshAt = Date.now()
    }

    function parseUPSData(output) {
        var lines = output.split("\n")
        var data = {}

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (line.includes(":")) {
                var parts = line.split(":")
                var key = parts[0].trim()
                var value = parts.slice(1).join(":").trim()

                switch(key) {
                    case "STATUS":
                        var statusParts = value.split(" ")
                        data.status = statusParts[0]
                        isOnline = (data.status === "ONLINE")
                        break
                    case "LINEV":
                        var match = value.match(/(\d+\.?\d*)/)
                        data.linev = match ? parseFloat(match[1]) : null
                        break
                    case "LOADPCT":
                        var match = value.match(/(\d+\.?\d*)/)
                        data.loadpct = match ? parseFloat(match[1]) : null
                        break
                    case "BCHARGE":
                        var match = value.match(/(\d+\.?\d*)/)
                        data.bcharge = match ? parseFloat(match[1]) : null
                        break
                    case "TIMELEFT":
                        var match = value.match(/(\d+\.?\d*)/)
                        data.timeleft = match ? parseFloat(match[1]) : null
                        break
                    case "MODEL":
                        data.model = value
                        break
                    case "SERIALNO":
                        data.serialno = value
                        break
                    case "BATTDATE":
                        data.battdate = value
                        break
                    case "ITEMP":
                        var match = value.match(/(\d+\.?\d*)/)
                        data.itemp = match ? parseFloat(match[1]) : null
                        break
                }
            }
        }

        upsModel = data
    }

    function action_refresh() {
        refreshUPS()
    }
}
