pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.services

StyledRect {
    id: root
    property bool tiling: false
    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: 66
    radius: Tokens.rounding.large
    color: tiling ? Colours.palette.m3secondaryContainer
        : Qt.alpha(Colours.tPalette.m3surfaceContainer, mouse.containsMouse ? 1 : 0.6)
    Accessible.role: Accessible.Button
    Accessible.name: tiling ? "Tiling enabled. Switch to floating" : "Floating enabled. Switch to tiling"
    Accessible.onPressAction: root.toggle()

    function toggle(): void {
        if (!toggleProcess.running) toggleProcess.running = true;
    }
    Column {
        anchors.centerIn: parent
        spacing: 5
        MaterialIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.tiling ? "grid_view" : "filter_none"
            color: root.tiling ? Colours.palette.m3primary : Colours.palette.m3onSurface
            font: Tokens.font.icon.medium
        }
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.tiling ? "Tiling" : "Float"
            font.pixelSize: 10
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggle()
    }
    ToolTip.visible: mouse.containsMouse
    ToolTip.delay: 350
    ToolTip.text: (tiling ? "Tiling" : "Floating") + " · All apps\nClick to switch to " + (tiling ? "floating" : "tiling")

    FileView {
        id: preference
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/caelestia/window-mode"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.tiling = text().trim() === "tiling"
    }
    Process {
        id: toggleProcess
        command: ["hyprctl", "eval", "caelestia_toggle_tiling()"]
        onExited: preference.reload()
    }
    IpcHandler {
        target: "windowLayout"
        function toggle(): void { root.toggle(); }
        function status(): string { return root.tiling ? "tiling" : "floating"; }
        function state(): string {
            const point = root.mapToItem(null, 0, 0);
            return JSON.stringify({mode: root.tiling ? "tiling" : "floating", x: point.x, y: point.y, width: root.width, height: root.height});
        }
    }
}
