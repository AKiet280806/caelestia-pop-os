pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services

Scope {
    id: root
    property var state: ({active: false, addresses: [], selected: ""})
    property bool showing: false
    readonly property var windows: (state.addresses ?? []).map(address =>
        Hypr.toplevels.values.find(window => window.lastIpcObject.address === address)).filter(window => !!window)
    readonly property int selectedIndex: windows.findIndex(window => window.lastIpcObject.address === state.selected)

    function cancel(): void { Hypr.extras.message("eval caelestia_alt_tab_cancel()"); }
    function choose(address): void { Hypr.extras.message("eval caelestia_alt_tab_select(" + JSON.stringify(address) + ")"); }
    onStateChanged: {
        if (!state.active) {
            revealDelay.stop();
            showing = false;
        } else if (!showing && !revealDelay.running) {
            revealDelay.start();
        }
    }
    Timer {
        id: revealDelay
        interval: 90
        onTriggered: root.showing = root.state.active
    }
    FileView {
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/caelestia-window-state/switcher.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try { root.state = JSON.parse(text()); }
            catch (error) { root.state = {active: false, addresses: [], selected: ""}; }
        }
        onLoadFailed: root.state = {active: false, addresses: [], selected: ""}
    }
    LazyLoader {
        id: overlay
        active: root.showing && root.windows.length > 0
        StyledWindow {
            id: window
            name: "app-switcher"
            screen: Quickshell.screens.find(screen => screen.name === Hypr.focusedMonitor?.name) ?? Quickshell.screens[0]
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            anchors { top: true; bottom: true; left: true; right: true }

            readonly property int columns: Math.max(1, Math.min(root.windows.length, 4, Math.floor((width - 64) / 240)))
            readonly property int cardWidth: Math.min(252, Math.floor((width - 64 - (columns - 1) * 12) / columns))
            readonly property int cardHeight: 190
            readonly property int gridHeight: Math.ceil(root.windows.length / columns) * (cardHeight + 12) - 12
            function revealSelection(): void {
                const top = Math.floor(Math.max(0, root.selectedIndex) / columns) * (cardHeight + 12);
                if (top < scroll.contentY) scroll.contentY = top;
                else if (top + cardHeight > scroll.contentY + scroll.height)
                    scroll.contentY = Math.min(scroll.contentHeight - scroll.height, top + cardHeight - scroll.height);
            }
            Component.onCompleted: Qt.callLater(revealSelection)
            Connections {
                target: root
                function onSelectedIndexChanged(): void { Qt.callLater(window.revealSelection); }
            }
            Rectangle {
                anchors.fill: parent
                color: Qt.alpha(Colours.palette.m3scrim, 0.26)
                MouseArea { anchors.fill: parent; onClicked: root.cancel() }
            }
            StyledRect {
                id: panel
                anchors.centerIn: parent
                width: window.columns * window.cardWidth + (window.columns - 1) * 12 + 40
                height: Math.min(window.height - 70, window.gridHeight + 112)
                radius: Tokens.rounding.extraLarge
                color: Colours.palette.m3surfaceContainer
                border.width: 1
                border.color: Colours.palette.m3outlineVariant
                // Consume panel background clicks; only the outside area cancels.
                MouseArea { anchors.fill: parent }
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 14
                    RowLayout {
                        Layout.fillWidth: true
                        MaterialIcon {
                            text: "select_window"
                            color: Colours.palette.m3primary
                            font: Tokens.font.icon.medium
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: "Switch windows"
                            font: Tokens.font.title.medium
                        }
                        StyledText {
                            text: (Math.max(0, root.selectedIndex) + 1) + " / " + root.windows.length
                            color: Colours.palette.m3onSurfaceVariant
                        }
                    }
                    Flickable {
                        id: scroll
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentWidth: width
                        contentHeight: grid.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        flickableDirection: Flickable.VerticalFlick
                        interactive: contentHeight > height
                        Grid {
                            id: grid
                            columns: window.columns
                            spacing: 12
                            Repeater {
                                id: cards
                                model: ScriptModel { values: root.windows }
                                StyledRect {
                                    id: card
                                    required property var modelData
                                    required property int index
                                    readonly property bool selected: modelData.lastIpcObject.address === root.state.selected
                                    readonly property bool minimized: modelData.workspace?.name === "special:minimized"
                                    readonly property string icon: {
                                        const name = DesktopEntries.heuristicLookup(modelData.lastIpcObject.class)?.icon;
                                        return name ? Quickshell.iconPath(name, true) : "";
                                    }
                                    readonly property bool previewReady: preview.hasContent
                                    readonly property bool inViewport: y + height >= scroll.contentY && y <= scroll.contentY + scroll.height
                                    property int previewRetries: 0
                                    onInViewportChanged: if (inViewport) previewRetries = 0
                                    width: window.cardWidth
                                    height: window.cardHeight
                                    radius: Tokens.rounding.medium
                                    color: selected ? Colours.palette.m3secondaryContainer
                                        : mouse.containsMouse ? Colours.palette.m3surfaceContainerHighest : Colours.palette.m3surfaceContainerHigh
                                    border.width: selected ? 3 : 1
                                    border.color: selected ? Colours.palette.m3primary : Colours.palette.m3outlineVariant
                                    Accessible.role: Accessible.Button
                                    Accessible.name: modelData.title || modelData.lastIpcObject.class
                                    Accessible.onPressAction: root.choose(modelData.lastIpcObject.address)
                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 8
                                        RowLayout {
                                            Layout.fillWidth: true
                                            IconImage { implicitSize: 22; source: card.icon; visible: card.icon.length > 0 }
                                            MaterialIcon {
                                                visible: card.icon.length === 0
                                                text: "desktop_windows"
                                                font: Tokens.font.icon.small
                                            }
                                            StyledText {
                                                Layout.fillWidth: true
                                                text: card.modelData.title || card.modelData.lastIpcObject.class
                                                elide: Text.ElideRight
                                                maximumLineCount: 1
                                            }
                                        }
                                        StyledClippingRect {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            radius: Tokens.rounding.small
                                            color: Colours.palette.m3surfaceDim
                                            ScreencopyView {
                                                id: preview
                                                anchors.centerIn: parent
                                                captureSource: card.inViewport ? (card.modelData.wayland ?? null) : null
                                                live: false
                                                paintCursor: false
                                                constraintSize.width: parent.width
                                                constraintSize.height: parent.height
                                            }
                                            // A newly opened window may still be resizing. Retry twice,
                                            // then retain the icon fallback instead of spinning forever.
                                            Timer {
                                                interval: 350
                                                repeat: true
                                                running: card.inViewport && !preview.hasContent && card.previewRetries < 2
                                                onTriggered: {
                                                    card.previewRetries++;
                                                    preview.captureSource = null;
                                                    preview.captureSource = Qt.binding(() => card.inViewport ? (card.modelData.wayland ?? null) : null);
                                                }
                                            }
                                            Column {
                                                anchors.centerIn: parent
                                                spacing: 6
                                                visible: !preview.hasContent
                                                IconImage {
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    implicitSize: 44
                                                    source: card.icon
                                                    visible: card.icon.length > 0
                                                }
                                                MaterialIcon {
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    visible: card.icon.length === 0
                                                    text: "desktop_windows"
                                                    font: Tokens.font.icon.large
                                                }
                                                StyledText {
                                                    text: card.minimized ? "Minimized" : "Window preview"
                                                    color: Colours.palette.m3onSurfaceVariant
                                                }
                                            }
                                            StyledRect {
                                                anchors.right: parent.right
                                                anchors.bottom: parent.bottom
                                                anchors.margins: 5
                                                visible: card.minimized && preview.hasContent
                                                width: badge.implicitWidth + 12
                                                height: badge.implicitHeight + 6
                                                radius: 5
                                                color: Colours.palette.m3surfaceContainerHighest
                                                StyledText { id: badge; anchors.centerIn: parent; text: "Minimized"; font.pixelSize: 11 }
                                            }
                                        }
                                    }
                                    MouseArea {
                                        id: mouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.choose(card.modelData.lastIpcObject.address)
                                    }
                                }
                            }
                        }
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: "Tab / Shift+Tab to select  ·  Release Alt to switch  ·  Esc to cancel"
                        font.pixelSize: 12
                        color: Colours.palette.m3onSurfaceVariant
                        wrapMode: Text.WordWrap
                    }
                }
            }
            // Introspection exposes only synthetic-test-friendly geometry and readiness.
            property alias chooserPanel: panel
            property alias chooserCards: cards
        }
    }
    IpcHandler {
        target: "appSwitcher"
        function cancel(): void { root.cancel(); }
        function choose(address: string): void { root.choose(address); }
        function status(): string {
            const window = overlay.item;
            const panel = window?.chooserPanel;
            const cards = window?.chooserCards;
            let previews = 0;
            if (cards) for (let i = 0; i < cards.count; i++) if (cards.itemAt(i)?.previewReady) previews++;
            return JSON.stringify({active: root.state.active, visible: root.showing && !!window,
                selected: root.state.selected, addresses: root.windows.map(window => window.lastIpcObject.address),
                previews: previews, x: panel?.x ?? 0, y: panel?.y ?? 0, width: panel?.width ?? 0, height: panel?.height ?? 0});
        }
    }
}
