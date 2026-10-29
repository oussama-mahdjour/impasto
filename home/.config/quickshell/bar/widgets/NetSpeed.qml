// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   N E T   S P E E D                                                      │
// │   download and upload speed on the bar · a click opens the card          │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

// The network's speed on the bar, down and up side by side, from the stats
// sampler (every 3 s). A click opens the network card (NetSpeedModule), as the
// battery's ring opens the battery's.

import QtQuick
import Quickshell

import "../../theme"
import "../../services"
import "../../components"

Item {
    id: root

    property bool chromeless: false

    implicitWidth: rates.implicitWidth
    implicitHeight: Theme.capsuleHeight
    width: implicitWidth
    height: implicitHeight

    Row {
        id: rates

        height: parent.height
        // Room either side in every style, so the hover highlight has a
        // margin round the text as the chips' do.
        leftPadding: 12
        rightPadding: 12
        spacing: 10

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: `󰇚 ${StatsService.rate(StatsService.networkDown)}`
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            font.features: { "tnum": 1 }
            color: Theme.text
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: `󰕒 ${StatsService.rate(StatsService.networkUp)}`
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            font.features: { "tnum": 1 }
            color: Theme.textMuted
        }
    }

    // The bar chips' hover highlight, and their click.
    Rectangle {
        anchors.centerIn: parent
        z: -1
        width: parent.width - 4
        height: Theme.capsuleHeight - 8
        radius: height / 2
        color: Theme.surfaceHoverIn(QsWindow.window)
        opacity: hover.hovered || ModuleService.openId === "netspeed" ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }
    }

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: ModuleService.activate("netspeed")
    }
}
