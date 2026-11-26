// Emoji picker (SUPER+period): `quickshell -c shell ipc call emoji toggle`
//   type to search by name (Unicode names, English) · arrows move · Enter / click insert · Esc close
// Inserting copies the emoji and, if wtype is installed, types it into the focused window.
// Data: /usr/share/unicode/emoji/emoji-test.txt (package unicode-emoji). Recent picks come first
// and are kept in ~/.local/state/quickshell/emoji-recent.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: ep

    readonly property color base: "#1a1a2a"
    readonly property color surface: "#252535"
    readonly property color overlay: "#2a2a3a"
    readonly property color pink: "#ff8fa3"
    readonly property color text: "#e0def4"
    readonly property color subtext: "#a8a6c0"
    readonly property string font: "Maple Mono NF CN"

    readonly property string recentFile: Quickshell.env("HOME") + "/.local/state/quickshell/emoji-recent"
    readonly property int maxRecent: 24

    property bool open: false
    property var all: []        // [{ e, name, group }]
    property var recent: []     // [emoji]

    function toggle() { open ? close() : show(); }
    function show() { search.text = ""; grid.currentIndex = 0; open = true; }
    function close() { open = false; }

    function pick(item) {
        const r = [item.e].concat(recent.filter(x => x !== item.e)).slice(0, maxRecent);
        recent = r;
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf "%s" "$2" > "$1"',
                                 "sh", recentFile, r.join("\n")]);
        close();
        // copy, then type it once focus is back on the previous window
        Quickshell.execDetached(["sh", "-c",
            'printf "%s" "$1" | wl-copy; command -v wtype >/dev/null && sleep 0.15 && wtype -- "$1"', "sh", item.e]);
    }

    // --- data -------------------------------------------------------------------
    FileView {
        path: "/usr/share/unicode/emoji/emoji-test.txt"
        blockLoading: true
        onLoaded: {
            const out = [];
            let group = "";
            for (const line of text().split("\n")) {
                if (line.startsWith("# group: ")) { group = line.slice(9); continue; }
                if (line.indexOf("; fully-qualified") < 0) continue;
                const rest = line.slice(line.indexOf("#") + 2);          // "😀 E1.0 grinning face"
                const sp1 = rest.indexOf(" "), sp2 = rest.indexOf(" ", sp1 + 1);
                const name = rest.slice(sp2 + 1);
                if (name.indexOf("skin tone") >= 0) continue;            // base emoji only
                out.push({ e: rest.slice(0, sp1), name: name, group: group });
            }
            ep.all = out;
        }
    }

    FileView {
        path: ep.recentFile
        blockLoading: true
        onLoaded: ep.recent = text().split("\n").filter(x => x.length)
    }

    IpcHandler {
        target: "emoji"
        function toggle(): void { ep.toggle(); }
    }

    // --- window -----------------------------------------------------------------
    PanelWindow {
        visible: ep.open
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-emoji"
        WlrLayershell.keyboardFocus: ep.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Rectangle {
            anchors.fill: parent
            color: ep.base
            opacity: 0.35
            MouseArea { anchors.fill: parent; onClicked: ep.close() }
        }

        Rectangle {
            width: 600
            height: 520
            anchors.centerIn: parent
            color: ep.base
            border.color: ep.pink
            border.width: 2

            MouseArea { anchors.fill: parent }   // keep clicks inside

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                Rectangle {
                    width: parent.width
                    height: 44
                    color: ep.surface
                    border.color: ep.pink
                    border.width: 2

                    Text {
                        id: icon
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰞅"
                        color: ep.pink
                        font.family: ep.font
                        font.pixelSize: 18
                    }

                    TextInput {
                        id: search
                        anchors.left: icon.right
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        color: ep.text
                        selectionColor: ep.pink
                        font.family: ep.font
                        font.pixelSize: 15
                        focus: ep.open
                        onTextChanged: grid.currentIndex = 0

                        Text {
                            anchors.fill: parent
                            text: "Search emoji…  (smile, heart, cat, fire…)"
                            color: ep.subtext
                            font: search.font
                            visible: !search.text
                        }

                        Keys.onPressed: event => {
                            const n = grid.count, cols = grid.columns;
                            let i = grid.currentIndex;
                            switch (event.key) {
                            case Qt.Key_Escape: ep.close(); break;
                            case Qt.Key_Right: i = Math.min(n - 1, i + 1); break;
                            case Qt.Key_Left: i = Math.max(0, i - 1); break;
                            case Qt.Key_Down: i = Math.min(n - 1, i + cols); break;
                            case Qt.Key_Up: i = Math.max(0, i - cols); break;
                            case Qt.Key_Return: case Qt.Key_Enter:
                                if (n) ep.pick(grid.model[i]);
                                break;
                            default: return;
                            }
                            grid.currentIndex = i;
                            event.accepted = true;
                        }
                    }
                }

                GridView {
                    id: grid
                    readonly property int columns: Math.floor(width / cellWidth)
                    width: parent.width
                    height: parent.height - 44 - 12 - footer.height - 12
                    cellWidth: 56
                    cellHeight: 56
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    highlightMoveDuration: 0
                    model: {
                        const q = search.text.trim().toLowerCase();
                        if (q) {
                            const words = q.split(/\s+/);
                            return ep.all.filter(x => {
                                const hay = (x.name + " " + x.group).toLowerCase();
                                return words.every(w => hay.includes(w));
                            });
                        }
                        const byChar = {};
                        for (const x of ep.all) byChar[x.e] = x;
                        const rec = ep.recent.map(e => byChar[e]).filter(x => x);
                        const recSet = new Set(ep.recent);
                        return rec.concat(ep.all.filter(x => !recSet.has(x.e)));
                    }

                    delegate: Rectangle {
                        id: cell
                        required property var modelData
                        required property int index
                        readonly property bool selected: GridView.isCurrentItem
                        width: 52
                        height: 52
                        color: selected ? ep.overlay : "transparent"
                        border.color: selected ? ep.pink : "transparent"
                        border.width: 2

                        Text {
                            anchors.centerIn: parent
                            text: cell.modelData.e
                            font.family: "Noto Color Emoji"
                            font.pixelSize: 28
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: grid.currentIndex = cell.index
                            onClicked: ep.pick(cell.modelData)
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: grid.count === 0
                        text: ep.all.length ? "No emoji found" : "Install unicode-emoji for the emoji list"
                        color: ep.subtext
                        font.family: ep.font
                        font.pixelSize: 14
                    }
                }

                // selected emoji name
                Text {
                    id: footer
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: grid.count && grid.currentIndex >= 0
                          ? grid.model[grid.currentIndex].name + "   ·   Enter insert  ·  Esc close"
                          : "Enter insert  ·  Esc close"
                    color: ep.subtext
                    font.family: ep.font
                    font.pixelSize: 12
                }
            }
        }
    }
}
