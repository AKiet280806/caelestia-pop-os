pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Singleton {
    id: root

    property var data: ({provider: "codex", name: "Codex", status: "loading", windows: [], providers: [], details: []})
    property string pendingProvider: ""
    readonly property string backendPath: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/caelestia-pop-os/ai-usage/ai_usage.py"
    readonly property bool hasData: Number(data.updated_at) > 0
    readonly property bool stale: data.status !== "ok" || (hasData && Time.date.getTime() / 1000 - Number(data.updated_at) > 180)
    readonly property bool selecting: selectionProc.running || pendingProvider.length > 0
    readonly property bool refreshing: !!data.refreshing || refreshProc.running || selecting
    readonly property var windows: Array.isArray(data.windows) ? data.windows : []
    readonly property var sidebarWindows: windows.length ? windows.slice(0, 2) : (details.length ? [] : [null])
    readonly property var providers: Array.isArray(data.providers) && data.providers.length ? data.providers : [{id: data.provider || "codex", name: data.name || "Codex"}]
    readonly property var details: Array.isArray(data.details) ? data.details : []
    readonly property var sidebarDetails: windows.length ? [] : details.slice(0, 1)
    readonly property string providerName: data.name || data.provider || "Codex"
    function providerIcon(provider: string): url {
        const known = ["codex", "openai", "claude", "antigravity", "copilot", "opencode", "zai", "kimi", "kilo", "deepseek", "cursor", "gemini", "grok"];
        return Qt.resolvedUrl("../assets/ai-providers/" + (known.includes(provider) ? provider : "codex") + ".svg");
    }

    function remaining(window): real {
        const used = window?.used_percent;
        return typeof used === "number" && isFinite(used) ? Math.max(0, Math.min(100, 100 - used)) : -1;
    }
    function percentage(window): string {
        const value = remaining(window);
        return value >= 0 ? Math.round(value) + "%" : "Unknown";
    }
    function windowName(window): string {
        if (window?.label) return window.label;
        const minutes = Number(window?.window_minutes);
        if (minutes > 0) {
            if (minutes < 60) return minutes + " minutes";
            if (minutes < 1440) return Math.round(minutes / 60 * 10) / 10 + " hours";
            return Math.round(minutes / 1440 * 10) / 10 + " days";
        }
        return "Usage";
    }
    function compactWindowName(window): string {
        // Provider labels take precedence: providers may report named limits without a duration.
        if (window?.label) return window.label;
        const minutes = Number(window?.window_minutes);
        if (!(minutes > 0)) return "Usage";
        if (minutes < 60) return minutes + "m";
        if (minutes < 1440) return Math.round(minutes / 60 * 10) / 10 + "h";
        return Math.round(minutes / 1440 * 10) / 10 + "d";
    }
    function resetText(window): string {
        const reset = Number(window?.resets_at);
        if (!(reset > 0)) return "Reset time unavailable";
        return "Resets " + Qt.formatDateTime(new Date(reset * 1000), "HH:mm · dd/MM");
    }
    function needsSetup(): bool {
        return ["sign_in_required", "login_required", "client_missing", "provider_missing", "not_configured", "credentials_missing", "config_missing"].includes(data.reason ?? data.status);
    }
    function statusText(): string {
        if (selecting || data.status === "loading") return "Loading " + providerName + " usage…";
        if (refreshing) return "Refreshing…";
        if (needsSetup()) return "Set up " + providerName + " to view usage";
        if (data.reason === "unsupported_source") return "This usage source is unavailable on Linux";
        if (["service_unavailable", "helper_unavailable"].includes(data.reason)) return "The usage service is unavailable";
        if (data.reason === "timeout") return "Provider timed out · retrying";
        if (data.status === "ok" && stale) return "Stale data · waiting for an update";
        if (data.status === "ok") return "Updates every minute";
        if (data.reason === "offline") return hasData ? "Stale data · update failed" : "Provider is currently unreachable";
        return hasData ? "Stale data · refresh unavailable" : "Usage data unavailable";
    }
    function refresh(): void {
        if (refreshing) return;
        data = Object.assign({}, data, {refreshing: true});
        refreshProc.running = true;
    }
    function select(provider: string): void {
        if (selectionProc.running || !providers.some(item => item.id === provider)) return;
        if (!pendingProvider && provider === data.provider) return;
        const entry = providers.find(item => item.id === provider);
        pendingProvider = provider;
        // Never show the previous provider's limits under the newly selected provider.
        data = {provider: provider, name: entry.name, status: "loading", windows: [], details: [], providers: providers, refreshing: true};
        selectionProc.command = ["python3", backendPath, "--select", provider];
        selectionProc.running = true;
    }
    function helperFailed(): void {
        pendingProvider = "";
        data = Object.assign({}, data, {status: hasData ? "stale" : "unavailable", reason: "helper_unavailable", refreshing: false});
    }

    FileView {
        id: cache
        path: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/caelestia/ai-usage.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const next = JSON.parse(text());
                if (!next || typeof next !== "object" || !next.provider) throw new Error("Invalid usage cache");
                if (root.pendingProvider && next.provider !== root.pendingProvider) return;
                root.pendingProvider = "";
                root.data = next;
            } catch (error) {
                root.data = Object.assign({}, root.data, {status: root.hasData ? "stale" : "unavailable", reason: "cache_unavailable", refreshing: false});
            }
        }
        onLoadFailed: root.data = Object.assign({}, root.data, {status: root.hasData ? "stale" : "unavailable", reason: "cache_unavailable", refreshing: false})
    }
    Process {
        id: selectionProc
        onExited: exitCode => { // qmllint disable signal-handler-parameters
            if (exitCode !== 0) root.helperFailed();
            else cache.reload();
        }
    }
    Process {
        id: refreshProc
        command: ["python3", root.backendPath, "--refresh"]
        onExited: exitCode => { // qmllint disable signal-handler-parameters
            if (exitCode !== 0) root.helperFailed();
            else cache.reload();
        }
    }
    IpcHandler {
        target: "aiUsage"
        function refresh(): void { root.refresh(); }
        function select(provider: string): void { root.select(provider); }
        function status(): string {
            return JSON.stringify({provider: root.data.provider, status: root.data.status, stale: root.stale, refreshing: root.refreshing, windowCount: root.windows.length});
        }
    }
}
