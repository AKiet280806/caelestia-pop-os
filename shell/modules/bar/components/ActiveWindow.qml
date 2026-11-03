pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

Item {
    id: root

    required property var bar
    required property Brightness.Monitor monitor
    property color colour: Colours.palette.m3primary
    readonly property int entrySize: Math.max(36, Tokens.sizes.bar.innerWidth)
    readonly property var windows: Hypr.toplevels.values.filter(w => w.lastIpcObject.mapped && w.lastIpcObject.class && w.lastIpcObject.address)
    readonly property var selected: Hypr.activeToplevel?.workspace?.name === "special:minimized" ? null : Hypr.activeToplevel
    readonly property var minimizedWindows: windows.filter(w => w.workspace?.name === "special:minimized")
    readonly property int maxHeight: {
        const others = bar.children.filter(c => c.entryId && c.item !== root && c.entryId !== "spacer");
        const used = others.reduce((acc, curr) => acc + (curr.item?.nonAnimHeight ?? curr.height), 0);
        return Math.max(entrySize, bar.height - used - bar.spacing * (bar.children.length - 1) - bar.vPadding * 2);
    }

    implicitWidth: entrySize
    implicitHeight: Math.min(apps.implicitHeight, maxHeight)

    function selector(window): string {
        return JSON.stringify("address:" + window.lastIpcObject.address);
    }

    function isActive(window): bool {
        return window.workspace?.name !== "special:minimized" && window.lastIpcObject.address === selected?.lastIpcObject.address;
    }

    function minimize(window): void {
        if (window)
            Hypr.extras.message("eval caelestia_minimize_window(" + selector(window) + ")");
    }

    function restore(window): void {
        if (!window)
            return;
        Hypr.extras.message("eval caelestia_restore_window(" + selector(window) + ")");
    }

    function clickWindow(window): void {
        if (!window)
            return;
        bar.popouts.hasCurrent = false;
        if (window.workspace?.name === "special:minimized")
            restore(window);
        else if (isActive(window))
            minimize(window);
        else
            Hypr.dispatch('hl.dsp.focus({window=' + selector(window) + '})');
    }

    // Keep the existing keyboard shortcuts working without shared control buttons.
    IpcHandler {
        target: "windowControls"
        function minimize(): void { root.minimize(root.selected); }
        function restore(): void { root.restore(root.minimizedWindows[root.minimizedWindows.length - 1]); }
        function maximize(): void {
            if (root.selected)
                Hypr.extras.message("eval caelestia_toggle_maximize(" + root.selector(root.selected) + ")");
        }
        function close(): void { root.selected?.wayland?.close(); }
        function status(): string {
            return JSON.stringify({app: root.selected?.lastIpcObject.class ?? "", minimized: root.minimizedWindows.length});
        }
    }

    IpcHandler {
        target: "runningApps"
        function click(address: string): void {
            root.clickWindow(root.windows.find(w => w.lastIpcObject.address === address));
        }
        function list(): string {
            return JSON.stringify(root.windows.map(w => ({
                address: w.lastIpcObject.address,
                app: w.lastIpcObject.class,
                active: root.isActive(w),
                minimized: w.workspace?.name === "special:minimized",
                workspace: w.workspace?.id
            })));
        }
    }

    Flickable {
        id: scroll
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: apps.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height

        ScrollBar.vertical: ScrollBar {
            width: 3
            policy: ScrollBar.AsNeeded
        }

        Column {
            id: apps
            width: scroll.width
            spacing: 5

            Repeater {
                model: ScriptModel { values: root.windows }

                Rectangle {
                    id: entry
                    required property var modelData
                    readonly property bool minimized: modelData.workspace?.name === "special:minimized"
                    readonly property bool active: root.isActive(modelData)
                    readonly property string appIcon: {
                        const icon = DesktopEntries.heuristicLookup(modelData.lastIpcObject.class)?.icon;
                        return icon ? Quickshell.iconPath(icon, true) : "";
                    }
                    width: root.entrySize
                    height: root.entrySize
                    radius: 12
                    color: active ? Qt.alpha(Colours.palette.m3primary, 0.24) : mouse.containsMouse ? Qt.alpha(Colours.palette.m3onSurface, 0.10) : "transparent"
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.title || modelData.lastIpcObject.class
                    Accessible.onPressAction: root.clickWindow(modelData)

                    IconImage {
                        anchors.centerIn: parent
                        implicitSize: 24
                        asynchronous: true
                        source: entry.appIcon
                        visible: entry.appIcon.length > 0
                        opacity: entry.minimized ? 0.50 : 1
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        visible: entry.appIcon.length === 0
                        text: Icons.getAppCategoryIcon(entry.modelData.lastIpcObject.class, "desktop_windows")
                        color: entry.active ? Colours.palette.m3primary : Colours.palette.m3onSurface
                        opacity: entry.minimized ? 0.50 : 1
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3
                        height: entry.active ? 18 : 6
                        radius: 2
                        color: entry.active ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                        opacity: entry.minimized ? 0.45 : 1
                    }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.clickWindow(entry.modelData)
                        onWheel: event => {
                            if (scroll.contentHeight > scroll.height) {
                                scroll.contentY = Math.max(0, Math.min(scroll.contentHeight - scroll.height, scroll.contentY - event.angleDelta.y / 3));
                                event.accepted = true;
                            } else {
                                event.accepted = false;
                            }
                        }
                    }

                    ToolTip.visible: mouse.containsMouse
                    ToolTip.delay: 400
                    ToolTip.text: (modelData.title || modelData.lastIpcObject.class)
                        + (minimized ? " · Đã thu nhỏ" : "")
                }
            }
        }
    }
}
