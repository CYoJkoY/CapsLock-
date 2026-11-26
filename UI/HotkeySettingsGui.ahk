#Requires AutoHotkey v2.0

class HotkeySettingsGui {
    static gui := ""
    static listView := ""
    static statusText := ""
    static pendingId := ""
    static capture := ""
    static capturedSuffix := ""

    static IsCapturing() {
        return this.pendingId != ""
    }

    static Show() {
        if IsObject(this.gui) {
            try WinActivate("ahk_id " this.gui.Hwnd)
            return
        }

        this.pendingId := ""
        this.capturedSuffix := ""
        myGui := Gui("-MaximizeBox -MinimizeBox", Lang("HOTKEY_SETTINGS_TITLE"))
        ThemeHelper.StyleGui(myGui)
        ThemeHelper.AddTitle(myGui, Lang("HOTKEY_SETTINGS_TITLE"), 640)
        myGui.SetFont("s9 c" Theme.TextSecondary, ThemeHelper.ReadingStack())
        hint := myGui.Add(
            "Text",
            "x18 y+8 w644",
            Lang("HOTKEY_SETTINGS_HINT")
        )
        ThemeHelper.MarkSurface(hint, Theme.TextSecondary, Theme.Background)

        myGui.SetFont("s10 c" Theme.Text, ThemeHelper.ReadingStack())
        this.listView := myGui.Add("ListView", "x18 y+10 w644 h300 -Multi " ThemeHelper.GetLVOptions(),
            [Lang("GUI_COMMAND_PALETTE_COL_COMMAND"), Lang("GUI_COMMAND_PALETTE_COL_SHORTCUT")])
        this.listView.ModifyCol(1, 355)
        this.listView.ModifyCol(2, 265)
        ThemeHelper.StyleListView(this.listView)
        this.listView.OnEvent("DoubleClick", (control, row) => this.BeginCapture(row))

        this.statusText := myGui.Add("Text", "x18 y+8 w644 r2", Lang("HOTKEY_SETTINGS_IDLE"))
        ThemeHelper.MarkSurface(this.statusText, Theme.TextSecondary, Theme.Background)

        editButton := ThemeHelper.AddButton(myGui, "x18 y+12 w150 h32", Lang("HOTKEY_SETTINGS_EDIT"), "primary")
        editButton.OnEvent("Click", (*) => this.BeginCapture(this.listView.GetNext()))
        resetButton := ThemeHelper.AddButton(
            myGui,
            "x+10 yp w185 h32",
            Lang("HOTKEY_SETTINGS_RESET"),
            "primary"
        )
        resetButton.OnEvent("Click", (*) => this.ResetDefaults())

        closeButton := ThemeHelper.AddButton(
            myGui,
            "x550 yp w112 h32",
            Lang("GUI_FULL_CLOSE", "Close")
        )
        closeButton.OnEvent("Click", (*) => this.Close())
        myGui.OnEvent("Escape", (*) => this.Escape())
        myGui.OnEvent("Close", (*) => this.Close())

        this.gui := myGui
        this.Refresh()
        ThemeHelper.ApplyWindowTheme(myGui.Hwnd)
        myGui.Show("w680 AutoSize Center")
        this.listView.Modify(1, "Select Focus")
    }

    static Close() {
        this.CancelCapture()
        if !IsObject(this.gui)
            return
        try this.gui.Destroy()
        this.gui := ""
        this.listView := ""
        this.statusText := ""
        this.pendingId := ""
        this.capturedSuffix := ""
    }

    static Refresh() {
        if !IsObject(this.listView)
            return
        this.listView.Delete()
        for definition in HotkeyRegistry.GetDefinitions() {
            this.listView.Add(
                ,
                Lang(definition.labelKey),
                HotkeyRegistry.GetDisplayKey(definition.id)
            )
        }
    }

    static BeginCapture(row) {
        if !IsObject(this.gui) || row <= 0 || this.IsCapturing()
            return
        this.pendingId := HotkeyRegistry.Definitions[row].id
        this.capturedSuffix := ""
        this.statusText.Text := Lang("HOTKEY_SETTINGS_PRESS")
        hook := InputHook("L0 T15")
        hook.KeyOpt("{All}", "NS")
        hook.OnKeyDown := ObjBindMethod(this, "CaptureKey")
        hook.OnKeyUp := ObjBindMethod(this, "CaptureReleased")
        hook.OnEnd := ObjBindMethod(this, "CaptureEnded")
        this.capture := hook
        hook.Start()
    }

    static CaptureKey(hook, vk, sc) {
        if !IsObject(this.gui) || !WinActive("ahk_id " this.gui.Hwnd) {
            hook.Stop()
            return
        }
        key := GetKeyName(Format("vk{:02X}sc{:03X}", vk, sc))
        if key == "Escape" {
            hook.Stop()
            return
        }
        if this.capturedSuffix != "" || RegExMatch(key, "i)^(CapsLock|[LR]?(Control|Ctrl|Shift|Alt|Win))$")
            return
        this.capturedSuffix := this.ModifierPrefix() key
        this.statusText.Text := HotkeyRegistry.DisplaySuffix(this.capturedSuffix)
    }

    static CaptureReleased(hook, vk, sc) {
        key := GetKeyName(Format("vk{:02X}sc{:03X}", vk, sc))
        if this.capturedSuffix != "" && key == RegExReplace(this.capturedSuffix, "^[\^!+#]+")
            this.CommitCapture(this.capturedSuffix)
    }

    static ModifierPrefix() {
        return (GetKeyState("Ctrl", "P") ? "^" : "")
            . (GetKeyState("Alt", "P") ? "!" : "")
            . (GetKeyState("Shift", "P") ? "+" : "")
            . (GetKeyState("LWin", "P") || GetKeyState("RWin", "P") ? "#" : "")
    }

    static CaptureMouse(key) {
        if !IsObject(this.gui) || !WinActive("ahk_id " this.gui.Hwnd) {
            this.CancelCapture()
            return
        }
        suffix := this.ModifierPrefix() key
        if !InStr(key, "Wheel")
            KeyWait(key)
        if this.IsCapturing()
            this.CommitCapture(suffix)
    }

    static CommitCapture(suffix) {
        id := this.pendingId
        this.pendingId := ""
        if IsObject(this.capture)
            this.capture.Stop()
        this.capture := ""
        success := HotkeyRegistry.SetSuffix(id, suffix)
        this.Refresh()
        this.statusText.Text := Lang(success ? "HOTKEY_SETTINGS_SAVED" : "HOTKEY_SETTINGS_INVALID")
    }

    static CaptureEnded(hook) {
        if hook != this.capture || this.pendingId == ""
            return
        this.capture := ""
        this.pendingId := ""
        if IsObject(this.statusText)
            this.statusText.Text := Lang("HOTKEY_SETTINGS_CANCELLED")
    }

    static ResetDefaults() {
        this.CancelCapture()
        success := HotkeyRegistry.ResetDefaults()
        this.Refresh()
        this.statusText.Text := Lang(success ? "HOTKEY_SETTINGS_SAVED" : "HOTKEY_SETTINGS_INVALID")
    }

    static CancelCapture() {
        this.pendingId := ""
        if IsObject(this.capture)
            this.capture.Stop()
        this.capture := ""
    }

    static Escape() {
        if !this.IsCapturing() {
            this.Close()
            return
        }
        this.CancelCapture()
        this.statusText.Text := Lang("HOTKEY_SETTINGS_CANCELLED")
    }
}
