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

        myGui := Gui("+Resize +MinSize600x500 +OwnDialogs", Lang("GUI_AI_SETTINGS_TITLE", "AI API Settings"))
        ThemeHelper.StyleGui(myGui)

        ; Store reference for resize handling
        this.GuiObj := myGui

        ; --- Title ---
        ThemeHelper.AddTitle(myGui, "🤖 " . Lang("GUI_AI_SETTINGS_TITLE", "AI API Settings"), 580)
        ThemeHelper.AddSubtitle(myGui,
            Lang("GUI_AI_SETTINGS_SUBTITLE", "Configure API endpoint and manage prompts"), 580)
        ThemeHelper.AddSeparator(myGui, 580)

        ; --- API Configuration Section ---
        myGui.SetFont("s11 Bold c" AppState.THEME_ACCENT, AppState.THEME_FONT)
        myGui.Add("Text", "x16 y+14 w580", Lang("GUI_AI_API_SECTION", "API Configuration"))
        myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)

        ; API URL
        myGui.Add("Text", "x16 y+12 w100", Lang("GUI_AI_URL", "API URL:"))
        urlEdit := myGui.Add("Edit", "x120 yp-2 w460 r1 " . ThemeHelper.GetEditOptions(), AppState.ApiUrl)
        this.UrlEdit := urlEdit

        ; API Key
        myGui.Add("Text", "x16 y+10 w100", Lang("GUI_AI_KEY", "API Key:"))
        keyEdit := myGui.Add("Edit", "x120 yp-2 w460 r1 Password " . ThemeHelper.GetEditOptions(), AppState.ApiKey)
        this.KeyEdit := keyEdit

        ; Model
        myGui.Add("Text", "x16 y+10 w100", Lang("GUI_AI_MODEL", "Model:"))
        modelEdit := myGui.Add("Edit", "x120 yp-2 w180 r1 " . ThemeHelper.GetEditOptions(), AppState.ApiModel)
        this.ModelEdit := modelEdit

        ; Max Tokens (on same row as Model, with more room)
        myGui.Add("Text", "x330 yp+2 w100", Lang("GUI_AI_MAX_TOKENS", "Max Tokens:"))
        maxTokensEdit := myGui.Add("Edit", "x440 yp-2 w70 r1 " . ThemeHelper.GetEditOptions(), AppState.ApiMaxTokens)
        this.MaxTokensEdit := maxTokensEdit

        ; Temperature
        myGui.Add("Text", "x16 y+10 w110", Lang("GUI_AI_TEMPERATURE", "Temperature:"))
        tempEdit := myGui.Add("Edit", "x130 yp-2 w70 r1 " . ThemeHelper.GetEditOptions(), AppState.ApiTemperature)
        this.TempEdit := tempEdit

        ; Test Connection button
        btnTest := ThemeHelper.AddButton(myGui, "x+16 yp w160", "🔗 " . Lang("GUI_AI_TEST", "Test Connection"))
        btnTest.OnEvent("Click", (*) => this.TestConnection())

        ; --- Prompts Section ---
        ThemeHelper.AddSeparator(myGui, 580)

        myGui.SetFont("s11 Bold c" AppState.THEME_ACCENT, AppState.THEME_FONT)
        myGui.Add("Text", "x16 y+10 w580", Lang("GUI_AI_PROMPTS_SECTION", "Prompts"))
        myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)

        ; Prompt ListView
        lv := myGui.Add(
            "ListView",
            "x16 y+10 w568 r8 -Multi " . ThemeHelper.GetLVOptions(),
            [Lang("GUI_AI_PROMPT_NAME", "Name"), Lang("GUI_AI_PROMPT_CONTENT", "Content")]
        )
        lv.ModifyCol(1, 180)
        lv.ModifyCol(2, 370)
        lv.OnEvent("DoubleClick", (*) => this.EditPrompt())
        lv.OnEvent("ItemSelect", (*) => this.UpdateButtonStates())
        ThemeHelper.StyleListView(lv)
        this.PromptLV := lv

        ; Prompt action buttons (wider to prevent text wrapping)
        btnAdd := ThemeHelper.AddButton(myGui, "x16 y+10 w100", "➕ " . Lang("GUI_AI_ADD_PROMPT", "Add"))
        btnAdd.OnEvent("Click", (*) => this.AddPrompt())

        btnEdit := ThemeHelper.AddButton(myGui, "x+8 yp w100", "✏️ " . Lang("GUI_AI_EDIT_PROMPT", "Edit"))
        btnEdit.OnEvent("Click", (*) => this.EditPrompt())
        this.BtnEdit := btnEdit

        btnDelete := ThemeHelper.AddButton(myGui, "x+8 yp w100", "🗑️ " . Lang("GUI_AI_DELETE_PROMPT", "Delete"), "danger")
        btnDelete.OnEvent("Click", (*) => this.DeletePrompt())
        this.BtnDelete := btnDelete

        btnSetActive := ThemeHelper.AddButton(myGui, "x+8 yp w120", "⭐ " . Lang("GUI_AI_SET_ACTIVE", "Set Active"), "primary")
        btnSetActive.OnEvent("Click", (*) => this.SetActivePrompt())
        this.BtnSetActive := btnSetActive

        ; Status bar
        ThemeHelper.AddSeparator(myGui, 580)
        statusText := myGui.Add(
            "Text",
            "x16 y+10 w568",
            this._BuildStatusText()
        )
        myGui.SetFont("s9 c" AppState.THEME_FG_MUTED, AppState.THEME_FONT)
        this.StatusText := statusText

        ; Bottom buttons (wider, more spacing)
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

        myGui.Show("w620 h580")
        ThemeHelper.ApplyImmersiveDarkMode(myGui.Hwnd)
    }

    ; --- Actions ---

    ; Add a new prompt.
    static AddPrompt() {
        result := PromptEditDialog.Show(
            Lang("TITLE_ADD_PROMPT", "Add New Prompt"),
            "",
            ""
        )

        if result.Result != "OK"
            return

        if !PromptManager.Add(result.Name, result.Content) {
            ShowToolTip(Lang("MSG_PROMPT_DUPLICATE", "A prompt with this name already exists."), 2500)
            return
        }

        this.RefreshPromptList()
        ShowToolTip(Lang("MSG_PROMPT_SAVED", "Prompt saved."), 1500)
    }

    ; Edit the selected prompt.
    static EditPrompt() {
        idx := this._GetSelectedIndex()
        if idx == 0 {
            ShowToolTip(Lang("GUI_AI_SELECT_PROMPT", "Please select a prompt first."), 1500)
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
            ShowToolTip(Lang("MSG_PROMPT_DUPLICATE", "A prompt with this name already exists."), 2500)
            return
        }

        this.RefreshPromptList()
        ShowToolTip(Lang("MSG_PROMPT_SAVED", "Prompt saved."), 1500)
    }

    ; Delete the selected prompt.
    static DeletePrompt() {
        idx := this._GetSelectedIndex()
        if idx == 0 {
            ShowToolTip(Lang("GUI_AI_SELECT_PROMPT", "Please select a prompt first."), 1500)
            return
        }

        p := PromptManager.Prompts[idx]

        ; Confirm deletion
        hwnd := this.GuiObj.Hwnd
        WinSetAlwaysOnTop(0, "ahk_id " . hwnd)
        confirm := MsgBox(
            Lang("CONFIRM_DELETE_PROMPT", "Are you sure you want to delete the prompt '{1}'?", p.name),
            Lang("MSG_CONFIRM", "Confirm"),
            "YesNo Icon?"
        )
        WinSetAlwaysOnTop(1, "ahk_id " . hwnd)

        if confirm != "Yes"
            return

        PromptManager.Delete(idx)
        this.RefreshPromptList()
        ShowToolTip(Lang("MSG_PROMPT_DELETED", "Prompt deleted."), 1500)
    }

    ; Set the selected prompt as active.
    static SetActivePrompt() {
        idx := this._GetSelectedIndex()
        if idx == 0 {
            ShowToolTip(Lang("GUI_AI_SELECT_PROMPT", "Please select a prompt first."), 1500)
            return
        }

        name := PromptManager.Prompts[idx].name
        PromptManager.SetActive(name)
        this.RefreshPromptList()
        ShowToolTip(Lang("MSG_PROMPT_ACTIVE_SET", "Active prompt set to: {1}", name), 2000)
    }

    ; Test the API connection with current settings.
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
            return Lang("GUI_AI_NO_PROMPTS", "No prompts configured. Add one to get started.")
        }

        return total . " prompt(s) configured  |  Active: " . active
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
        minW := 600
        if w < minW
            w := minW

        ; Resize ListView
        lvW := w - margin * 2
        this.PromptLV.Move(margin, , lvW)
        this.PromptLV.ModifyCol(2, lvW - 190)
    }
}
