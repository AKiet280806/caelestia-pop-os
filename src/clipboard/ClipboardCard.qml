import QtQuick

Rectangle {
    id: root
    required property var entry
    required property var theme
    property string thumbnail: ''
    signal chosen()
    property bool selected: false
    property bool disabled: false
    signal activated()
    implicitHeight: entry.kind === 'image' ? 108 : 88
    radius: 16
    color: selected ? Qt.alpha(theme.primary, 0.15) : mouse.containsMouse ? Qt.alpha(theme.high, Math.min(1, theme.cardAlpha + 0.1)) : Qt.alpha(theme.low, theme.cardAlpha)
    border.width: selected ? 1.5 : 1
    border.color: selected ? theme.primary : Qt.alpha(theme.outline, 0.4)
    Accessible.role: Accessible.ListItem
    Accessible.name: entry.detail + ': ' + entry.title
    Accessible.onPressAction: if (!root.disabled) root.chosen()
    Behavior on color { ColorAnimation { duration: 110 } }
    Rectangle {
        id: iconBox
        x: 14; anchors.verticalCenter: parent.verticalCenter
        width: root.entry.kind === 'image' ? 112 : 42; height: root.entry.kind === 'image' ? 80 : 42; radius: 12
        clip: true
        color: Qt.alpha(root.theme.primary, 0.12)
        Text {
            visible: !previewImage.visible
            anchors.centerIn: parent
            text: root.entry.kind === 'image' ? 'image' : root.entry.kind === 'link' ? 'link' : root.entry.kind === 'file' ? 'draft' : 'notes'
            font.family: 'Material Symbols Rounded'; font.pixelSize: 22
            color: root.theme.primary
        }
    }
    Image {
        id: previewImage
        anchors.fill: iconBox; anchors.margins: 3
        source: root.thumbnail
        sourceSize: Qt.size(224, 160)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        visible: status === Image.Ready
    }
    Column {
        anchors.left: iconBox.right; anchors.leftMargin: 14
        anchors.right: copyIcon.left; anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5
        Text {
            width: parent.width
            text: root.entry.title || 'Empty text'
            textFormat: Text.PlainText
            font.family: 'Rubik'; font.pixelSize: 14
            color: root.theme.text
            wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
        }
        Text {
            width: parent.width
            text: root.entry.detail
            textFormat: Text.PlainText
            font.family: 'Rubik'; font.pixelSize: 11
            color: root.theme.muted; elide: Text.ElideRight
        }
    }
    Text {
        id: copyIcon
        anchors.right: parent.right; anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        text: root.selected ? 'keyboard_return' : 'content_copy'
        font.family: 'Material Symbols Rounded'; font.pixelSize: 19
        color: root.selected ? root.theme.primary : root.theme.muted
        opacity: root.selected || mouse.containsMouse ? 1 : 0.35
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: !root.disabled
        onClicked: root.chosen()
        onDoubleClicked: root.activated()
    }
    MouseArea {
        anchors.centerIn: copyIcon
        width: 34; height: 42
        cursorShape: Qt.PointingHandCursor
        enabled: !root.disabled
        onClicked: root.activated()
    }
}
