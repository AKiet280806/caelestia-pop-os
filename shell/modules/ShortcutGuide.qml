pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services

Scope {
    id: root
    property bool showing: false
    readonly property var groups: [
        {title: "Windows & layout", rows: [
            ["Alt + Tab / Alt + Shift + Tab", "Switch windows"],
            ["Alt + F4 / Win + Q", "Close window"],
            ["Alt + F10", "Maximize / restore"],
            ["Win + V", "Float / tile this window"],
            ["Win + Shift + T", "Float / tile this workspace"],
            ["Win + F", "Fullscreen"],
            ["Win + H / Win + Shift + H", "Minimize / restore one"],
            ["Win + M / Win + Shift + M", "Minimize / restore all"]
        ]},
        {title: "Everyday", rows: [
            ["Win + D", "Find an app"],
            ["Win + Enter / Win + T", "Open terminal"],
            ["Win + E", "Open files"],
            ["Win + B", "Open browser"],
            ["Win + L", "Lock screen"],
            ["Win + N", "Notifications"],
            ["Win + Shift + P", "Toggle popup hover"],
            ["Ctrl + Shift + Esc", "System monitor"]
        ]},
        {title: "Workspaces & moving", rows: [
            ["Win + 1–9 / 0", "Go to workspace 1–10"],
            ["Win + Shift + 1–9 / 0", "Move window to workspace"],
            ["Win + arrow keys", "Focus a nearby window"],
            ["Win + left mouse drag", "Move window"],
            ["Win + right mouse drag", "Resize window"]
        ]},
        {title: "Capture & clipboard", rows: [
            ["Print Screen", "Copy screenshot"],
            ["Win + Shift + S", "Copy selected region"],
            ["Win + Shift + V", "Clipboard history"],
            ["Ctrl + V", "Paste into the active app"],
            ["Esc", "Cancel capture / close this guide"]
        ]}
    ]

    IpcHandler {
        target: "shortcutGuide"
        function toggle(): void { root.showing = !root.showing; }
        function close(): void { root.showing = false; }
        function status(): bool { return root.showing; }
    }

    LazyLoader {
        active: root.showing
        StyledWindow {
            id: window
            name: "shortcut-guide"
            screen: Quickshell.screens.find(screen => screen.name === Hypr.focusedMonitor?.name) ?? Quickshell.screens[0]
            color: "transparent"
            anchors { top: true; bottom: true; left: true; right: true }
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            Rectangle {
                anchors.fill: parent
                color: Qt.alpha(Colours.palette.m3scrim, 0.25)
                MouseArea { anchors.fill: parent; onClicked: root.showing = false }
            }
            StyledRect {
                id: panel
                anchors.centerIn: parent
                width: Math.min(920, window.width - 48)
                height: Math.min(730, window.height - 64)
                radius: Tokens.rounding.extraLarge
                color: Qt.alpha(Colours.palette.m3surfaceContainer, Math.max(0.86, Colours.tPalette.m3surfaceContainer.a))
                border.width: 1
                border.color: Colours.palette.m3outlineVariant
                focus: true
                Keys.onEscapePressed: root.showing = false
                Component.onCompleted: forceActiveFocus()
                MouseArea { anchors.fill: parent }
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 26
                    spacing: 20
                    RowLayout {
                        Layout.fillWidth: true
                        MaterialIcon {
                            text: "keyboard"
                            font: Tokens.font.icon.large
                            color: Colours.palette.m3primary
                        }
                        ColumnLayout {
                            spacing: 3
                            StyledText { text: "Keyboard shortcuts"; font.pixelSize: 24 }
                            StyledText {
                                text: "Win = Super / Windows key"
                                color: Colours.palette.m3onSurfaceVariant
                                font.pixelSize: 12
                            }
                        }
                        Item { Layout.fillWidth: true }
                        IconButton {
                            icon: "close"
                            type: IconButton.Tonal
                            isRound: true
                            Accessible.name: "Close keyboard shortcuts"
                            onClicked: root.showing = false
                        }
                    }
                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentWidth: availableWidth
                        GridLayout {
                            width: parent.width
                            columns: panel.width >= 740 ? 2 : 1
                            columnSpacing: 16
                            rowSpacing: 16
                            Repeater {
                                model: root.groups
                                delegate: StyledRect {
                                    id: group
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignTop
                                    implicitHeight: groupContent.implicitHeight + 32
                                    radius: Tokens.rounding.large
                                    color: Colours.tPalette.m3surfaceContainerHigh
                                    ColumnLayout {
                                        id: groupContent
                                        anchors.fill: parent
                                        anchors.margins: 16
                                        spacing: 12
                                        StyledText {
                                            text: group.modelData.title
                                            color: Colours.palette.m3primary
                                            font.pixelSize: 15
                                        }
                                        Repeater {
                                            model: group.modelData.rows
                                            delegate: RowLayout {
                                                id: row
                                                required property var modelData
                                                Layout.fillWidth: true
                                                spacing: 10
                                                StyledText {
                                                    Layout.preferredWidth: group.width * 0.51
                                                    text: row.modelData[0]
                                                    font.pixelSize: 12
                                                    wrapMode: Text.Wrap
                                                }
                                                StyledText {
                                                    Layout.fillWidth: true
                                                    text: row.modelData[1]
                                                    color: Colours.palette.m3onSurfaceVariant
                                                    font.pixelSize: 12
                                                    wrapMode: Text.Wrap
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
