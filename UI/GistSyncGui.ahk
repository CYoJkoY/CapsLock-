#Requires AutoHotkey v2.0

class GistSyncGui {
    static GuiObj := ""

    static Show() {
        if IsObject(this.GuiObj) {
            try {
                if WinExist("ahk_id " . this.GuiObj.Hwnd) {
                    WinActivate("ahk_id " . this.GuiObj.Hwnd)
                    return
                }
            } catch {
                this.GuiObj := ""
            }
        }

        myGui := Gui("+AlwaysOnTop +Resize +MinSize640x440", Lang("GUI_GIST_TITLE"))
        ThemeHelper.StyleGui(myGui)
        this.GuiObj := myGui

        contentW := 580
        labelW := 130          ; Increased from 100 to accommodate multi-language labels
        labelX := 16
        editX := labelX + labelW + 8   ; 8px gap

        ; Title
        ThemeHelper.AddTitle(myGui, "☁️ " . Lang("GUI_GIST_TITLE"), contentW)
        ThemeHelper.AddSubtitle(myGui, Lang("GUI_GIST_SUBTITLE"), contentW)
        ThemeHelper.AddSeparator(myGui, contentW)

        ; Token
        myGui.SetFont("s10 c" AppState.THEME_FG_DIM, AppState.THEME_FONT)
        myGui.Add("Text", "x" labelX " y+16 w" labelW, Lang("GUI_GIST_TOKEN"))
        myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)
        tokenEdit := myGui.Add("Edit", "x" editX " yp-2 w" (contentW - editX - 16) " r1 Password " ThemeHelper.GetEditOptions(), AppState.GistToken)
        this.TokenEdit := tokenEdit

