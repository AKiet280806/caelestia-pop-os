pragma Singleton

import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property bool enabled: true

    function toggle(): void {
        enabled = !enabled;
        storage.setText(JSON.stringify({enabled: enabled}));
    }

    FileView {
        id: storage
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/caelestia/popup-hover.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const data = JSON.parse(text());
                if (typeof data.enabled === "boolean")
                    root.enabled = data.enabled;
            } catch (error) {}
        }
    }

    IpcHandler {
        target: "popupHover"
        function toggle(): void { root.toggle(); }
        function status(): bool { return root.enabled; }
    }
}
