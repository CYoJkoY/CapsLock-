#Requires AutoHotkey v2.0

class HotkeyRegistry {
    static Definitions := [
        {id: "gotoLine", group: "text", default: "j", labelKey: "HOTKEY_GOTO_LINE", action: ((*) => JumpToLine())},
        {id: "killProcess", group: "window", default: "k", labelKey: "HOTKEY_KILL_PROCESS", action: ((*) => TerminateProcessByPid())},
        {id: "previousTab", group: "tabs", default: "q", labelKey: "HOTKEY_PREV_TAB", action: ((*) => Send("^{PgUp}"))},
        {id: "nextTab", group: "tabs", default: "e", labelKey: "HOTKEY_NEXT_TAB", action: ((*) => Send("^{PgDn}"))},
        {id: "alwaysOnTop", group: "window", default: "t", labelKey: "HOTKEY_ALWAYS_ON_TOP", action: ((*) => ToggleAlwaysOnTopWithOSD())},
        {id: "windowSwitcher", group: "window", default: "l", labelKey: "HOTKEY_WINDOW_SWITCHER", action: ((*) => WindowSwitcherGui.Show())},
        {id: "copyPlain", group: "clipboard", default: "c", labelKey: "HOTKEY_COPY_PLAIN", action: ((*) => CopyAsPlainTextAndAddToHistory())},
        {id: "paste", group: "clipboard", default: "v", labelKey: "HOTKEY_PASTE", action: ((*) => PasteWithCurrentMode())},
        {id: "historyMenu", group: "clipboard", default: "+v", labelKey: "HOTKEY_HISTORY_MENU", action: ((*) => ShowHistoryMenu())},
        {id: "changeCase", group: "clipboard", default: "f", labelKey: "HOTKEY_CHANGE_CASE", action: ((*) => ChangeCaseOfLastCopy())},
        {id: "pandoc", group: "tools", default: "p", labelKey: "HOTKEY_PANDOC", action: ((*) => ConvertWithPandoc())},
        {id: "tempFolder", group: "tools", default: "!q", labelKey: "HOTKEY_TEMP_FOLDER", action: ((*) => OpenTempFolder())},
        {id: "commandPalette", group: "tools", default: "r", labelKey: "HOTKEY_COMMAND_PALETTE", action: ((*) => CommandPaletteGui.Show())},
        {id: "cheatsheet", group: "tools", default: "h", labelKey: "HOTKEY_CHEATSHEET", action: ((*) => HotkeyReferenceGui.Toggle())},
        {id: "cheatsheetF1", group: "tools", default: "F1", labelKey: "HOTKEY_CHEATSHEET_F1", action: ((*) => HotkeyReferenceGui.Toggle())},
        {id: "settings", group: "tools", default: ",", labelKey: "HOTKEY_SETTINGS", action: ((*) => SettingsGui.Toggle())},
        {id: "imageTools", group: "tools", default: "i", labelKey: "HOTKEY_IMAGE_TOOLS", action: ((*) => ImageToolsGui.Toggle())},
        {id: "spotlight", group: "visual", default: "o", labelKey: "HOTKEY_SPOTLIGHT", action: ((*) => Spotlight.HandleDown()), release: ((*) => Spotlight.HandleUp())},
        {id: "zoom", group: "visual", default: "z", labelKey: "HOTKEY_ZOOM", action: ((*) => Zoom.HandleDown()), release: ((*) => Zoom.HandleUp())},
        {id: "windowHole", group: "visual", default: "x", labelKey: "HOTKEY_WINDOW_HOLE", action: ((*) => WindowHole.HandleXDown()), release: ((*) => WindowHole.HandleXUp())},
        {id: "fileDelete", group: "files", default: "+d", labelKey: "HOTKEY_FILE_DELETE", action: ((*) => FileDeleter.ConfirmDelete()), fileOnly: true},
        {id: "quickPhrase", group: "quickphrase", default: "+p", labelKey: "HOTKEY_QUICK_PHRASE", action: ((*) => QuickPhraseHandleHotkey()), quickPhrase: true},
        {id: "selectWordLeft", group: "text", default: "+Left", labelKey: "HOTKEY_SELECT_WORD_LEFT", action: ((*) => Send("^+{Left}"))},
        {id: "selectWordRight", group: "text", default: "+Right", labelKey: "HOTKEY_SELECT_WORD_RIGHT", action: ((*) => Send("^+{Right}"))},
        {id: "selectLineUp", group: "text", default: "+Up", labelKey: "HOTKEY_SELECT_LINE_UP", action: ((*) => Send("+{Home}"))},
        {id: "selectLineDown", group: "text", default: "+Down", labelKey: "HOTKEY_SELECT_LINE_DOWN", action: ((*) => Send("+{End}"))},
        {id: "selectCurrent", group: "text", default: "Space", labelKey: "HOTKEY_SELECT_CURRENT", action: ((*) => Send("^{Left}^+{Right}"))},
        {id: "deletePreviousChar", group: "text", default: "a", labelKey: "HOTKEY_DELETE_PREVIOUS_CHAR", action: ((*) => Send("{Backspace}"))},
        {id: "deleteNextChar", group: "text", default: "d", labelKey: "HOTKEY_DELETE_NEXT_CHAR", action: ((*) => Send("{Delete}"))},
        {id: "deletePreviousWord", group: "text", default: "+a", labelKey: "HOTKEY_DELETE_PREVIOUS_WORD", action: ((*) => Send("^{Backspace}"))},
        {id: "deleteNextWord", group: "text", default: "+d", labelKey: "HOTKEY_DELETE_NEXT_WORD", action: ((*) => Send("^{Delete}")), excludeFileBrowser: true},
        {id: "deleteLineBackspace", group: "text", default: "Backspace", labelKey: "HOTKEY_DELETE_LINE_BACKSPACE", action: ((*) => Send("{Home}+{End}{Delete}"))},
        {id: "deleteLine", group: "text", default: "Delete", labelKey: "HOTKEY_DELETE_LINE", action: ((*) => Send("{Home}+{End}{Delete}"))},
        {id: "maximize", group: "window", default: "w", labelKey: "CHEAT_ACT_MAXIMIZE", action: ((*) => WindowWildcardMaximize()), wildcard: true},
        {id: "maximize8", group: "window", default: "8", labelKey: "CHEAT_ACT_MAXIMIZE", action: ((*) => WindowWildcardMaximize()), wildcard: true},
        {id: "maximizeNum8", group: "window", default: "Numpad8", labelKey: "CHEAT_ACT_MAXIMIZE", action: ((*) => WindowWildcardMaximize()), wildcard: true},
        {id: "minimize", group: "window", default: "s", labelKey: "CHEAT_ACT_MINIMIZE", action: ((*) => WindowWildcardMinimize()), wildcard: true},
        {id: "minimize2", group: "window", default: "2", labelKey: "CHEAT_ACT_MINIMIZE", action: ((*) => WindowWildcardMinimize()), wildcard: true},
        {id: "minimizeNum2", group: "window", default: "Numpad2", labelKey: "CHEAT_ACT_MINIMIZE", action: ((*) => WindowWildcardMinimize()), wildcard: true},
        {id: "fullscreen", group: "window", default: "+w", labelKey: "CHEAT_ACT_BORDERLESS", action: ((*) => (DeactivateShiftLayer(), WindowFullScreen.Toggle()))},
        {id: "fullscreen8", group: "window", default: "+8", labelKey: "CHEAT_ACT_BORDERLESS", action: ((*) => (DeactivateShiftLayer(), WindowFullScreen.Toggle()))},
        {id: "fullscreenNum8", group: "window", default: "+Numpad8", labelKey: "CHEAT_ACT_BORDERLESS", action: ((*) => (DeactivateShiftLayer(), WindowFullScreen.Toggle()))},
        {id: "hideTray", group: "window", default: "+s", labelKey: "CHEAT_ACT_HIDE_TRAY", action: ((*) => (DeactivateShiftLayer(), TrayHider.HideActive()))},
        {id: "hideTray2", group: "window", default: "+2", labelKey: "CHEAT_ACT_HIDE_TRAY", action: ((*) => (DeactivateShiftLayer(), TrayHider.HideActive()))},
        {id: "hideTrayNum2", group: "window", default: "+Numpad2", labelKey: "CHEAT_ACT_HIDE_TRAY", action: ((*) => (DeactivateShiftLayer(), TrayHider.HideActive()))},
        {id: "opacityIncrease", group: "window", default: "LButton", labelKey: "HOTKEY_OPACITY_INCREASE", action: ((*) => AdjustOpacityShortcut("opacityIncrease", 20)), opacity: true},
        {id: "opacityDecrease", group: "window", default: "RButton", labelKey: "HOTKEY_OPACITY_DECREASE", action: ((*) => AdjustOpacityShortcut("opacityDecrease", -20)), opacity: true},
        {id: "ghost", group: "window", default: "MButton", labelKey: "CHEAT_ACT_GHOST", action: ((*) => ToggleGhostOpacity()), opacity: true}
    ]

