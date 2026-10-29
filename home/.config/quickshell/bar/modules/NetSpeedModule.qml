// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   N E T   S P E E D   M O D U L E                                        │
// │   the connection in detail · speeds, name, addresses, totals, graph      │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../../theme"
import "../../services"
import "../../components"

// The network in detail, opened from the speed on the bar. The heading is the
// speed now, down and up, with the Wi-Fi signal beside it. Under it the
// network's name, which wraps so a long one keeps its room; a line for each
// interface that has an address; the totals since boot; and the last minutes
// drawn (`StatsService`). The card's height is declared in
// `ModuleService.openSize`, so a row added here is counted there.
Item {
    id: root

    property bool compact: false

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    Component.onCompleted: {
        SystemMonitorService.subscribe()
        SystemMonitorService.refreshAddresses()
    }
    Component.onDestruction: SystemMonitorService.release()

    ModuleCard {
        id: card

        anchors.fill: parent
        title: `↓ ${StatsService.rate(StatsService.networkDown)}   ↑ ${StatsService.rate(StatsService.networkUp)}`
        figure: NetworkService.wifiConnected ? `${Math.round(NetworkService.strength * 100)}%` : ""

        mark: Text {
            anchors.centerIn: parent
            text: NetworkService.icon
            font.family: Theme.fontMono
            font.pixelSize: 20
            color: Theme.indicator
        }

        Text {
            Layout.fillWidth: true
            text: NetworkService.connectionName
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeRegular
            font.weight: Font.DemiBold
            color: Theme.text
        }

        Repeater {
            model: SystemMonitorService.addresses

            CardFact {
                required property var modelData

                name: modelData.name
                value: modelData.address
            }
        }

        CardFact {
            visible: SystemMonitorService.addresses.length === 0
            name: "Address"
            value: "—"
        }

        CardFact {
            name: "Since boot"
            value: `↓ ${SystemMonitorService.formatBytes(SystemMonitorService.ethRxTotal + SystemMonitorService.wifiRxTotal)}  ↑ ${SystemMonitorService.formatBytes(SystemMonitorService.ethTxTotal + SystemMonitorService.wifiTxTotal)}`
        }

        // Down in the accent, up muted, over the sampler's last minutes, on
        // one ceiling so the two compare.
        Item {
            id: graph

            readonly property real ceiling: Math.max(1024,
                ...StatsService.downHistory, ...StatsService.upHistory)

            Layout.fillWidth: true
            Layout.preferredHeight: 64
            Layout.topMargin: 4

            Sparkline {
                anchors.fill: parent
                values: StatsService.downHistory
                maximum: graph.ceiling
            }

            Sparkline {
                anchors.fill: parent
                values: StatsService.upHistory
                maximum: graph.ceiling
                stroke: Theme.textMuted
                showDot: false
            }
        }
    }
}
