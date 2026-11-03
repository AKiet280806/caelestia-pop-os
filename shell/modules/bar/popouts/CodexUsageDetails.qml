pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root
    readonly property alias hovered: hoverHandler.hovered
    HoverHandler { id: hoverHandler }
    implicitWidth: 330
    implicitHeight: layout.implicitHeight

    ColumnLayout {
        id: layout
        width: parent.width
        spacing: Tokens.spacing.medium

        RowLayout {
            Layout.fillWidth: true
            StyledText {
                Layout.fillWidth: true
                text: "Codex" + (CodexUsage.data.plan_type ? " · " + CodexUsage.data.plan_type.charAt(0).toUpperCase() + CodexUsage.data.plan_type.slice(1) : "")
                font: Tokens.font.title.medium
            }
            IconButton {
                implicitWidth: 32
                implicitHeight: 32
                icon: "refresh"
                type: IconButton.Text
                disabled: CodexUsage.data.refreshing ?? false
                onClicked: CodexUsage.refresh()
            }
        }
        StyledText {
            Layout.fillWidth: true
            text: "Usage limits for the Codex account signed in on this device"
            wrapMode: Text.WordWrap
            color: Colours.palette.m3onSurfaceVariant
        }
        Repeater {
            model: CodexUsage.windows
            StyledRect {
                id: card
                required property var modelData
                required property int index
                Layout.fillWidth: true
                implicitHeight: cardLayout.implicitHeight + 24
                radius: Tokens.rounding.medium
                color: Colours.tPalette.m3surfaceContainer

                ColumnLayout {
                    id: cardLayout
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        StyledText {
                            Layout.fillWidth: true
                            text: CodexUsage.windowName(card.modelData, card.index)
                            font: Tokens.font.title.small
                        }
                        StyledText {
                            text: CodexUsage.percentage(card.modelData) + " remaining"
                            color: Colours.palette.m3primary
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 6
                        radius: 3
                        color: Colours.palette.m3outlineVariant
                        Rectangle {
                            height: parent.height
                            radius: parent.radius
                            width: card.modelData ? parent.width * CodexUsage.remaining(card.modelData) / 100 : 0
                            color: card.modelData && CodexUsage.remaining(card.modelData) <= 10 ? Colours.palette.m3error : Colours.palette.m3primary
                        }
                    }
                    StyledText {
                        text: card.modelData ? Math.round(card.modelData.used_percent) + "% used" : "Usage data unavailable"
                        color: Colours.palette.m3onSurfaceVariant
                    }
                    StyledText {
                        text: CodexUsage.resetText(card.modelData)
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }
            }
        }
        StyledText {
            Layout.fillWidth: true
            text: CodexUsage.statusText()
            wrapMode: Text.WordWrap
            color: CodexUsage.stale && CodexUsage.hasData ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
        }
        StyledText {
            Layout.fillWidth: true
            visible: CodexUsage.hasData
            text: "Last updated: " + Qt.formatDateTime(new Date((CodexUsage.data.updated_at ?? 0) * 1000), "HH:mm:ss · dd/MM")
            color: Colours.palette.m3onSurfaceVariant
        }
    }
}