    static _active := Map()
    static _initialized := false
    static _held := Map()
    static _releaseKeys := Map()
    static _conditions := Map()

    static Initialize() {
        if this._initialized
            return
        this._initialized := true
        this.Apply()
    }

    static GetDefinitions() {
        return this.Definitions
    }

    static GetDefinition(id) {
        for definition in this.Definitions
            if definition.id == id
                return definition
        return ""
    }

    static GetSuffix(id) {
        if AppState.HotkeyBindings.Has(id)
            return AppState.HotkeyBindings[id]
        definition := this.GetDefinition(id)
        return IsObject(definition) ? definition.default : ""
    }

    static GetDisplayKey(id) {
        return this.DisplaySuffix(this.GetSuffix(id))
    }

    static GetDisplayKeys(ids) {
        modifiers := []
        keys := []
        for id in ids {
            suffix := this.GetSuffix(id)
            modifiers.Push(this._ModifierNames(suffix))
            keys.Push(this._DisplayKeyName(RegExReplace(suffix, "^[\^!+#]+")))
        }
        if keys.Length == 0
            return ""
        for modifier in modifiers
            if modifier != modifiers[1] {
                displays := []
                for id in ids
                    displays.Push(this.GetDisplayKey(id))
                return Join(displays, " / ")
            }
        prefix := modifiers[1] == "" ? "CapsLock" : "CapsLock + " modifiers[1]
        return prefix " + " Join(keys, " / ")
    }

