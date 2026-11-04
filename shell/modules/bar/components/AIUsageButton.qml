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
    implicitHeight: 128
    radius: Tokens.rounding.large
    color: mouse.containsMouse || (popouts.hasCurrent && popouts.currentName === "aiusage")
        ? Colours.palette.m3secondaryContainer : Qt.alpha(Colours.tPalette.m3surfaceContainer, 0.6)

    function open(): void {
        hoverCloseTimer.stop();
        popouts.currentName = "aiusage";
        popouts.currentCenter = root.mapToItem(bar, 0, height / 2).y;
        popouts.hasCurrent = true;
    }

    Column {
        id: layout
        width: root.implicitWidth - 8
        anchors.centerIn: parent
        spacing: 4
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 28
            height: 28
            clip: true
            Image {
                anchors.centerIn: parent
                width: 20
                height: 20
                sourceSize: Qt.size(40, 40)
                fillMode: Image.PreserveAspectFit
                source: AIUsage.providerIcon(AIUsage.data.provider)
            }
        }
        Repeater {
            model: AIUsage.sidebarDetails
            Column {
                id: sidebarDetail
                required property var modelData
                width: layout.width
                StyledText { width: parent.width; text: sidebarDetail.modelData.label; textFormat: Text.PlainText; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 9 }
                StyledText { width: parent.width; text: sidebarDetail.modelData.value; textFormat: Text.PlainText; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 10 }
            }
        }
        Repeater {
            model: AIUsage.sidebarWindows
            Column {
                id: quota
                required property var modelData
                width: layout.width
                spacing: 2
                StyledText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: AIUsage.compactWindowName(quota.modelData)
                    textFormat: Text.PlainText
                    font.pixelSize: 9
                    color: Colours.palette.m3onSurfaceVariant
                }
                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: AIUsage.percentage(quota.modelData)
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
                        width: parent.width * Math.max(0, AIUsage.remaining(quota.modelData)) / 100
                        color: AIUsage.remaining(quota.modelData) >= 0 && AIUsage.remaining(quota.modelData) <= 10 ? Colours.palette.m3error : Colours.palette.m3primary
                    }
                }
            }
        }
    }

    readonly property bool popupHovered: popouts.currentName === "aiusage" && ((popouts.current?.hovered ?? false) || (popouts.current?.interactionActive ?? false))
    onPopupHoveredChanged: {
        if (popupHovered) hoverCloseTimer.stop();
        else hoverCloseTimer.restart();
    }
    Timer {
        id: hoverCloseTimer
        interval: 200
        onTriggered: {
            if (root.popouts.currentName === "aiusage" && !mouse.containsMouse && !mouse.pressed && !root.popupHovered)
                root.popouts.hasCurrent = false;
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.open()
        onClicked: root.open()
        onExited: hoverCloseTimer.restart()
        onPressedChanged: if (!pressed && !containsMouse) hoverCloseTimer.restart()
    }
    ToolTip.visible: mouse.containsMouse && !(popouts.hasCurrent && popouts.currentName === "aiusage")
    ToolTip.delay: 400
    ToolTip.text: "AI Usage · " + AIUsage.providerName + "\n"
        + AIUsage.sidebarWindows.map(window => AIUsage.windowName(window) + ": " + AIUsage.percentage(window) + " remaining").join("\n")
        + "\n" + AIUsage.statusText()

    IpcHandler {
        target: "aiUsagePanel"
        function open(): void { root.open(); }
        function close(): void { root.popouts.hasCurrent = false; }
        function openProviders(): void {
            root.open();
            Qt.callLater(() => root.popouts.current?.toggleProviderSelector());
        }
        function state(): string {
            const point = root.mapToItem(null, 0, 0);
            const popupPoint = root.popouts.mapToItem(null, 0, 0);
            return JSON.stringify({currentName: root.popouts.currentName, anyOpen: root.popouts.hasCurrent, panelX: popupPoint.x, panelY: popupPoint.y, open: root.popouts.hasCurrent && root.popouts.currentName === "aiusage", x: point.x, y: point.y, width: root.width, height: root.height, panelHeight: root.popouts.current?.height ?? 0, selectorOpen: root.popouts.current?.selectorOpen ?? false, matches: root.popouts.current?.filteredProviders?.length ?? 0});
        }
    }
}
