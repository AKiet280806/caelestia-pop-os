//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root
    readonly property string base: Quickshell.env('CAELESTIA_CLIPBOARD_ROOT') || (Quickshell.env('XDG_DATA_HOME') || Quickshell.env('HOME') + '/.local/share') + '/caelestia-pop-os/clipboard'
    ClipboardTheme { id: colourTheme }
    function close(): void { clipboard.shutdown(); }
    ClipboardModel {
        id: clipboard
        sessionKey: Date.now().toString() + '-' + Math.floor(Math.random() * 1000000000).toString()
        backend: root.base + '/clipboard.py'
        onCopied: root.close()
        onClosed: Qt.quit()
    }
    IpcHandler {
        target: 'clipboard'
        function toggle(): void { root.close(); }
        function close(): void { root.close(); }
        function status(): string {
            // Geometry/counts only: never expose clipboard content through diagnostics.
            return JSON.stringify({count: clipboard.items.length, matches: clipboard.filtered.length, selected: clipboard.selected,
                category: clipboard.category, previews: Object.values(clipboard.thumbnails).filter(url => !!url).length, loading: clipboard.loading, copying: clipboard.copying,
                x: panel.x, y: panel.y, width: panel.width, height: panel.height});
        }
    }
    PanelWindow {
        id: window
        screen: Quickshell.screens.find(screen => screen.name === Quickshell.env('CAELESTIA_CLIPBOARD_SCREEN')) || Quickshell.screens[0]
        color: 'transparent'
        anchors { top: true; bottom: true; left: true; right: true }
        WlrLayershell.namespace: 'caelestia-clipboard'
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        Rectangle {
            anchors.fill: parent
            color: '#40000000'
            MouseArea { anchors.fill: parent; onClicked: root.close() }
        }
        Rectangle {
            id: panel
            Keys.onEscapePressed: root.close()
            anchors.centerIn: parent
            width: Math.min(940, window.width - 48)
            height: Math.min(644, window.height - 64)
            radius: 26
            color: Qt.alpha(colourTheme.surface, colourTheme.panelAlpha)
            border.width: 1; border.color: colourTheme.outline
            MouseArea { anchors.fill: parent }
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 24
                spacing: 16
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14
                    Rectangle {
                        implicitWidth: 44; implicitHeight: 44; radius: 14
                        color: Qt.alpha(colourTheme.primary, 0.15)
                        Text { anchors.centerIn: parent; text: 'content_paste'; font.family: 'Material Symbols Rounded'; font.pixelSize: 25; color: colourTheme.primary }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 3
                        Text { text: 'Clipboard'; font.family: 'Rubik'; font.pixelSize: 23; font.weight: Font.DemiBold; color: colourTheme.text }
                        Text { text: 'Your recent copies, within reach'; font.family: 'Rubik'; font.pixelSize: 12; color: colourTheme.muted }
                    }
                    Item { Layout.fillWidth: true }
                    Text { text: clipboard.items.length + ' items'; color: colourTheme.muted; font.family: 'Rubik'; font.pixelSize: 12 }
                    ToolButton {
                        id: closeButton
                        Layout.alignment: Qt.AlignRight
                        text: '×'; font.pixelSize: 24; palette.buttonText: colourTheme.muted
                        Accessible.name: 'Close clipboard'
                        onClicked: root.close()
                        background: Rectangle { radius: 10; color: closeButton.hovered ? colourTheme.high : 'transparent' }
                    }
                }
                TextField {
                    id: search
                    Layout.fillWidth: true; implicitHeight: 48
                    placeholderText: 'Search your clipboard…'
                    color: colourTheme.text; placeholderTextColor: colourTheme.muted
                    selectionColor: colourTheme.primary; selectedTextColor: colourTheme.onPrimary
                    font.family: 'Rubik'; font.pixelSize: 15
                    leftPadding: 44; rightPadding: 16
                    Accessible.name: 'Search clipboard history'
                    background: Rectangle { radius: 14; color: colourTheme.low; border.width: 1; border.color: search.activeFocus ? Qt.alpha(colourTheme.primary, 0.65) : colourTheme.outline }
                    Text { x: 15; anchors.verticalCenter: parent.verticalCenter; text: 'search'; font.family: 'Material Symbols Rounded'; font.pixelSize: 21; color: colourTheme.muted }
                    onTextChanged: clipboard.query = text
                    Keys.onPressed: event => {
                        if ((event.modifiers & Qt.ControlModifier) && event.key >= Qt.Key_1 && event.key <= Qt.Key_4) {
                            clipboard.category = ['All', 'Text', 'Images', 'Links'][event.key - Qt.Key_1];
                            event.accepted = true;
                        }
                    }
                    Keys.onDownPressed: clipboard.move(1)
                    Keys.onUpPressed: clipboard.move(-1)
                    Keys.onReturnPressed: clipboard.copy(clipboard.selected)
                    Keys.onEnterPressed: clipboard.copy(clipboard.selected)
                    Keys.onEscapePressed: root.close()
                    Component.onCompleted: { forceActiveFocus(); clipboard.refresh(); }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Repeater {
                        model: ['All', 'Text', 'Images', 'Links']
                        delegate: Rectangle {
                            id: chip
                            required property string modelData
                            width: chipLabel.implicitWidth + 26; height: 31; radius: 10
                            color: clipboard.category === modelData ? colourTheme.primary : chipMouse.containsMouse ? colourTheme.high : colourTheme.low
                            border.width: clipboard.category === modelData ? 0 : 1
                            border.color: colourTheme.outline
                            Accessible.role: Accessible.Button
                            Accessible.name: modelData
                            Accessible.onPressAction: clipboard.category = modelData
                            Text { id: chipLabel; anchors.centerIn: parent; text: chip.modelData; font.family: 'Rubik'; font.pixelSize: 12; color: clipboard.category === chip.modelData ? colourTheme.onPrimary : colourTheme.muted }
                            MouseArea { id: chipMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { clipboard.category = chip.modelData; search.forceActiveFocus(); } }
                        }
                    }
                    Item { Layout.fillWidth: true }
                    ToolButton {
                        id: refreshButton
                        text: 'refresh'; font.family: 'Material Symbols Rounded'; font.pixelSize: 20
                        palette.buttonText: colourTheme.muted
                        Accessible.name: 'Refresh clipboard history'
                        enabled: !clipboard.loading && !clipboard.copying
                        onClicked: { clipboard.refresh(); search.forceActiveFocus(); }
                        background: Rectangle { radius: 10; color: refreshButton.hovered ? colourTheme.high : 'transparent' }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    spacing: 16
                    Item {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        ListView {
                            id: list
                            anchors.fill: parent; clip: true; spacing: 8
                            model: clipboard.filtered
                            currentIndex: clipboard.selected
                            boundsBehavior: Flickable.StopAtBounds
                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                            onCurrentIndexChanged: positionViewAtIndex(Math.max(0, currentIndex), ListView.Contain)
                            delegate: ClipboardCard {
                                required property var modelData
                                required property int index
                                width: list.width - 8
                                entry: modelData; theme: colourTheme
                                selected: clipboard.selected === index
                                thumbnail: clipboard.thumbnails[modelData.id] || ''
                                disabled: clipboard.copying
                                Component.onCompleted: if (modelData.kind === 'image') clipboard.requestThumbnail(modelData.id)
                                onChosen: { clipboard.selected = index; search.forceActiveFocus(); }
                                onActivated: clipboard.copy(index)
                            }
                        }
                        Column {
                            anchors.centerIn: parent
                            visible: clipboard.filtered.length === 0
                            width: parent.width - 30; spacing: 14
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: clipboard.loading ? 'hourglass_top' : clipboard.error ? 'error_outline' : 'content_paste_off'; font.family: 'Material Symbols Rounded'; font.pixelSize: 42; color: colourTheme.primary }
                            Text {
                                width: parent.width; horizontalAlignment: Text.AlignHCenter
                                text: clipboard.loading ? 'Loading your history…' : clipboard.error ? clipboard.error : clipboard.items.length ? 'No matching items' : 'Nothing copied yet'
                                wrapMode: Text.Wrap; font.family: 'Rubik'; font.pixelSize: 16; color: colourTheme.text
                            }
                            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: clipboard.error ? 'Try Refresh, or check that cliphist is running.' : 'Copy text or an image, and find it here.'; wrapMode: Text.Wrap; font.family: 'Rubik'; font.pixelSize: 12; color: colourTheme.muted }
                        }
                    }
                    ClipboardPreview {
                        Layout.preferredWidth: Math.min(400, panel.width * 0.45)
                        Layout.fillHeight: true
                        visible: panel.width >= 760
                        entry: clipboard.selectedEntry
                        theme: colourTheme
                        thumbnail: clipboard.selectedEntry ? (clipboard.thumbnails[clipboard.selectedEntry.id] || '') : ''
                        copying: clipboard.copying
                        previewFailed: !!clipboard.selectedEntry && clipboard.thumbnails[clipboard.selectedEntry.id] === ''
                        onCopyRequested: clipboard.copy(clipboard.selected)
                    }
                }
                Text {
                    Layout.fillWidth: true
                    visible: clipboard.error.length > 0 && clipboard.filtered.length > 0
                    text: clipboard.error; color: colourTheme.error; font.family: 'Rubik'; font.pixelSize: 12
                }
                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: colourTheme.outline }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16
                    Text { text: '↑ ↓  Navigate'; color: colourTheme.muted; font.family: 'Rubik'; font.pixelSize: 11 }
                    Text { text: clipboard.copying ? 'Copying…' : '↵  Copy'; color: colourTheme.muted; font.family: 'Rubik'; font.pixelSize: 11 }
                    Item { Layout.fillWidth: true }
                    Text { text: 'Ctrl+1–4  Filter   ·   Esc  Close'; color: colourTheme.muted; font.family: 'Rubik'; font.pixelSize: 11 }
                }
            }
        }
    }
}
