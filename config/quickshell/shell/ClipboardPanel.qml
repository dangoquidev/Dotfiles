// Clipboard history (cliphist) with real image previews.
//   `quickshell -c shell ipc call clipboard toggle` (SUPER+SHIFT+V)
//   type to search · ↑/↓ move · Enter or click copy · Shift+Del remove · Esc / click outside close

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: cb

    readonly property color base: "#1a1a2a"
    readonly property color surface: "#252535"
    readonly property color overlay: "#2a2a3a"
    readonly property color pink: "#ff8fa3"
    readonly property color text: "#e0def4"
    readonly property color subtext: "#a8a6c0"

    readonly property string script: Quickshell.env("HOME") + "/.config/quickshell/shell/scripts/clipboard.sh"

    property bool open: false
    property var entries: []        // [{ kind, id, data }]
    property bool loading: false

    function toggle() { open ? close() : show(); }

    function show() {
        search.text = "";
        entries = [];
        loading = true;
        listProc.running = true;
        open = true;
    }

    function close() { open = false; }

    function copy(entry) {
        Quickshell.execDetached([script, "copy", entry.id]);
        close();
    }

    function remove(entry) {
        Quickshell.execDetached([script, "delete", entry.id]);
        entries = entries.filter(e => e.id !== entry.id);
    }

    Process {
        id: listProc
        command: [cb.script, "list"]
        stdout: StdioCollector {
            id: listOut
            onStreamFinished: {
                const out = [];
                for (const line of listOut.text.split("\n")) {
                    const a = line.indexOf("\t"), b = line.indexOf("\t", a + 1);
                    if (a < 0 || b < 0) continue;
                    out.push({ kind: line.slice(0, a), id: line.slice(a + 1, b), data: line.slice(b + 1) });
                }
                cb.entries = out;
                cb.loading = false;
                list.currentIndex = 0;
            }
        }
    }

    IpcHandler {
        target: "clipboard"
        function toggle(): void { cb.toggle(); }
    }

    PanelWindow {
        visible: cb.open
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-clipboard"
        WlrLayershell.keyboardFocus: cb.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        // dim + click outside closes
        Rectangle {
            anchors.fill: parent
            color: cb.base
            opacity: 0.35
            MouseArea { anchors.fill: parent; onClicked: cb.close() }
        }

        Rectangle {
            id: panel
            width: 640
            height: 600
            anchors.centerIn: parent
            color: cb.base
            border.color: cb.pink
            border.width: 2

            // swallow clicks so they don't close the panel
            MouseArea { anchors.fill: parent }

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                // search
                Rectangle {
                    width: parent.width
                    height: 44
                    color: cb.surface
                    border.color: search.activeFocus ? cb.pink : cb.overlay
                    border.width: 2

                    Text {
                        id: searchIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰅌"
                        color: cb.pink
                        font.family: "Maple Mono NF CN"
                        font.pixelSize: 18
                    }

                    TextInput {
                        id: search
                        anchors.left: searchIcon.right
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        color: cb.text
                        selectionColor: cb.pink
                        font.family: "Maple Mono NF CN"
                        font.pixelSize: 15
                        focus: cb.open
                        onTextChanged: list.currentIndex = 0

                        Text {
                            anchors.fill: parent
                            text: "Search clipboard…"
                            color: cb.subtext
                            font: search.font
                            visible: !search.text
                        }

                        Keys.onPressed: event => {
                            const n = list.count;
                            if (event.key === Qt.Key_Escape) { cb.close(); }
                            else if (event.key === Qt.Key_Down) { list.currentIndex = Math.min(n - 1, list.currentIndex + 1); }
                            else if (event.key === Qt.Key_Up) { list.currentIndex = Math.max(0, list.currentIndex - 1); }
                            else if (event.key === Qt.Key_PageDown) { list.currentIndex = Math.min(n - 1, list.currentIndex + 5); }
                            else if (event.key === Qt.Key_PageUp) { list.currentIndex = Math.max(0, list.currentIndex - 5); }
                            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (n) cb.copy(list.model[list.currentIndex]);
                            }
                            else if (event.key === Qt.Key_Delete && (event.modifiers & Qt.ShiftModifier)) {
                                if (n) cb.remove(list.model[list.currentIndex]);
                            }
                            else return;
                            event.accepted = true;
                        }
                    }
                }

                ListView {
                    id: list
                    width: parent.width
                    height: parent.height - 44 - 12 - hint.height - 12
                    clip: true
                    spacing: 6
                    boundsBehavior: Flickable.StopAtBounds
                    highlightMoveDuration: 120
                    model: {
                        const q = search.text.toLowerCase();
                        return q ? cb.entries.filter(e => e.kind === "text" && e.data.toLowerCase().includes(q))
                                 : cb.entries;
                    }

                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool selected: ListView.isCurrentItem

                        width: list.width
                        height: modelData.kind === "image" ? 136 : Math.max(44, label.implicitHeight + 20)
                        color: selected ? cb.overlay : cb.surface
                        border.color: selected ? cb.pink : "transparent"
                        border.width: 2

                        Text {
                            id: label
                            visible: row.modelData.kind === "text"
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            text: row.modelData.kind === "text" ? row.modelData.data : ""
                            color: cb.text
                            font.family: "Maple Mono NF CN"
                            font.pixelSize: 13
                            wrapMode: Text.WrapAnywhere
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }

                        Image {
                            visible: row.modelData.kind === "image"
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.margins: 8
                            width: 180
                            source: row.modelData.kind === "image" ? "file://" + row.modelData.data : ""
                            fillMode: Image.PreserveAspectFit
                            horizontalAlignment: Image.AlignLeft
                            asynchronous: true
                            sourceSize.width: 360
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: list.currentIndex = row.index
                            onClicked: cb.copy(row.modelData)
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: list.count === 0
                        text: cb.loading ? "Loading…" : search.text ? "No match" : "Clipboard history is empty"
                        color: cb.subtext
                        font.family: "Maple Mono NF CN"
                        font.pixelSize: 14
                    }
                }

                Text {
                    id: hint
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: "Enter copy  ·  Shift+Del remove  ·  Esc close"
                    color: cb.subtext
                    font.family: "Maple Mono NF CN"
                    font.pixelSize: 12
                }
            }
        }
    }
}
