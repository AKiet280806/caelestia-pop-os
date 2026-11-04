import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    required property var entry
    required property var theme
    property string thumbnail: ''
    property bool copying: false
    property bool previewFailed: false
    signal copyRequested()
    radius: 16
    color: Qt.alpha(theme.low, theme.cardAlpha)
    border.width: 1; border.color: Qt.alpha(theme.outline, 0.6)
    ColumnLayout {
        anchors.fill: parent; anchors.margins: 16; spacing: 12
        Text { text: 'Preview'; color: root.theme.muted; font.family: 'Rubik'; font.pixelSize: 12 }
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true
            Image {
                anchors.fill: parent
                visible: root.entry?.kind === 'image' && status === Image.Ready
                source: root.entry?.kind === 'image' ? root.thumbnail : ''
                sourceSize: Qt.size(960, 720)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }
            Text {
                anchors.fill: parent
                visible: root.entry?.kind !== 'image'
                text: root.entry?.preview || 'Select an item to see it here.'
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                font.family: 'Rubik'; font.pixelSize: 14
                color: root.theme.text
                clip: true
            }
            Text {
                anchors.centerIn: parent
                visible: root.entry?.kind === 'image' && !root.thumbnail
                text: root.previewFailed ? 'Preview unavailable' : 'Loading image…'
                font.family: 'Rubik'; font.pixelSize: 13
                color: root.theme.muted
            }
        }
        Text {
            Layout.fillWidth: true
            text: root.entry?.detail || ''
            textFormat: Text.PlainText
            color: root.theme.muted; font.family: 'Rubik'; font.pixelSize: 11
            elide: Text.ElideRight
        }
        Button {
            id: copyButton
            Layout.fillWidth: true; implicitHeight: 40
            text: root.copying ? 'Copying…' : 'Copy item'
            enabled: !!root.entry && !root.copying
            Accessible.name: 'Copy selected clipboard item'
            onClicked: root.copyRequested()
            contentItem: Text { text: copyButton.text; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.family: 'Rubik'; font.pixelSize: 13; color: root.theme.onPrimary }
            background: Rectangle { radius: 11; color: copyButton.hovered ? Qt.lighter(root.theme.primary, 1.08) : root.theme.primary; opacity: copyButton.enabled ? 1 : 0.4 }
        }
    }
}
