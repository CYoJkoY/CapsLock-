#Requires AutoHotkey v2.0

; AI API Settings GUI - manages API configuration and custom prompts.
; Opens from the system tray menu.
class PromptSettingsGui {
    static GuiObj := ""
    static PromptLV := ""
    static StatusText := ""
    static UrlEdit := ""
    static KeyEdit := ""
    static ModelEdit := ""
    static MaxTokensEdit := ""
    static TempEdit := ""

    ; Show the AI Settings GUI. If already open, activates the existing window.
    static Show() {
        ; If already open, just activate
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

        myGui := Gui("+Resize +MinSize800x720 +OwnDialogs", Lang("GUI_AI_SETTINGS_TITLE"))
        ThemeHelper.StyleGui(myGui)

        ; Store reference for resize handling
        this.GuiObj := myGui

        ; Layout constant — wider than before to fit all content
        contentW := 640

        ; --- Title ---
        ThemeHelper.AddTitle(myGui, "🤖 " . Lang("GUI_AI_SETTINGS_TITLE"), contentW)
        ThemeHelper.AddSubtitle(myGui,
            Lang("GUI_AI_SETTINGS_SUBTITLE"), contentW)
        ThemeHelper.AddSeparator(myGui, contentW)

        ; --- API Configuration Section ---
        myGui.SetFont("s11 Bold c" AppState.THEME_ACCENT, AppState.THEME_FONT)
        myGui.Add("Text", "x16 y+14 w" contentW, Lang("GUI_AI_API_SECTION"))
        myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)

        ; API URL
        myGui.Add("Text", "x16 y+12 w100", Lang("GUI_AI_URL"))
        urlEdit := myGui.Add("Edit", "x120 yp-2 w" (contentW - 120) " r1 " . ThemeHelper.GetEditOptions(), AppState.ApiUrl)
        this.UrlEdit := urlEdit

