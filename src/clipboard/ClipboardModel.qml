import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root
    required property string backend
    required property string sessionKey
    property var thumbnails: ({})
    property var thumbnailQueue: []
    property string thumbnailId: ''
    property bool closing: false
    property bool refreshPending: false
    property var items: []
    property string query: ''
    property string category: 'All'
    property int selected: 0
    property bool loading: false
    property bool copying: false
    property string error: ''
    property string copyId: ''
    readonly property var filtered: items.filter(item => {
        const q = query.trim().toLowerCase();
        const kind = category === 'All' || (category === 'Text' && item.kind === 'text')
            || (category === 'Images' && item.kind === 'image') || (category === 'Links' && item.kind === 'link');
        return kind && (!q || item.preview.toLowerCase().includes(q));
    })
    readonly property var selectedEntry: filtered[selected] || null
    signal copied()
    signal closed()
    onSelectedEntryChanged: if (selectedEntry?.kind === 'image') requestThumbnail(selectedEntry.id, true)
    function requestThumbnail(id, priority = false) {
        if (closing || Object.prototype.hasOwnProperty.call(thumbnails, id) || thumbnailId === id && thumbnailProcess.running) return;
        const pending = thumbnailQueue.filter(value => value !== id);
        thumbnailQueue = priority ? [id, ...pending] : [...pending, id];
        nextThumbnail();
    }
    function nextThumbnail() {
        if (closing || thumbnailProcess.running || thumbnailQueue.length === 0) return;
        thumbnailId = thumbnailQueue[0]; thumbnailQueue = thumbnailQueue.slice(1);
        thumbnailProcess.running = true;
    }
    function shutdown() {
        if (closing || copying) return;
        closing = true;
        listProcess.running = false;
        thumbnailQueue = [];
        if (thumbnailProcess.running) thumbnailProcess.running = false;
        else cleanupProcess.running = true;
    }
    onFilteredChanged: selected = 0
    function move(delta) { selected = Math.max(0, Math.min(filtered.length - 1, selected + delta)); }
    function refresh() {
        if (listProcess.running || closing) return;
        if (thumbnailProcess.running) { refreshPending = true; return; }
        thumbnailQueue = []; thumbnails = {};
        items = []; loading = true; error = ''; listProcess.running = true;
    }
    function copy(index) {
        if (closing || copying || index < 0 || index >= filtered.length) return;
        selected = index; copyId = filtered[index].id; copying = true; error = ''; copyProcess.running = true;
    }
    Process {
        id: listProcess
        command: ['python3', root.backend, '--list']
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text);
                    root.items = result.ok ? result.items : [];
                    root.error = result.ok ? '' : result.error;
                } catch (error) { root.items = []; root.error = 'Could not load clipboard history'; }
                root.loading = false;
            }
        }
        stderr: StdioCollector {}
        onExited: if (root.loading) { root.loading = false; root.error = 'Could not load clipboard history'; }
    }
    Process {
        id: thumbnailProcess
        command: ['python3', root.backend, '--thumbnail', root.thumbnailId, '--session', root.sessionKey]
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.closing) return;
                let url = '';
                try { const result = JSON.parse(text); if (result.ok) url = result.url; } catch (error) {}
                root.thumbnails = Object.assign({}, root.thumbnails, {[root.thumbnailId]: url});
            }
        }
        stderr: StdioCollector {}
        onExited: {
            if (root.closing) cleanupProcess.running = true;
            else if (root.refreshPending) { root.refreshPending = false; Qt.callLater(root.refresh); }
            else Qt.callLater(root.nextThumbnail);
        }
    }
    Process {
        id: cleanupProcess
        command: ['python3', root.backend, '--cleanup', '--session', root.sessionKey]
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: root.closed()
    }
    Process {
        id: copyProcess
        command: ['python3', root.backend, '--copy', root.copyId]
        stdout: StdioCollector {
            onStreamFinished: {
                root.copying = false;
                try {
                    const result = JSON.parse(text);
                    if (result.ok) root.copied();
                    else root.error = result.error || 'Could not copy this item';
                } catch (error) { root.error = 'Could not copy this item'; }
            }
        }
        stderr: StdioCollector {}
        onExited: if (root.copying) { root.copying = false; root.error = 'Could not copy this item'; }
    }
}
