// Volume / microphone / brightness on-screen display: a small pill at the bottom of the screen.
//   volume, mute, mic mute: followed live through PipeWire (keys, waybar scroll, pavucontrol…)
//   brightness: shown by `quickshell -c shell ipc call osd brightness` (brightness keys, waybar scroll)
// Click-through, hides itself after a moment.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland

Scope {
    id: osd

    readonly property color base: "#1a1a2a"
    readonly property color surface: "#2a2a3a"
    readonly property color pink: "#ff8fa3"
    readonly property color text: "#e0def4"
    readonly property color muted: "#6a6880"

    // what is displayed
    property string icon: ""
    property real value: 0          // 0..1 (can go above 1 for volume boost)
    property bool off: false        // muted
    property bool shown: false

    // ignore the burst of PipeWire "changes" while the shell starts
    property bool armed: false
    Timer { running: true; interval: 1500; onTriggered: osd.armed = true }

    Timer { id: hideTimer; interval: 1400; onTriggered: osd.shown = false }

    function show(icon, value, off) {
        if (!armed) return;
        osd.icon = icon;
        osd.value = value;
        osd.off = off;
        osd.shown = true;
        hideTimer.restart();
    }

    // --- volume & mic (PipeWire) ---------------------------------------------
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [osd.sink, osd.source] }

    function showVolume() {
        if (!sink || !sink.audio) return;
        const v = sink.audio.volume;
        const m = sink.audio.muted;
        show(m ? "󰝟" : v < 0.34 ? "󰕿" : v < 0.67 ? "󰖀" : "󰕾", v, m);
    }

    Connections {
        target: osd.sink ? osd.sink.audio : null
        function onVolumeChanged() { osd.showVolume(); }
        function onMutedChanged() { osd.showVolume(); }
    }

    Connections {
        target: osd.source ? osd.source.audio : null
        function onMutedChanged() {
            const m = osd.source.audio.muted;
            osd.show(m ? "󰍭" : "󰍬", m ? 0 : osd.source.audio.volume, m);
        }
    }

    // --- brightness (IPC) ----------------------------------------------------
    Process {
        id: brightnessProc
        command: ["brightnessctl", "-m"]   // name,class,current,percent%,max
        stdout: StdioCollector {
            id: brightnessOut
            onStreamFinished: {
                const f = brightnessOut.text.trim().split(",");
                const pct = parseInt(f[3]) / 100;
                if (!isNaN(pct)) osd.show(pct < 0.34 ? "󰃞" : pct < 0.67 ? "󰃟" : "󰃠", pct, false);
            }
        }
    }

    IpcHandler {
        target: "osd"
        function brightness(): void { brightnessProc.running = true; }
        function volume(): void { osd.showVolume(); }
    }

    // --- the pill --------------------------------------------------------------
    PanelWindow {
        id: win
        visible: osd.shown || pill.opacity > 0
        anchors.bottom: true
        margins.bottom: 90
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: 320
        implicitHeight: 56
        color: "transparent"
        mask: Region {}                       // click-through
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-osd"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Rectangle {
            id: pill
            anchors.fill: parent
            color: Qt.rgba(26 / 255, 26 / 255, 42 / 255, 0.92)
            border.color: osd.pink
            border.width: 2
            radius: 0

            opacity: osd.shown ? 1 : 0
            scale: osd.shown ? 1 : 0.92
            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

            Row {
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                spacing: 14

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26
                    text: osd.icon
                    color: osd.off ? osd.muted : osd.pink
                    font.family: "Maple Mono NF CN"
                    font.pixelSize: 22
                    horizontalAlignment: Text.AlignHCenter
                }

                // bar
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 26 - 52 - 2 * parent.spacing
                    height: 8
                    color: osd.surface

                    Rectangle {
                        height: parent.height
                        width: parent.width * Math.min(1, osd.value)
                        color: osd.off ? osd.muted : osd.pink
                        Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 52
                    text: osd.off ? "muted" : Math.round(osd.value * 100) + "%"
                    color: osd.off ? osd.muted : osd.text
                    font.family: "Maple Mono NF CN"
                    font.pixelSize: 15
                    font.bold: true
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }
}
