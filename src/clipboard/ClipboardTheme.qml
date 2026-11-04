import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root
    property bool translucent: true
    property real panelAlpha: 0.75
    property real cardAlpha: 0.6
    property var colours: ({})
    function colour(name, fallback) { return '#' + (colours[name] || fallback); }
    readonly property color surface: colour('surfaceContainer', '282a36')
    readonly property color low: colour('surfaceContainerLow', '21222c')
    readonly property color high: colour('surfaceContainerHigh', '44475a')
    readonly property color text: colour('onSurface', 'f8f8f2')
    readonly property color muted: colour('onSurfaceVariant', 'c4c4d0')
    readonly property color outline: colour('outlineVariant', '44475a')
    readonly property color primary: colour('primary', 'bd93f9')
    readonly property color onPrimary: colour('onPrimary', '282a36')
    readonly property color error: colour('error', 'ff5555')
    FileView {
        path: (Quickshell.env('XDG_CONFIG_HOME') || Quickshell.env('HOME') + '/.config') + '/caelestia/shell.json'
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const transparency = JSON.parse(text()).appearance?.transparency || {};
                root.translucent = transparency.enabled !== false;
                root.panelAlpha = root.translucent ? Math.max(0.2, Math.min(1, transparency.base ?? 0.75)) : 1;
                root.cardAlpha = root.translucent ? Math.max(0.2, Math.min(1, transparency.layers ?? 0.6)) : 1;
            } catch (error) { root.panelAlpha = 0.9; root.cardAlpha = 0.7; }
        }
    }
    FileView {
        path: (Quickshell.env('XDG_STATE_HOME') || Quickshell.env('HOME') + '/.local/state') + '/caelestia/scheme.json'
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try { root.colours = JSON.parse(text()).colours || {}; }
            catch (error) { root.colours = {}; }
        }
    }
}
