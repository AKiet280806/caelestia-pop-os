pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.services

StyledRect {
    id: root
    required property var bar
    required property var popouts
    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: layout.implicitHeight + 12
    radius: Tokens.rounding.large
    color: mouse.containsMouse || (popouts.hasCurrent && popouts.currentName === "codexusage")
        ? Colours.palette.m3secondaryContainer : Qt.alpha(Colours.tPalette.m3surfaceContainer, 0.6)

    function open(): void {
        popouts.currentName = "codexusage";
        popouts.currentCenter = root.mapToItem(bar, 0, height / 2).y;
        popouts.hasCurrent = true;
    }
    function toggle(): void {
        if (popouts.hasCurrent && popouts.currentName === "codexusage")
            popouts.hasCurrent = false;
        else
            open();
    }

    Column {
        id: layout
        anchors.centerIn: parent
        spacing: 4
        MaterialIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            text: CodexUsage.stale && CodexUsage.hasData ? "sync_problem" : "token"
            color: Colours.palette.m3primary
            font: Tokens.font.icon.small
        }
        Repeater {
            model: CodexUsage.windows
            Column {
                id: quota
                required property var modelData
                required property int index
                width: root.implicitWidth - 8
                spacing: 2
                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: (quota.index === 0 ? "5h " : "7d ") + CodexUsage.percentage(quota.modelData)
                    font.pixelSize: 10
                    color: Colours.palette.m3onSurface
                }
                Rectangle {
                    width: parent.width
                    height: 3
                    radius: 2
                    color: Colours.palette.m3outlineVariant
                    Rectangle {
                        height: parent.height
                        radius: parent.radius
                        width: quota.modelData ? parent.width * CodexUsage.remaining(quota.modelData) / 100 : 0
                        color: quota.modelData && CodexUsage.remaining(quota.modelData) <= 10 ? Colours.palette.m3error : Colours.palette.m3primary
                    }
                }
            }
        }
    }

    Timer {
        id: hoverCloseTimer
        interval: 200
        onTriggered: {
            if (root.popouts.currentName === "codexusage" && !mouse.containsMouse && !root.popupHovered)
                root.popouts.hasCurrent = false;
        }
    }
    readonly property bool popupHovered: popouts.currentName === "codexusage" && (popouts.current?.hovered ?? false)
    onPopupHoveredChanged: {
        if (popupHovered)
            hoverCloseTimer.stop();
        else
            hoverCloseTimer.restart();
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.open()
        onClicked: root.open()
        onExited: hoverCloseTimer.restart()
    }
    ToolTip.visible: mouse.containsMouse
    ToolTip.delay: 400
    ToolTip.text: "Codex · Remaining quota\n5 hours: " + CodexUsage.percentage(CodexUsage.data.primary)
        + " · Weekly: " + CodexUsage.percentage(CodexUsage.data.secondary)
        + (CodexUsage.stale ? "\n" + CodexUsage.statusText() : "")

    IpcHandler {
        target: "codexUsagePanel"
        function open(): void { root.open(); }
        function close(): void { root.popouts.hasCurrent = false; }
        function state(): string {
            const point = root.mapToItem(null, 0, 0);
            return JSON.stringify({open: root.popouts.hasCurrent && root.popouts.currentName === "codexusage", x:point.x,y:point.y,width:root.width,height:root.height});
        }
    }
}
