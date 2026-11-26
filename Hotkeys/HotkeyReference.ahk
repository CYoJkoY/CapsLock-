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
            ; Native behavior and navigation
            {
                cat: "CHEAT_CAT_NATIVE",
                keys: "CapsLock ×2",
                desc: "CHEAT_ACT_CAPS_TOGGLE",
                action: ""
            },
            {
                cat: "CHEAT_CAT_NAV",
                keys: HotkeyRegistry.GetDisplayKey("gotoLine"),
                desc: "CHEAT_ACT_GOTO_LINE",
                action: ((*) => JumpToLine())
            },

            ; Text selection
            {
                cat: "CHEAT_CAT_SELECTION",
                keys: HotkeyRegistry.GetDisplayKeys(["selectWordLeft", "selectWordRight"]),
                desc: "CHEAT_ACT_SEL_WORD",
                action: ""
            },
            {
                cat: "CHEAT_CAT_SELECTION",
                keys: HotkeyRegistry.GetDisplayKeys(["selectLineUp", "selectLineDown"]),
                desc: "CHEAT_ACT_SEL_LINE",
                action: ""
            },
            {
                cat: "CHEAT_CAT_SELECTION",
                keys: HotkeyRegistry.GetDisplayKey("selectCurrent"),
                desc: "CHEAT_ACT_SEL_CURRENT",
                action: ""
            },

            ; Text editing
            {
                cat: "CHEAT_CAT_EDIT",
                keys: HotkeyRegistry.GetDisplayKeys(["deletePreviousChar", "deleteNextChar"]),
                desc: "CHEAT_ACT_DEL_CHAR",
                action: ""
            },
            {
                cat: "CHEAT_CAT_EDIT",
                keys: HotkeyRegistry.GetDisplayKeys(["deletePreviousWord", "deleteNextWord"]),
                desc: "CHEAT_ACT_DEL_WORD",
                action: ""
            },
            {
                cat: "CHEAT_CAT_EDIT",
                keys: HotkeyRegistry.GetDisplayKeys(["deleteLineBackspace", "deleteLine"]),
                desc: "CHEAT_ACT_DEL_LINE",
                action: ""
            },

            ; Clipboard operations
            {
                cat: "CHEAT_CAT_CLIPBOARD",
                keys: HotkeyRegistry.GetDisplayKey("copyPlain"),
                desc: "CHEAT_ACT_COPY_PLAIN",
                action: ((*) => CopyAsPlainTextAndAddToHistory())
            },
            {
                cat: "CHEAT_CAT_CLIPBOARD",
                keys: HotkeyRegistry.GetDisplayKey("paste"),
                desc: "CHEAT_ACT_PASTE",
                action: ((*) => PasteWithCurrentMode())
            },
            {
                cat: "CHEAT_CAT_CLIPBOARD",
                keys: HotkeyRegistry.GetDisplayKey("historyMenu"),
                desc: "CHEAT_ACT_HISTORY",
                action: ((*) => ShowHistoryMenu())
            },
            {
                cat: "CHEAT_CAT_CLIPBOARD",
                keys: HotkeyRegistry.GetDisplayKey("changeCase"),
                desc: "CHEAT_ACT_CASE",
                action: ((*) => ChangeCaseOfLastCopy())
            },

            ; Document conversion
            {
                cat: "CHEAT_CAT_DOCUMENTS",
                keys: HotkeyRegistry.GetDisplayKey("pandoc"),
                desc: "CHEAT_ACT_PANDOC",
                action: ((*) => ConvertWithPandoc())
            },

            ; Quick Phrase
            {
                cat: "CHEAT_CAT_CLIPBOARD",
                keys: HotkeyRegistry.GetDisplayKey("quickPhrase"),
                desc: "CHEAT_ACT_QUICK_PHRASE",
                descDefault: "Open the Quick Phrase selector",
                action: ((*) => QuickPhraseHandleHotkey())
            },

            ; File tools
            {
                cat: "CHEAT_CAT_FILES",
                keys: HotkeyRegistry.GetDisplayKey("tempFolder"),
                desc: "CHEAT_ACT_TEMP",
                action: ((*) => OpenTempFolder())
            },
            {
                cat: "CHEAT_CAT_FILES",
                keys: HotkeyRegistry.GetDisplayKey("fileDelete"),
                desc: "CHEAT_ACT_DELETE_FILE",
                action: ((*) => FileDeleter.ConfirmDelete())
            },

            ; Window management
            {
                cat: "CHEAT_CAT_WINDOW",
                keys: HotkeyRegistry.GetDisplayKey("alwaysOnTop"),
                desc: "CHEAT_ACT_TOPMOST",
                action: ((*) => ToggleAlwaysOnTopWithOSD())
            },
            {
                cat: "CHEAT_CAT_WINDOW",
                keys: HotkeyRegistry.GetDisplayKey("killProcess"),
                desc: "CHEAT_ACT_KILL_PROCESS",
                action: ((*) => TerminateProcessByPid())
            },
            {
                cat: "CHEAT_CAT_WINDOW",
                keys: HotkeyRegistry.GetDisplayKey("windowSwitcher"),
                desc: "CHEAT_ACT_WINDOW_SWITCH",
                action: ((*) => WindowSwitcherGui.Show())
            },
            {
                cat: "CHEAT_CAT_WINDOW",
                keys: HotkeyRegistry.GetDisplayKeys(["maximize", "maximize8", "maximizeNum8"]),
                desc: "CHEAT_ACT_MAXIMIZE",
                action: ""
            },
            {
                cat: "CHEAT_CAT_WINDOW",
                keys: HotkeyRegistry.GetDisplayKeys(["minimize", "minimize2", "minimizeNum2"]),
                desc: "CHEAT_ACT_MINIMIZE",
                action: ""
            },
            {
                cat: "CHEAT_CAT_WINDOW",
                keys: HotkeyRegistry.GetDisplayKeys(["fullscreen", "fullscreen8", "fullscreenNum8"]),
                desc: "CHEAT_ACT_BORDERLESS",
                action: ((*) => WindowFullScreen.Toggle())
            },
            {
                cat: "CHEAT_CAT_WINDOW",
                keys: HotkeyRegistry.GetDisplayKeys(["hideTray", "hideTray2", "hideTrayNum2"]),
                desc: "CHEAT_ACT_HIDE_TRAY",
                action: ((*) => TrayHider.HideActive())
            },
            {
                cat: "CHEAT_CAT_WINDOW",
                keys: HotkeyRegistry.GetDisplayKeys(["opacityIncrease", "opacityDecrease"]),
                desc: "CHEAT_ACT_OPACITY",
                action: ""
            },
            {
                cat: "CHEAT_CAT_WINDOW",
                keys: HotkeyRegistry.GetDisplayKey("ghost"),
                desc: "CHEAT_ACT_GHOST",
                action: ""
            },
            {
                cat: "CHEAT_CAT_WINDOW",
                keys: HotkeyRegistry.GetDisplayKey("windowHole"),
                desc: "CHEAT_ACT_WINDOW_HOLE",
                action: ((*) => WindowHole.Toggle())
            },
            {
                cat: "CHEAT_CAT_WINDOW",
                keys: "CapsLock + X, then 1",
                desc: "CHEAT_ACT_WINDOW_HOLE_SECOND",
                action: ""
            },

            ; Mouse control mode
            {
                cat: "CHEAT_CAT_MOUSE",
                keys: "CapsLock ON, then Shift twice",
                desc: "CHEAT_ACT_MOUSE_TOGGLE",
                action: ((*) => MouseControl.Toggle())
            },
            {
                cat: "CHEAT_CAT_MOUSE",
                keys: "W / A / S / D",
                desc: "CHEAT_ACT_MOUSE_MOVE",
                action: ""
            },
            {
                cat: "CHEAT_CAT_MOUSE",
                keys: "J / K / L",
                desc: "CHEAT_ACT_MOUSE_CLICK",
                action: ""
            },
            {
                cat: "CHEAT_CAT_MOUSE",
                keys: "I / M",
                desc: "CHEAT_ACT_MOUSE_SCROLL",
                action: ""
            },
            {
                cat: "CHEAT_CAT_MOUSE",
                keys: "Alt + I / M",
                desc: "CHEAT_ACT_MOUSE_SCROLL_FAST",
                action: ""
            },
            {
                cat: "CHEAT_CAT_MOUSE",
                keys: "Q / E",
                desc: "CHEAT_ACT_MOUSE_SCROLL_HORIZONTAL",
                action: ""
            },
            {
                cat: "CHEAT_CAT_MOUSE",
                keys: "Alt + Q / E",
                desc: "CHEAT_ACT_MOUSE_SCROLL_HORIZONTAL_FAST",
                action: ""
            },
            {
                cat: "CHEAT_CAT_MOUSE",
                keys: "Shift / Esc",
                desc: "CHEAT_ACT_MOUSE_EXIT",
                action: ""
            },

            ; Visual effects
            {
                cat: "CHEAT_CAT_VISUAL",
                keys: HotkeyRegistry.GetDisplayKey("spotlight"),
                desc: "CHEAT_ACT_SPOTLIGHT",
                action: ((*) => Spotlight.Toggle())
            },
            {
                cat: "CHEAT_CAT_VISUAL",
                keys: HotkeyRegistry.GetDisplayKey("zoom"),
                desc: "CHEAT_ACT_ZOOM",
                action: ((*) => Zoom.Toggle())
            },

            ; Browser tabs
            {
                cat: "CHEAT_CAT_TABS",
                keys: HotkeyRegistry.GetDisplayKeys(["previousTab", "nextTab"]),
                desc: "CHEAT_ACT_TAB_PREV_NEXT",
                action: ""
            },

            ; Help and settings
            {
                cat: "CHEAT_CAT_HELP",
                keys: HotkeyRegistry.GetDisplayKeys(["cheatsheet", "cheatsheetF1"]),
                desc: "CHEAT_ACT_CHEATSHEET",
                action: ""
            },
            {
                cat: "CHEAT_CAT_HELP",
                keys: HotkeyRegistry.GetDisplayKey("commandPalette"),
                desc: "CHEAT_ACT_COMMAND_PALETTE",
                action: ((*) => CommandPaletteGui.Show())
            },
            {
                cat: "CHEAT_CAT_HELP",
                keys: HotkeyRegistry.GetDisplayKey("settings"),
                desc: "CHEAT_ACT_SETTINGS",
                action: ((*) => SettingsGui.Show())
            },
            {
                cat: "CHEAT_CAT_FILES",
                keys: HotkeyRegistry.GetDisplayKey("imageTools"),
                desc: "CHEAT_ACT_IMAGE_TOOLS",
                descDefault: "Open ImageMagick image tools",
                action: ((*) => ImageToolsGui.Toggle())
            }
        ]
    }
}
