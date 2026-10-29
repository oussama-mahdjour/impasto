// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   N E T   S P E E D   M O D U L E                                        │
// │   the connection in detail · rates, signal, address, totals              │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

// The network in detail, opened from the speed on the bar, as the battery
// opens its: what carries the traffic, its signal
// and address, the rates now with the last minutes drawn, and the totals
// since boot (SystemMonitorService). The button goes to the Wi-Fi page.

import QtQuick
import QtQuick.Layouts
import Quickshell.Io

import "../../theme"
import "../../services"
import "../../components"

Item {
    id: root

    property bool compact: false

    // `interface address/prefix` per line, read on open.
    property var addresses: []

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    Component.onCompleted: {
        SystemMonitorService.subscribe()
        addressReader.running = true
    }
    Component.onDestruction: SystemMonitorService.release()

    Process {
        id: addressReader

        command: ["ip", "-4", "-o", "addr", "show", "scope", "global"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.addresses = text.trim().split("\n").filter(line => line !== "").map(line => {
                    const fields = line.trim().split(/\s+/)
                    return `${fields[1]}  ${fields[3]}`
                }).filter(line => !line.startsWith("docker") && !line.startsWith("br-") && !line.startsWith("veth"))
            }
        }
    }

    ModuleCard {
        id: card

        anchors.fill: parent
        title: NetworkService.connectionName
        subtitle: NetworkService.stateLine
        figure: `↓ ${StatsService.rate(StatsService.networkDown)}`

        mark: Text {
            anchors.centerIn: parent
            text: NetworkService.icon
            font.family: Theme.fontMono
            font.pixelSize: 20
            color: Theme.indicator
        }

        CardFact {
            name: "Up"
            value: StatsService.rate(StatsService.networkUp)
        }

        CardFact {
            visible: NetworkService.wifiConnected
            name: "Signal"
            value: `${Math.round(NetworkService.strength * 100)} %`
        }

        CardFact {
            name: "Address"
            value: root.addresses.length > 0 ? root.addresses.join(" · ") : "—"
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

        PillButton {
            Layout.topMargin: 4
            Layout.alignment: Qt.AlignHCenter
            text: "Wi-Fi, Bluetooth and audio"
            onClicked: ModuleService.requestPanel("wifi")
        }
    }
}
