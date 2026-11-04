pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root
    required property var popouts
    readonly property bool popupActive: popouts.hasCurrent && popouts.currentName === "aiusage"
    onPopupActiveChanged: if (!popupActive) selectorOpen = false;
    readonly property alias hovered: hoverHandler.hovered
    readonly property bool interactionActive: selectorOpen
    property bool selectorOpen: false
    readonly property real availableHeight: Math.max(160, (Screen.height || 800) - 100)
    readonly property var filteredProviders: {
        const query = providerSearch.text.trim().toLowerCase();
        return AIUsage.providers.filter(item => !query || item.name.toLowerCase().includes(query) || item.id.toLowerCase().includes(query));
    }
    function toggleProviderSelector(): void {
        selectorOpen = !selectorOpen;
        if (selectorOpen) {
            providerSearch.clear();
            providerList.currentIndex = filteredProviders.findIndex(item => item.id === AIUsage.data.provider);
            providerList.positionViewAtIndex(Math.max(0, providerList.currentIndex), ListView.Contain);
            Qt.callLater(() => providerSearch.forceActiveFocus());
        }
    }
    implicitWidth: 330
    // Keep the same compact size for both hover paths, filtering and refresh.
    // Longer provider details remain accessible through the Flickable below.
    implicitHeight: Math.min(426, availableHeight)
    HoverHandler { id: hoverHandler }

    Flickable {
        id: body
        anchors.fill: parent
        clip: true
        contentHeight: layout.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: StyledScrollBar { flickable: body }

        ColumnLayout {
            id: layout
            width: body.width
            spacing: Tokens.spacing.medium

            RowLayout {
                Layout.fillWidth: true
                StyledText {
                    Layout.fillWidth: true
                    text: "AI Usage"
                    font: Tokens.font.title.medium
                }
                IconButton {
                    id: refreshButton
                    implicitWidth: 32
                    implicitHeight: 32
                    icon: "refresh"
                    type: IconButton.Text
                    disabled: AIUsage.refreshing
                    onClicked: AIUsage.refresh()
                }
            }
            StyledText {
                Layout.fillWidth: true
                text: "Usage limits from the selected provider"
                wrapMode: Text.WordWrap
                color: Colours.palette.m3onSurfaceVariant
            }
            TextButton {
                id: selectorButton
                Layout.fillWidth: true
                text: AIUsage.providerName + (root.selectorOpen ? "  ▴" : "  ▾")
                type: TextButton.Tonal
                disabled: AIUsage.selecting
                label.width: width - horizontalPadding * 2 - 32
                label.elide: Text.ElideRight
                label.horizontalAlignment: Text.AlignLeft
                label.anchors.horizontalCenterOffset: 16
                label.textFormat: Text.PlainText
                Image {
                    anchors.left: parent.left
                    anchors.leftMargin: selectorButton.horizontalPadding
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18; height: 18
                    sourceSize: Qt.size(36, 36)
                    fillMode: Image.PreserveAspectFit
                    source: AIUsage.providerIcon(AIUsage.data.provider)
                }
                onClicked: root.toggleProviderSelector()
            }
            SearchBar {
                id: providerSearch
                Layout.fillWidth: true
                visible: root.selectorOpen
                placeholderText: "Search providers"
                topPadding: Tokens.padding.small
                bottomPadding: Tokens.padding.small
                onTextChanged: providerList.positionViewAtBeginning()
                onAccepted: {
                    if (root.filteredProviders.length) {
                        AIUsage.select(root.filteredProviders[0].id);
                        root.selectorOpen = false;
                    }
                }
            }
            StyledRect {
                Layout.fillWidth: true
                implicitHeight: Math.min(192, providerList.count * 36)
                visible: root.selectorOpen
                color: Colours.tPalette.m3surfaceContainer
                radius: Tokens.rounding.medium
                clip: true
                ListView {
                    id: providerList
                    anchors.fill: parent
                    model: root.filteredProviders
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: StyledScrollBar { flickable: providerList }
                    delegate: TextButton {
                        id: providerOption
                        required property var modelData
                        width: providerList.width
                        implicitHeight: 36
                        text: (modelData.id === AIUsage.data.provider ? "✓  " : "    ") + modelData.name
                        type: TextButton.Text
                        label.width: width - horizontalPadding * 2 - 32
                        label.elide: Text.ElideRight
                        label.horizontalAlignment: Text.AlignLeft
                        label.anchors.horizontalCenterOffset: 16
                        Image {
                            anchors.left: parent.left
                            anchors.leftMargin: providerOption.horizontalPadding
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18; height: 18
                            sourceSize: Qt.size(36, 36)
                            fillMode: Image.PreserveAspectFit
                            source: AIUsage.providerIcon(providerOption.modelData.id)
                        }
                        label.textFormat: Text.PlainText
                        onClicked: {
                            AIUsage.select(modelData.id);
                            root.selectorOpen = false;
                        }
                    }
                }
            }
            StyledText {
                Layout.fillWidth: true
                visible: root.selectorOpen && !providerList.count
                text: "No matching providers"
                color: Colours.palette.m3onSurfaceVariant
            }
            Repeater {
                model: AIUsage.windows
                StyledRect {
                    id: card
                    required property var modelData
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
                                text: AIUsage.windowName(card.modelData)
                                textFormat: Text.PlainText
                                wrapMode: Text.WordWrap
                                font: Tokens.font.title.small
                            }
                            StyledText {
                                text: AIUsage.remaining(card.modelData) >= 0 ? AIUsage.percentage(card.modelData) + " remaining" : "Unknown"
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
                                width: parent.width * Math.max(0, AIUsage.remaining(card.modelData)) / 100
                                color: AIUsage.remaining(card.modelData) >= 0 && AIUsage.remaining(card.modelData) <= 10 ? Colours.palette.m3error : Colours.palette.m3primary
                            }
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: AIUsage.remaining(card.modelData) >= 0 ? Math.round(card.modelData.used_percent) + "% used" : "Usage data unavailable"
                            color: Colours.palette.m3onSurfaceVariant
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: AIUsage.resetText(card.modelData)
                            wrapMode: Text.WordWrap
                            color: Colours.palette.m3onSurfaceVariant
                        }
                    }
                }
            }
            Repeater {
                model: AIUsage.details
                StyledRect {
                    id: detail
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: detailLayout.implicitHeight + 24
                    radius: Tokens.rounding.medium
                    color: Colours.tPalette.m3surfaceContainer
                    ColumnLayout {
                        id: detailLayout
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                        spacing: 6
                        StyledText {
                            Layout.fillWidth: true
                            text: detail.modelData.label || "Details"
                            textFormat: Text.PlainText
                            font: Tokens.font.title.small
                            wrapMode: Text.WordWrap
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: String(detail.modelData.value ?? "Unknown")
                            textFormat: Text.PlainText
                            wrapMode: Text.WrapAnywhere
                            color: Colours.palette.m3onSurfaceVariant
                        }
                    }
                }
            }
            StyledText {
                Layout.fillWidth: true
                text: AIUsage.statusText()
                wrapMode: Text.WordWrap
                color: AIUsage.stale && AIUsage.hasData ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
            }
            StyledText {
                Layout.fillWidth: true
                visible: AIUsage.needsSetup()
                text: "Sign in with the provider's native CLI or configure it in CodexBar, then refresh."
                wrapMode: Text.WordWrap
                color: Colours.palette.m3onSurfaceVariant
            }
            StyledText {
                Layout.fillWidth: true
                visible: AIUsage.hasData
                text: "Last updated: " + Qt.formatDateTime(new Date((AIUsage.data.updated_at ?? 0) * 1000), "HH:mm:ss · dd/MM")
                wrapMode: Text.WordWrap
                color: Colours.palette.m3onSurfaceVariant
            }
        }
    }
}