        ; API URL hint — tells user only base URL is needed
        myGui.SetFont("s8 c" AppState.THEME_FG_MUTED, AppState.THEME_FONT)
        myGui.Add("Text", "x120 y+2 w" (contentW - 120), Lang("GUI_AI_URL_HINT"))
        myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)

        ; API Key
        myGui.Add("Text", "x16 y+10 w100", Lang("GUI_AI_KEY"))
        keyEdit := myGui.Add("Edit", "x120 yp-2 w" (contentW - 120) " r1 Password " . ThemeHelper.GetEditOptions(), AppState.ApiKey)
        this.KeyEdit := keyEdit

        ; Model
        myGui.Add("Text", "x16 y+10 w100", Lang("GUI_AI_MODEL"))
        modelEdit := myGui.Add("Edit", "x120 yp-2 w200 r1 " . ThemeHelper.GetEditOptions(), AppState.ApiModel)
        this.ModelEdit := modelEdit

        ; Max Tokens (on same row as Model)
        myGui.Add("Text", "x350 yp+2 w100", Lang("GUI_AI_MAX_TOKENS"))
        maxTokensEdit := myGui.Add("Edit", "x460 yp-2 w80 r1 " . ThemeHelper.GetEditOptions(), AppState.ApiMaxTokens)
        this.MaxTokensEdit := maxTokensEdit

        ; Temperature
        myGui.Add("Text", "x16 y+10 w110", Lang("GUI_AI_TEMPERATURE"))
        tempEdit := myGui.Add("Edit", "x130 yp-2 w70 r1 " . ThemeHelper.GetEditOptions(), AppState.ApiTemperature)
        this.TempEdit := tempEdit

        ; Test Connection button
        btnTest := ThemeHelper.AddButton(myGui, "x+16 yp w160", "🔗 " . Lang("GUI_AI_TEST"))
        btnTest.OnEvent("Click", (*) => this.TestConnection())

        ; --- Prompts Section ---
        ThemeHelper.AddSeparator(myGui, contentW)

        myGui.SetFont("s11 Bold c" AppState.THEME_ACCENT, AppState.THEME_FONT)
        myGui.Add("Text", "x16 y+10 w" contentW, Lang("GUI_AI_PROMPTS_SECTION"))
        myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)

        ; Prompt ListView — slightly wider, initial col 2 width uses contentW
        lv := myGui.Add(
            "ListView",
            "x16 y+10 w" (contentW - 10) " r8 -Multi " . ThemeHelper.GetLVOptions(),
            [Lang("GUI_AI_PROMPT_NAME"), Lang("GUI_AI_PROMPT_CONTENT")]
        )
        lv.ModifyCol(1, 180)
        lv.ModifyCol(2, contentW - 200)
        lv.OnEvent("DoubleClick", (*) => this.EditPrompt())
        lv.OnEvent("ItemSelect", (*) => this.UpdateButtonStates())
        ThemeHelper.StyleListView(lv)
        this.PromptLV := lv

        ; Prompt action buttons
        btnAdd := ThemeHelper.AddButton(myGui, "x16 y+10 w100", "➕ " . Lang("GUI_AI_ADD_PROMPT"))
        btnAdd.OnEvent("Click", (*) => this.AddPrompt())

        btnEdit := ThemeHelper.AddButton(myGui, "x+8 yp w100", "✏️ " . Lang("GUI_AI_EDIT_PROMPT"))
        btnEdit.OnEvent("Click", (*) => this.EditPrompt())
        this.BtnEdit := btnEdit

        btnDelete := ThemeHelper.AddButton(myGui, "x+8 yp w100", "🗑️ " . Lang("GUI_AI_DELETE_PROMPT"), "danger")
        btnDelete.OnEvent("Click", (*) => this.DeletePrompt())
        this.BtnDelete := btnDelete

        btnSetActive := ThemeHelper.AddButton(myGui, "x+8 yp w120", "⭐ " . Lang("GUI_AI_SET_ACTIVE"), "primary")
        btnSetActive.OnEvent("Click", (*) => this.SetActivePrompt())
        this.BtnSetActive := btnSetActive

        ; Status bar
        ThemeHelper.AddSeparator(myGui, contentW)
        statusText := myGui.Add(
            "Text",
            "x16 y+10 w" contentW,
            this._BuildStatusText()
        )
        myGui.SetFont("s9 c" AppState.THEME_FG_MUTED, AppState.THEME_FONT)
        this.StatusText := statusText

        ; Bottom buttons
        myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)
        btnSave := ThemeHelper.AddButton(myGui, "x16 y+14 w100", "💾 " . Lang("GUI_OK"), "primary")
        btnSave.OnEvent("Click", (*) => this.SaveAndClose())

        btnCancel := ThemeHelper.AddButton(myGui, "x+10 yp w100", "✕ " . Lang("GUI_CANCEL"))
        btnCancel.OnEvent("Click", (*) => this.Close())

        ; --- Events ---
        myGui.OnEvent("Close", (*) => this.Close())
        myGui.OnEvent("Escape", (*) => this.Close())
        myGui.OnEvent("Size", (obj, minmax, w, h) => this.Resize(w, h))

        ; Populate and show
        this.RefreshPromptList()
        this.UpdateButtonStates()

        myGui.Show("w680 h640")
        ThemeHelper.ApplyImmersiveDarkMode(myGui.Hwnd)
    }

    ; --- Actions ---

    ; Add a new prompt.
    static AddPrompt() {
        result := PromptEditDialog.Show(
            Lang("TITLE_ADD_PROMPT"),
            "",
            ""
        )

        if result.Result != "OK"
            return

        if !PromptManager.Add(result.Name, result.Content) {
            ShowToolTip(Lang("MSG_PROMPT_DUPLICATE"), 2500)
            return
        }

        this.RefreshPromptList()
        ShowToolTip(Lang("MSG_PROMPT_SAVED"), 1500)
    }

    ; Edit the selected prompt.
    static EditPrompt() {
        idx := this._GetSelectedIndex()
        if idx == 0 {
            ShowToolTip(Lang("GUI_AI_SELECT_PROMPT"), 1500)
            return
        }

        p := PromptManager.Prompts[idx]
        result := PromptEditDialog.Show(
            Lang("TITLE_EDIT_PROMPT", "Edit Prompt"),
            p.name,
            p.content
        )

        if result.Result != "OK"
            return

        if !PromptManager.Update(idx, result.Name, result.Content) {
            ShowToolTip(Lang("MSG_PROMPT_DUPLICATE"), 2500)
            return
        }

        this.RefreshPromptList()
        ShowToolTip(Lang("MSG_PROMPT_SAVED"), 1500)
    }

    ; Delete the selected prompt.
    static DeletePrompt() {
        idx := this._GetSelectedIndex()
        if idx == 0 {
            ShowToolTip(Lang("GUI_AI_SELECT_PROMPT"), 1500)
            return
        }

        p := PromptManager.Prompts[idx]

        ; Confirm deletion
        hwnd := this.GuiObj.Hwnd
        WinSetAlwaysOnTop(0, "ahk_id " . hwnd)
        confirm := MsgBox(
            Lang("CONFIRM_DELETE_PROMPT", , p.name),
            Lang("MSG_CONFIRM"),
            "YesNo Icon?"
        )
        WinSetAlwaysOnTop(1, "ahk_id " . hwnd)

        if confirm != "Yes"
            return

        PromptManager.Delete(idx)
        this.RefreshPromptList()
        ShowToolTip(Lang("MSG_PROMPT_DELETED"), 1500)
    }

    ; Set the selected prompt as active.
    static SetActivePrompt() {
        idx := this._GetSelectedIndex()
        if idx == 0 {
            ShowToolTip(Lang("GUI_AI_SELECT_PROMPT"), 1500)
            return
        }

        name := PromptManager.Prompts[idx].name
        PromptManager.SetActive(name)
        this.RefreshPromptList()
        ShowToolTip(Lang("MSG_PROMPT_ACTIVE_SET", , name), 2000)
    }

    ; Test the API connection with current settings.
    ; Returns true on success, throws on failure.
    static TestConnection() {
        ; Temporarily save current settings to AppState
        tempUrl := AppState.ApiUrl
        tempKey := AppState.ApiKey
        tempModel := AppState.ApiModel
        tempMaxTokens := AppState.ApiMaxTokens
        tempTemp := AppState.ApiTemperature

        AppState.ApiUrl := this.UrlEdit.Value
        AppState.ApiKey := this.KeyEdit.Value
        AppState.ApiModel := this.ModelEdit.Value
        AppState.ApiMaxTokens := Integer(this.MaxTokensEdit.Value)

        try {
            AppState.ApiTemperature := Float(this.TempEdit.Value)
        } catch {
            AppState.ApiTemperature := 0.7
        }

        ; Show progress
        ShowToolTip(Lang("MSG_API_SENDING", "Testing API connection..."), 0)
        osdHwnd := OSD.currentHwnd 
        hwnd := this.GuiObj.Hwnd
        WinSetAlwaysOnTop(0, "ahk_id " . hwnd)

        try {
            ApiClient.TestConnection()
            MsgBox(
                Lang("MSG_API_TEST_SUCCESS", "Connection successful! The API is responding correctly."),
                Lang("MSG_SUCCESS", "Success"),
                "Iconi T2"
            )
        } catch as err {
            MsgBox(
                Lang("MSG_API_TEST_FAILED", "Connection test failed: {1}", err.Message),
                Lang("MSG_ERROR", "Error"),
                "Iconx T2"
            )
        } finally {
            OSD.DestroyOSD(osdHwnd)
        }

        WinSetAlwaysOnTop(1, "ahk_id " . hwnd)

        ; Restore original values
        AppState.ApiUrl := tempUrl
        AppState.ApiKey := tempKey
        AppState.ApiModel := tempModel
        AppState.ApiMaxTokens := tempMaxTokens
        AppState.ApiTemperature := tempTemp
    }

    ; Save settings and close.
    static SaveAndClose() {
        ; Validate and save API settings
        AppState.ApiUrl := Trim(this.UrlEdit.Value)
        AppState.ApiKey := this.KeyEdit.Value  ; Don't trim - key may have spaces
        AppState.ApiModel := Trim(this.ModelEdit.Value)

        try {
            AppState.ApiMaxTokens := Integer(this.MaxTokensEdit.Value)
            if AppState.ApiMaxTokens < 1
                AppState.ApiMaxTokens := 2000
        } catch {
            AppState.ApiMaxTokens := 2000
        }

        try {
            AppState.ApiTemperature := Float(this.TempEdit.Value)
            if AppState.ApiTemperature < 0
                AppState.ApiTemperature := 0
            if AppState.ApiTemperature > 2
                AppState.ApiTemperature := 2
        } catch {
            AppState.ApiTemperature := 0.7
        }

        ConfigManager.Save()
        ShowToolTip(Lang("MSG_API_SETTINGS_SAVED", "API settings saved."), 1500)
        this.Close()
    }

    ; Close the GUI without saving API settings (prompts are auto-saved on edit).
    static Close() {
        if IsObject(this.GuiObj) {
            try this.GuiObj.Destroy()
            this.GuiObj := ""
        }
        this.PromptLV := ""
        this.StatusText := ""
        this.UrlEdit := ""
        this.KeyEdit := ""
        this.ModelEdit := ""
        this.MaxTokensEdit := ""
        this.TempEdit := ""
    }

    ; --- UI Helpers ---

    ; Refresh the prompt ListView content.
    static RefreshPromptList() {
        if !IsObject(this.PromptLV)
            return

        this.PromptLV.Delete()

        for i, p in PromptManager.Prompts {
            ; Show preview of content (first 60 chars)
            preview := RegExReplace(p.content, "[\r\n]+", " ")
            if StrLen(preview) > 60
                preview := SubStr(preview, 1, 60) . "…"

            ; Mark active prompt with a star
            displayName := p.name
            if p.name == PromptManager.ActivePrompt
                displayName := "⭐ " . displayName

            this.PromptLV.Add(, displayName, preview)
        }

        this.PromptLV.ModifyCol(1, "AutoHdr")

        ; Update status text
        if IsObject(this.StatusText)
            this.StatusText.Value := this._BuildStatusText()

        this.UpdateButtonStates()
    }

    ; Update button enabled/disabled states based on selection.
    static UpdateButtonStates() {
        hasSelection := this._GetSelectedIndex() > 0

        ; Enable/disable Edit, Delete, Set Active buttons
        if IsObject(this.BtnEdit) {
            try this.BtnEdit.Enabled := hasSelection
        }
        if IsObject(this.BtnDelete) {
            try this.BtnDelete.Enabled := hasSelection
        }
        if IsObject(this.BtnSetActive) {
            try this.BtnSetActive.Enabled := hasSelection
        }
    }

    ; Build the status bar text.
    static _BuildStatusText() {
        total := PromptManager.Prompts.Length
        active := PromptManager.ActivePrompt

        if active == "" {
            return Lang("GUI_AI_NO_PROMPTS")
        }

        return Lang("GUI_AI_PROMPTS_CONFIGURED", , total, active)
    }

    ; Get the 1-based index of the selected prompt, or 0 if none.
    static _GetSelectedIndex() {
        if !IsObject(this.PromptLV)
            return 0

        row := this.PromptLV.GetNext(0)
        if row == 0
            return 0

        ; Get the display text and strip the star marker
        displayName := this.PromptLV.GetText(row, 1)
        actualName := StrReplace(displayName, "⭐ ", "")

        return PromptManager.FindByName(actualName)
    }

    ; Handle window resize.
    static Resize(w, h) {
        if !IsObject(this.PromptLV)
            return

        margin := 16
        minW := 680
        if w < minW
            w := minW

        ; Resize ListView
        lvW := w - margin * 2

        ; Freeze redrawing to prevent vertical line artifacts during resize
        SendMessage(0x000B, 0, 0, this.PromptLV.Hwnd)  ; WM_SETREDRAW, FALSE

        this.PromptLV.Move(margin, , lvW)
        this.PromptLV.ModifyCol(2, lvW - 190)

        SendMessage(0x000B, 1, 0, this.PromptLV.Hwnd)  ; WM_SETREDRAW, TRUE
        ; Force a single clean repaint after all changes
        DllCall("InvalidateRect", "Ptr", this.PromptLV.Hwnd, "Ptr", 0, "Int", 1)
    }
}
