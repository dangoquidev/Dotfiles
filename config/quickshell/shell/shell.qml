// Resident Quickshell instance, started by hypr autostart: `quickshell -c shell`
//   Osd             volume / mic / brightness pill
//   ClipboardPanel  clipboard history with image previews (SUPER+SHIFT+V)
//   EmojiPicker     emoji search & insert (SUPER+period)
// Driven over IPC, e.g. `quickshell -c shell ipc call clipboard toggle`.
// (The wallpaper carousel is a separate, on-demand config: ../wallpaper)

import Quickshell

ShellRoot {
    Osd {}
    ClipboardPanel {}
    EmojiPicker {}
}