    static DisplaySuffix(suffix) {
        modifiers := this._ModifierNames(suffix)
        key := RegExReplace(suffix, "^[\^!+#]+")
        return modifiers == ""
            ? "CapsLock + " this._DisplayKeyName(key)
            : "CapsLock + " modifiers " + " this._DisplayKeyName(key)
    }

    static _ModifierNames(suffix) {
        names := []
        if InStr(suffix, "^")
            names.Push("Ctrl")
        if InStr(suffix, "!")
            names.Push("Alt")
        if InStr(suffix, "+")
            names.Push("Shift")
        if InStr(suffix, "#")
            names.Push("Win")
        return Join(names, " + ")
    }

    static _DisplayKeyName(key) {
        static names := Map(
            ",", "Comma",
            "space", "Space",
            "tab", "Tab",
            "enter", "Enter",
            "numpadenter", "Numpad Enter",
            "esc", "Escape",
            "escape", "Escape",
            "backspace", "Backspace",
            "delete", "Delete",
            "del", "Delete",
            "insert", "Insert",
            "ins", "Insert",
            "home", "Home",
            "end", "End",
            "pgup", "Page Up",
            "pgdn", "Page Down",
            "left", "Left",
            "right", "Right",
            "up", "Up",
            "down", "Down",
            "lbutton", "Left Button",
            "rbutton", "Right Button",
            "mbutton", "Middle Button",
            "xbutton1", "XButton 1",
            "xbutton2", "XButton 2",
            "wheelup", "Wheel Up",
            "wheeldown", "Wheel Down",
            "wheelleft", "Wheel Left",
            "wheelright", "Wheel Right",
            "capslock", "CapsLock",
            "numlock", "NumLock",
            "scrolllock", "ScrollLock",
            "appskey", "Apps",
            "printscreen", "Print Screen",
            "pause", "Pause"
        )
        lower := StrLower(key)
        if names.Has(lower)
            return names[lower]
        if StrLen(lower) == 1
            return StrUpper(lower)
        if RegExMatch(lower, "^f\d{1,2}$")
            return StrUpper(lower)
        return key
    }

    static Serialize() {
        values := []
        for definition in this.Definitions
            values.Push(definition.id "=" this.GetSuffix(definition.id))
        return Join(values, "|")
    }

    static Deserialize(serialized) {
        values := Map()
        known := Map()
        for definition in this.Definitions
            known[definition.id] := definition
        for item in StrSplit(String(serialized), "|") {
            separator := InStr(item, "=")
            if separator <= 1
                continue
            id := SubStr(item, 1, separator - 1)
            suffix := this.NormalizeSuffix(SubStr(item, separator + 1))
            if known.Has(id) && this.IsValidSuffix(known[id], suffix)
                values[id] := suffix
        }
        for definition in this.Definitions {
            suffix := values.Has(definition.id) ? values[definition.id] : definition.default
            if this.FindConflict(definition.id, suffix, values) != ""
                return Map()
        }
        return values
    }

    static IsValidSuffix(definition, suffix) {
        return suffix != ""
            && !(definition.HasProp("release") && InStr(suffix, "wheel"))
    }

    static NormalizeSuffix(suffix) {
        suffix := Trim(String(suffix))
        if suffix == ""
            return ""
        if !RegExMatch(suffix, "^([\^!+#]*)([^\^!+# ]+)$", &match)
            return ""
        key := GetKeyName(match[2])
        if key == "" || RegExMatch(key, "i)^(CapsLock|[LR]?(Control|Ctrl|Shift|Alt|Win))$")
            return ""
        if InStr(key, "|") || InStr(key, "=")
            key := Format("vk{:02X}", GetKeyVK(key))
        modifiers := ""
        for modifier in ["^", "!", "+", "#"]
            if InStr(match[1], modifier)
                modifiers .= modifier
        return modifiers StrLower(key)
    }

