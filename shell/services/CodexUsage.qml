pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Singleton {
    id: root
    property var data: ({status: "loading", primary: null, secondary: null})
    readonly property bool hasData: !!data.updated_at
    readonly property bool stale: data.status !== "ok" || (hasData && Time.date.getTime() / 1000 - data.updated_at > 180)
    readonly property var windows: [data.primary ?? null, data.secondary ?? null]

    function remaining(window): real {
        return window ? Math.max(0, 100 - window.used_percent) : -1;
    }
    function percentage(window): string {
        return window ? Math.round(remaining(window)) + "%" : "—";
    }
    function windowName(window, index): string {
        const minutes = window?.window_minutes;
        if (minutes === 300) return "5 hours";
        if (minutes === 10080) return "Weekly";
        if (minutes) return minutes < 1440 ? Math.round(minutes / 60) + " hours" : Math.round(minutes / 1440) + " days";
        return index === 0 ? "Short-term" : "Long-term";
    }
    function resetText(window): string {
        if (!window?.resets_at) return "Resets time unavailable";
        return "Resets " + Qt.formatDateTime(new Date(window.resets_at * 1000), "HH:mm · dd/MM");
    }
    function statusText(): string {
        if (data.status === "ok" && stale) return "Stale data · waiting for an update";
        switch (data.reason ?? data.status) {
        case "sign_in_required": return "Sign in to Codex on this device";
        case "client_missing": return "Codex CLI is not available";
        case "offline": return hasData ? "Stale data · update failed" : "Cannot reach Codex";
        case "loading": return "Loading usage…";
        default: return data.refreshing ? "Refreshing…" : "Updates every minute";
        }
    }
    function refresh(): void {
        refreshProc.running = true;
    }

    FileView {
        path: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/caelestia/codex-usage.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try { root.data = JSON.parse(text()); }
            catch (error) { root.data = Object.assign({}, root.data, {status: "stale", reason: "offline"}); }
        }
        onLoadFailed: root.data = Object.assign({}, root.data, {status: root.hasData ? "stale" : "loading", reason: root.hasData ? "offline" : "loading"})
    }
    Process {
        id: refreshProc
        command: ["systemctl", "--user", "kill", "--kill-whom=main", "--signal=USR1", "caelestia-codex-usage.service"]
    }
    IpcHandler {
        target: "codexUsage"
        function refresh(): void { root.refresh(); }
        function status(): string { return JSON.stringify(root.data); }
    }
}
