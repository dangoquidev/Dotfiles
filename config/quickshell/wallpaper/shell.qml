// Wallpaper carousel (launched by ~/.config/hypr/scripts/wallpaper.sh, SUPER+SHIFT+B)
//
//   ← / →, mouse wheel   rotate          Enter, click center   apply
//   click a side card     go to it        Esc, click outside    close
//
// Landscape cards in a looping row, each filled by its wallpaper: the selected one is
// centered, full size and on top; the others shrink, overlap and darken with distance.
// Layout inspired by the carousel in github.com/kianblakley/pibble.
//
// Input: $WALLPAPER_LIST, a JSON file written by wallpaper.sh:
//   { "current": 0, "walls": [ { "path": "/full/image.png", "thumb": "/cached/preview.jpg" }, … ] }
// Previews are made at exactly the card size (440x275, center-cropped) so nothing heavy is decoded here.
// Applying runs: $WALLPAPER_SCRIPT <path>

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

ShellRoot {
    id: shell

    // rice palette
    readonly property color base: "#1a1a2a"
    readonly property color pink: "#ff8fa3"

    property var walls: []
    property int startIndex: 0

    FileView {
        path: Quickshell.env("WALLPAPER_LIST")
        blockLoading: true
        onLoaded: {
            const data = JSON.parse(text());
            shell.walls = data.walls;
            shell.startIndex = data.current;
        }
    }

    PanelWindow {
        id: win

        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "wallpaper-carousel"

        property bool closing: false

        function close() {
            if (closing) return;
            closing = true;
            outAnim.start();
        }

        function apply(path) {
            // detached: keeps running after this window quits
            Quickshell.execDetached([Quickshell.env("WALLPAPER_SCRIPT"), path]);
            close();
        }

        // dimmed (not blurred) desktop; click outside the cards to close
        Rectangle {
            id: dim
            anchors.fill: parent
            color: shell.base
            opacity: 0
            MouseArea {
                anchors.fill: parent
                onClicked: win.close()
            }
        }

        Item {
            id: carousel

            // geometry (px)
            readonly property int n: shell.walls.length
            readonly property int barW: 440          // = preview size made by wallpaper.sh (PREVIEW_W/H)
            readonly property int barH: 275
            readonly property int slot: 370          // center-to-center distance at full scale (< barW: cards overlap)
            readonly property real floorScale: 0.64  // smallest a card gets
            readonly property real rate: 0.12        // shrink per step away from the center
            readonly property int halfVisible: 2     // cards shown on each side

            // Cards keep a constant visual overlap while they shrink: x(m) integrates the scaled widths.
            readonly property real edgeBreak: (1 - floorScale) / rate
            function edgeOffset(m) {
                if (m <= edgeBreak)
                    return slot * m - (barW * rate / 2) * m * m;
                const atBreak = slot * edgeBreak - (barW * rate / 2) * edgeBreak * edgeBreak;
                return atBreak + (slot - barW * (1 - floorScale)) * (m - edgeBreak);
            }

            // `sel` is an unbounded step counter (keeps the animation continuous across the
            // loop); `pos` follows it with an animation, cards are placed from `pos`.
            property int sel: 0
            property real pos: sel
            property bool ready: false
            Behavior on pos {
                enabled: carousel.ready
                NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
            }

            function wrap(i) { return ((i % n) + n) % n; }
            function current() { return shell.walls[wrap(sel)]; }

            width: 2 * edgeOffset(halfVisible) + barW
            height: barH
            anchors.centerIn: parent
            scale: 0.92
            opacity: 0

            focus: true
            Keys.onPressed: event => {
                switch (event.key) {
                case Qt.Key_Left: case Qt.Key_H: carousel.sel--; break;
                case Qt.Key_Right: case Qt.Key_L: carousel.sel++; break;
                case Qt.Key_Return: case Qt.Key_Enter: case Qt.Key_Space:
                    if (carousel.n) win.apply(carousel.current().path);
                    break;
                case Qt.Key_Escape: win.close(); break;
                default: return;
                }
                event.accepted = true;
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    const d = event.angleDelta.y !== 0 ? event.angleDelta.y : -event.angleDelta.x;
                    if (d < 0) carousel.sel++; else if (d > 0) carousel.sel--;
                }
            }

            Repeater {
                model: carousel.n

                Item {
                    id: card
                    required property int index

                    // signed distance to the center, wrapped into (-n/2, n/2] so the row loops
                    readonly property real rank: {
                        const n = carousel.n;
                        let r = (((index - carousel.pos) % n) + n) % n;
                        if (r > n / 2) r -= n;
                        return r;
                    }
                    readonly property real dist: Math.abs(rank)

                    width: carousel.barW
                    height: carousel.barH
                    x: carousel.width / 2 - width / 2 + Math.sign(rank) * carousel.edgeOffset(dist)
                    y: 0
                    z: 100 - dist
                    scale: Math.max(carousel.floorScale, 1 - dist * carousel.rate)
                    opacity: Math.max(0, Math.min(1, carousel.halfVisible + 1 - dist))
                    visible: opacity > 0

                    // pink ring hugging the selected card (filled, so no card behind shows through)
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -3
                        radius: 17
                        color: shell.base
                        border.color: shell.pink
                        border.width: 3
                        opacity: Math.max(0, 1 - card.dist * 2.5)
                    }

                    ClippingRectangle {
                        anchors.fill: parent
                        radius: 14
                        color: shell.base

                        // fills the card; previews are already cropped to its size
                        Image {
                            anchors.fill: parent
                            source: "file://" + shell.walls[card.index].thumb
                            sourceSize: Qt.size(carousel.barW, carousel.barH)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            smooth: true
                        }

                        // darker with distance
                        Rectangle {
                            anchors.fill: parent
                            color: shell.base
                            opacity: Math.min(0.65, card.dist * 0.3)
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (card.dist < 0.5)
                                win.apply(shell.walls[card.index].path);
                            else
                                carousel.sel += Math.round(card.rank);
                        }
                    }
                }
            }

            Component.onCompleted: {
                sel = shell.startIndex;
                ready = true;
                inAnim.start();
            }
        }

        ParallelAnimation {
            id: inAnim
            NumberAnimation { target: dim; property: "opacity"; to: 0.45; duration: 180; easing.type: Easing.OutCubic }
            NumberAnimation { target: carousel; property: "opacity"; to: 1; duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { target: carousel; property: "scale"; to: 1; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
        }

        SequentialAnimation {
            id: outAnim
            ParallelAnimation {
                NumberAnimation { target: dim; property: "opacity"; to: 0; duration: 160; easing.type: Easing.InCubic }
                NumberAnimation { target: carousel; property: "opacity"; to: 0; duration: 160; easing.type: Easing.InCubic }
                NumberAnimation { target: carousel; property: "scale"; to: 0.92; duration: 160; easing.type: Easing.InCubic }
            }
            ScriptAction { script: Qt.quit() }
        }
    }
}
