#Requires AutoHotkey v2.0

; ---------------------------------------------------------------------------
; Single source of truth for the user-facing hotkey reference.
;
; The cheatsheet overlay (UI\Cheatsheet.ahk) and the shortcut table in
; README.md are both derived from this list, so adding a binding only means:
;   1. add the hotkey in Hotkeys\HotkeyBindings.ahk
;   2. add / update the matching entry below
;
; Entry fields
;   cat    - language key of the category (grouping + column 1)
;   keys   - display string for the "Shortcut" column
;   desc   - language key of the one-line description (column 3)
;   action - optional lambda executed when the row is double-clicked.
;            Use "" for bindings that have no standalone function
;            (they are inline Send() definitions and stay reference-only).
; ---------------------------------------------------------------------------
class HotkeyReference {
    static Entries() {
        return [
            { cat: "CHEAT_CAT_NATIVE", keys: "CapsLock ×2", desc: "CHEAT_ACT_CAPS_TOGGLE", action: "" },

            { cat: "CHEAT_CAT_NAV", keys: "CapsLock + J", desc: "CHEAT_ACT_GOTO_LINE", action: ((*) => JumpToLine()) },

            { cat: "CHEAT_CAT_SELECTION", keys: "CapsLock + Shift + ← / →", desc: "CHEAT_ACT_SEL_WORD", action: "" },
            { cat: "CHEAT_CAT_SELECTION", keys: "CapsLock + Shift + ↑ / ↓", desc: "CHEAT_ACT_SEL_LINE", action: "" },
            { cat: "CHEAT_CAT_SELECTION", keys: "CapsLock + Space", desc: "CHEAT_ACT_SEL_CURRENT", action: "" },

            { cat: "CHEAT_CAT_EDIT", keys: "CapsLock + A / D", desc: "CHEAT_ACT_DEL_CHAR", action: "" },
            { cat: "CHEAT_CAT_EDIT", keys: "CapsLock + Shift + A / D", desc: "CHEAT_ACT_DEL_WORD", action: "" },
            { cat: "CHEAT_CAT_EDIT", keys: "CapsLock + Backspace / Delete", desc: "CHEAT_ACT_DEL_LINE", action: "" },

            { cat: "CHEAT_CAT_CLIPBOARD", keys: "CapsLock + C", desc: "CHEAT_ACT_COPY_PLAIN", action: ((*) => CopyAsPlainTextAndAddToHistory()) },
            { cat: "CHEAT_CAT_CLIPBOARD", keys: "CapsLock + V", desc: "CHEAT_ACT_PASTE", action: ((*) => PasteWithCurrentMode()) },
            { cat: "CHEAT_CAT_CLIPBOARD", keys: "CapsLock + Shift + V", desc: "CHEAT_ACT_HISTORY", action: ((*) => ShowHistoryMenu()) },
            { cat: "CHEAT_CAT_CLIPBOARD", keys: "CapsLock + F", desc: "CHEAT_ACT_CASE", action: ((*) => ChangeCaseOfLastCopy()) },

            { cat: "CHEAT_CAT_DOCUMENTS", keys: "CapsLock + P", desc: "CHEAT_ACT_PANDOC", action: ((*) => ConvertWithPandoc()) },
            { cat: "CHEAT_CAT_CLIPBOARD", keys: "CapsLock + Shift + P", desc: "CHEAT_ACT_QUICK_PHRASE", descDefault: "Open the Quick Phrase selector", action: ((*) => QuickPhraseHandleHotkey()) },

            { cat: "CHEAT_CAT_FILES", keys: "CapsLock + Alt + Q", desc: "CHEAT_ACT_TEMP", action: ((*) => OpenTempFolder()) },

            { cat: "CHEAT_CAT_WINDOW", keys: "CapsLock + T", desc: "CHEAT_ACT_TOPMOST", action: ((*) => ToggleAlwaysOnTopWithOSD()) },
            { cat: "CHEAT_CAT_WINDOW", keys: "CapsLock + K", desc: "CHEAT_ACT_KILL_PROCESS", action: ((*) => TerminateProcessByPid()) },
            { cat: "CHEAT_CAT_WINDOW", keys: "CapsLock + L", desc: "CHEAT_ACT_WINDOW_SWITCH", action: ((*) => WindowSwitcherGui.Show()) },
            { cat: "CHEAT_CAT_WINDOW", keys: "CapsLock + W / 8", desc: "CHEAT_ACT_MAXIMIZE", action: "" },
            { cat: "CHEAT_CAT_WINDOW", keys: "CapsLock + S / 2", desc: "CHEAT_ACT_MINIMIZE", action: "" },
            { cat: "CHEAT_CAT_WINDOW", keys: "CapsLock + Shift + W / 8", desc: "CHEAT_ACT_BORDERLESS", action: ((*) => WindowFullScreen.Toggle()) },
            { cat: "CHEAT_CAT_WINDOW", keys: "CapsLock + Shift + S / 2", desc: "CHEAT_ACT_HIDE_TRAY", action: ((*) => TrayHider.HideActive()) },
            { cat: "CHEAT_CAT_WINDOW", keys: "CapsLock + Left / Right Button", desc: "CHEAT_ACT_OPACITY", action: "" },
            { cat: "CHEAT_CAT_WINDOW", keys: "CapsLock + Middle Button", desc: "CHEAT_ACT_GHOST", action: "" },
            { cat: "CHEAT_CAT_WINDOW", keys: "CapsLock + X", desc: "CHEAT_ACT_WINDOW_HOLE", action: ((*) => WindowHole.Toggle()) },
            { cat: "CHEAT_CAT_WINDOW", keys: "CapsLock + X, then 1", desc: "CHEAT_ACT_WINDOW_HOLE_SECOND", action: "" },

            { cat: "CHEAT_CAT_TABS", keys: "CapsLock + Q / E", desc: "CHEAT_ACT_TAB_PREV_NEXT", action: "" },

            { cat: "CHEAT_CAT_HELP", keys: "CapsLock + H / F1", desc: "CHEAT_ACT_CHEATSHEET", action: "" }
        ]
    }
}
