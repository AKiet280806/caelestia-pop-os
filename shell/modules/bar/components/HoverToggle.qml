import QtQuick
import QtQuick.Controls
import Caelestia.Config
import qs.components
import qs.services

StyledRect {
    id: root
    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: 56
    radius: Tokens.rounding.large
    color: PopupHover.enabled ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainer
    Accessible.role: Accessible.CheckBox
    Accessible.name: "Open popups on hover"
    Accessible.checked: PopupHover.enabled
    Accessible.onToggleAction: PopupHover.toggle()

    Column {
        anchors.centerIn: parent
        spacing: 3
        MaterialIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            text: PopupHover.enabled ? "touchpad_mouse" : "mouse_lock"
            color: PopupHover.enabled ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
            font: Tokens.font.icon.medium
        }
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: PopupHover.enabled ? "Hover" : "Click"
            font.pixelSize: 10
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: PopupHover.toggle()
    }
    ToolTip.visible: mouse.containsMouse
    ToolTip.delay: 350
    ToolTip.text: "Auto-open popups: " + (PopupHover.enabled ? "On" : "Off") + "\nWin + Shift + P"
}