        ; Gist ID
        myGui.SetFont("s10 c" AppState.THEME_FG_DIM, AppState.THEME_FONT)
        myGui.Add("Text", "x" labelX " y+12 w" labelW, Lang("GUI_GIST_GISTID"))
        myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)
        gistEdit := myGui.Add("Edit", "x" editX " yp-2 w" (contentW - editX - 16) " r1 " ThemeHelper.GetEditOptions(), AppState.GistId)
        this.GistEdit := gistEdit

        ThemeHelper.AddSeparator(myGui, contentW)

        ; Three action buttons (unchanged)
        btnUpload := ThemeHelper.AddButton(myGui, "x16 y+16 w140", "⬆️ " . Lang("GUI_GIST_UPLOAD"), "primary")
        btnUpload.OnEvent("Click", (*) => this._OnUpload())

        btnAppend := ThemeHelper.AddButton(myGui, "x+16 yp w140", "📥 " . Lang("GUI_GIST_APPEND"), "secondary")
        btnAppend.OnEvent("Click", (*) => this._OnAppend())

        btnOverwrite := ThemeHelper.AddButton(myGui, "x+16 yp w140", "⚠️ " . Lang("GUI_GIST_OVERWRITE"), "danger")
        btnOverwrite.OnEvent("Click", (*) => this._OnOverwrite())

        ; Status line
        myGui.SetFont("s9 c" AppState.THEME_FG_MUTED, AppState.THEME_FONT)
        statusText := myGui.Add("Text", "x16 y+20 w" contentW, Lang("GUI_GIST_STATUS_READY"))
        this.StatusText := statusText

        myGui.OnEvent("Close", (*) => this.Close())
        myGui.OnEvent("Escape", (*) => this.Close())

        myGui.Show("w660 h380")
        ThemeHelper.ApplyImmersiveDarkMode(myGui.Hwnd)
    }

    ; ---- Other methods remain exactly the same ----
    static Close() {
        if IsObject(this.GuiObj) {
            try this.GuiObj.Destroy()
            this.GuiObj := ""
        }
        this.TokenEdit := ""
        this.GistEdit := ""
        this.StatusText := ""
    }

    static _OnUpload() {
        this._SaveInputs()
        localDir := A_ScriptDir "\configs"
        token := AppState.GistToken
        gistId := AppState.GistId
        if token == "" {
            ShowToolTip(Lang("MSG_GIST_NO_TOKEN"), 3000)
            return
        }

        this._SetStatus(Lang("MSG_GIST_UPLOADING"))

        try {
            newId := GistSync.Upload(localDir, token, gistId)

            if gistId == "" {
                AppState.GistId := newId
                ConfigManager.Save()
                this.GistEdit.Value := newId
            }

            ShowToolTip(Lang("MSG_GIST_UPLOAD_SUCCESS", , newId), 3000)
            this._SetStatus(Lang("MSG_GIST_UPLOAD_SUCCESS", , newId))
        } catch as err {
            ShowToolTip(Lang("MSG_GIST_UPLOAD_FAIL", , err.Message), 4000)
            this._SetStatus(Lang("MSG_GIST_UPLOAD_FAIL", , err.Message))
        }
    }

    static _OnAppend() {
        this._SaveInputs()
        token := AppState.GistToken
        gistId := AppState.GistId
        if token == "" {
            ShowToolTip(Lang("MSG_GIST_NO_TOKEN"), 3000)
            return
        }
        if gistId == "" {
            ShowToolTip(Lang("MSG_GIST_NO_GISTID"), 3000)
            return
        }
        this._SetStatus(Lang("MSG_GIST_APPENDING"))
        try {
            written := GistSync.Download(gistId, token, A_ScriptDir "\configs", "append")
            ShowToolTip(Lang("MSG_GIST_APPEND_SUCCESS", , written), 3000)
            this._SetStatus(Lang("MSG_GIST_APPEND_SUCCESS", , written))
        } catch as err {
            ShowToolTip(Lang("MSG_GIST_APPEND_FAIL", , err.Message), 4000)
            this._SetStatus(Lang("MSG_GIST_APPEND_FAIL", , err.Message))
        }
    }

    static _OnOverwrite() {
        this._SaveInputs()
        token := AppState.GistToken
        gistId := AppState.GistId
        if token == "" {
            ShowToolTip(Lang("MSG_GIST_NO_TOKEN"), 3000)
            return
        }
        if gistId == "" {
            ShowToolTip(Lang("MSG_GIST_NO_GISTID"), 3000)
            return
        }
        ; Confirm overwrite (with temporary deactivation of always-on-top)
        hwnd := this.GuiObj.Hwnd
        WinSetAlwaysOnTop(0, "ahk_id " . hwnd)
        confirm := MsgBox(Lang("MSG_GIST_CONFIRM_OVERWRITE"), Lang("MSG_CONFIRM"), "YesNo Icon?")
        WinSetAlwaysOnTop(1, "ahk_id " . hwnd)
        if confirm != "Yes"
            return

        this._SetStatus(Lang("MSG_GIST_OVERWRITING"))
        try {
            written := GistSync.Download(gistId, token, A_ScriptDir "\configs", "overwrite")
            ShowToolTip(Lang("MSG_GIST_OVERWRITE_SUCCESS", , written), 3000)
            this._SetStatus(Lang("MSG_GIST_OVERWRITE_SUCCESS", , written))
        } catch as err {
            ShowToolTip(Lang("MSG_GIST_OVERWRITE_FAIL", , err.Message), 4000)
            this._SetStatus(Lang("MSG_GIST_OVERWRITE_FAIL", , err.Message))
        }
    }

    static _SaveInputs() {
        if IsObject(this.TokenEdit)
            AppState.GistToken := Trim(this.TokenEdit.Value)

        if IsObject(this.GistEdit)
            AppState.GistId := Trim(this.GistEdit.Value)

        ConfigManager.Save()
    }

    static _SetStatus(text) {
        if IsObject(this.StatusText)
            this.StatusText.Value := text
    }
}