    static FindConflict(id, suffix, bindings := "") {
        definition := this.GetDefinition(id)
        if !IsObject(bindings)
            bindings := AppState.HotkeyBindings
        for other in this.Definitions {
            otherSuffix := bindings.Has(other.id) ? bindings[other.id] : other.default
            if other.id == id || this.NormalizeSuffix(otherSuffix) != this.NormalizeSuffix(suffix)
                continue
            if (definition.HasProp("fileOnly") && other.HasProp("excludeFileBrowser"))
                || (definition.HasProp("excludeFileBrowser") && other.HasProp("fileOnly"))
                continue
            return other.id
        }
        return ""
    }

    static SetSuffix(id, suffix) {
        definition := this.GetDefinition(id)
        if !IsObject(definition)
            return false
        suffix := this.NormalizeSuffix(suffix)
        if !this.IsValidSuffix(definition, suffix)
            return false
        if this.FindConflict(id, suffix) != ""
            return false
        previous := AppState.HotkeyBindings.Clone()
        AppState.HotkeyBindings[id] := suffix
        try {
            this.Apply()
            ConfigManager.Save()
        } catch {
            AppState.HotkeyBindings := previous
            this.Apply()
            return false
        }
        return true
    }

    static ResetDefaults() {
        previous := AppState.HotkeyBindings.Clone()
        AppState.HotkeyBindings := Map()
        try {
            this.Apply()
            ConfigManager.Save()
        } catch {
            AppState.HotkeyBindings := previous
            this.Apply()
            return false
        }
        return true
    }

    static Apply() {
        for id, key in this._held.Clone()
            this.Release(this.GetDefinition(id))
        for id, previous in this._active {
            HotIf(previous.condition)
            Hotkey(previous.suffix, "Off")
        }
        HotIf()
        for key, releaseHotkey in this._releaseKeys
            Hotkey(releaseHotkey, "Off")
        this._active := Map()
        this._releaseKeys := Map()
        try {
            for definition in this.Definitions
                this._Register(definition)
        } finally {
            HotIf()
        }
    }

    static _Register(definition) {
        suffix := this.GetSuffix(definition.id)
        if !this._conditions.Has(definition.id)
            this._conditions[definition.id] := (*) => this._IsAvailable(definition)
        condition := this._conditions[definition.id]
        HotIf(condition)
        hotkeyName := "$" (definition.HasProp("wildcard") && definition.wildcard ? "*" : "") suffix
        Hotkey(hotkeyName, (*) => this.Run(definition), "On")
        this._active[definition.id] := {suffix: hotkeyName, condition: condition}
        if !definition.HasProp("release")
            return
        key := RegExReplace(suffix, "^[\^!+#]+")
        HotIf()
        releaseHotkey := "~*" key " up"
        Hotkey(releaseHotkey, (*) => this.ReleaseKey(key), "On")
        this._releaseKeys[key] := releaseHotkey
    }

    static Run(definition) {
        if definition.HasProp("release") && this._held.Has(definition.id)
            return
        if definition.HasProp("release")
            this._held[definition.id] := RegExReplace(this.GetSuffix(definition.id), "^[\^!+#]+")
        definition.action.Call()
    }

    static ReleaseKey(key) {
        if this._releaseKeys.Get(key, "") == ""
            return
        for id, heldKey in this._held.Clone()
            if heldKey == key
                this.Release(this.GetDefinition(id))
    }

    static Release(definition) {
        try
            this._held.Delete(definition.id)
        try
            definition.release.Call()
    }

    static IsHeld(id) {
        if this._held.Has(id)
            return true
        key := RegExReplace(this.GetSuffix(id), "^[\^!+#]+")
        return GetKeyState(key, "P")
    }

    static _IsAvailable(definition) {
        if HotkeySettingsGui.IsCapturing() || FileDeleter.Busy
            return false
        if !CapsLockShortcutGroupAvailable(definition.group)
            return false
        if definition.HasProp("opacity") && !WindowOpacityHotkeysAvailable()
            return false
        if definition.HasProp("fileOnly") && definition.fileOnly
            return FileDeleter.IsFileBrowserActive()
        if definition.HasProp("excludeFileBrowser") && definition.excludeFileBrowser
            return !FileDeleter.IsFileBrowserActive()
        if definition.HasProp("quickPhrase") && definition.quickPhrase
            return AppState.QuickPhraseEnabled && !QuickPhraseUiActive()
        return true
    }
}
