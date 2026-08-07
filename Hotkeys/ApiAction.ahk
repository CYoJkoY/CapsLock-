#Requires AutoHotkey v2.0

; =========================================================================
; Handles the CapsLock+K hotkey: opens a read-only GUI window showing the
; AI response. The user can press C to copy the entire content, or K to
; output the content at the current cursor position.
; =========================================================================

; ---------------------------------------------------------------------------
; AI Result Window – displays the response and handles C/K hotkeys
; ---------------------------------------------------------------------------
class AIResultWindow {
    static GuiObj := ""
    static TargetWindow := 0
    static Content := ""
    static _buffer := ""
    static _updateTimer := ""
    static _pending := false

    ; Show a new result window. Closes any existing window first.
    static Show(content, targetHwnd) {
        this.Close()
        this.Content := content
        this.TargetWindow := targetHwnd
        this._buffer := ""

        myGui := Gui("+AlwaysOnTop +Resize +MinSize600x400", Lang("GUI_AI_RESULT_TITLE"))
        ThemeHelper.StyleGui(myGui)

        ; Title
        ThemeHelper.AddTitle(myGui, "🤖 " . Lang("GUI_AI_RESULT_TITLE"), 560)

        ; Content edit – read‑only, multi‑line, monospace
        myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT_MONO)
        editCtrl := myGui.Add("Edit", "Multi VScroll ReadOnly w560 h300 " ThemeHelper.GetEditOptions(), content)
        myGui.editCtrl := editCtrl   ; store reference

        ; Bottom hint
        myGui.SetFont("s9 c" AppState.THEME_FG_DIM, AppState.THEME_FONT)
        myGui.Add("Text", "x16 y+8 w560 center", Lang("GUI_AI_RESULT_HINT"))

        ; Event handlers
        myGui.OnEvent("Close", (*) => this.Close())
        myGui.OnEvent("Escape", (*) => this.Close())

        this.GuiObj := myGui
        myGui.Show("w640 h480")
        ThemeHelper.ApplyImmersiveDarkMode(myGui.Hwnd)

        ; Install the keyboard hook only once
        static keyHandlerRegistered := false
        if !keyHandlerRegistered {
            OnMessage(0x100, this.KeyHandler.Bind(this))
            keyHandlerRegistered := true
        }
    }

    ; Close and clean up the window
    static Close() {
        if this._updateTimer
            SetTimer(this._updateTimer, 0)

        if IsObject(this.GuiObj) {
            try this.GuiObj.Destroy()
            this.GuiObj := ""
        }

        this.Content := ""
        this.TargetWindow := 0
        this._buffer := ""
        this._pending := false
    }

    ; Append text to buffer and schedule a flush
    static AppendToCurrent(text) {
        if !IsObject(this.GuiObj)
            return
        this._buffer .= text
        if !this._pending {
            this._pending := true
            this._updateTimer := ObjBindMethod(this, "FlushBuffer")
            SetTimer(this._updateTimer, -50)   ; flush after 50ms of inactivity
        }
    }

    ; Flush accumulated buffer to the edit control
    static FlushBuffer() {
        this._pending := false
        this._updateTimer := ""
        if !IsObject(this.GuiObj) || this._buffer == ""
            return
        try {
            if this.GuiObj.HasProp("editCtrl") {
                current := this.GuiObj.editCtrl.Value
                this.GuiObj.editCtrl.Value := current . this._buffer
                SendMessage(0x00B1, 0, -1, this.GuiObj.editCtrl.Hwnd)   ; scroll to bottom
                this._buffer := ""
            }
        }
    }

    ; WM_KEYDOWN handler – responds to C and K when the result window is active
    static KeyHandler(wParam, lParam, msg, hwnd) {
        ; Ignore if the message does not belong to our window
        if !IsObject(this.GuiObj) || this.GuiObj.Hwnd != hwnd
            return

        ; Ignore modifier keys to avoid interfering with normal shortcuts
        if GetKeyState("Ctrl", "P") || GetKeyState("Alt", "P") || GetKeyState("Shift", "P")
            return

        vkCode := wParam
        if (vkCode == 0x43) { ; C key – copy all content
            A_Clipboard := this.Content
            OSD.ShowNotification(Lang("GUI_AI_RESULT_COPY_TOAST"), 1500, "success")
            return 0
        }
        else if (vkCode == 0x4B) { ; K key – output content
            if (this.Content == "") {
                OSD.ShowNotification(Lang("GUI_AI_RESULT_EMPTY"), 1500, "warning")
                return 0
            }

            target := this.TargetWindow
            ; Fallback to the currently active window if the captured one is gone
            if !target || !WinExist("ahk_id " target) {
                target := WinExist("A")
                if !target {
                    OSD.ShowNotification(Lang("MSG_NO_TARGET"), 2000, "error")
                    return 0
                }
                this.TargetWindow := target
            }

            ; Temporarily set clipboard to the content, paste, then restore
            backup := A_Clipboard
            AppState.IgnoreNextClipChange := true
            A_Clipboard := this.Content

            WinActivate("ahk_id " target)
            Sleep(100)
            Send("^v")
            Sleep(50)

            AppState.IgnoreNextClipChange := true
            A_Clipboard := backup

            OSD.ShowNotification(Lang("GUI_AI_RESULT_OUTPUT_TOAST"), 1500, "info")
            return 0
        }
    }
}

; ---------------------------------------------------------------------------
; Main entry point called by CapsLock+K
; ---------------------------------------------------------------------------
SendToApiAndPaste() {
    ; Validate API configuration
    if (AppState.ApiUrl == "" || AppState.ApiKey == "") {
        ShowToolTip(Lang("MSG_API_URL_NOT_SET"), 3000)
        return
    }

    ; Check active prompt
    activeContent := PromptManager.GetActiveContent()
    if (activeContent == "") {
        ShowToolTip(Lang("MSG_API_NO_PROMPT"), 3000)
        return
    }

    ; Get clipboard content
    clipboardContent := A_Clipboard
    if (clipboardContent == "") {
        ShowToolTip(Lang("MSG_API_CLIPBOARD_EMPTY"), 2500)
        return
    }

    ; Capture the target window for later pasting (K key)
    CapturePasteTarget()

    ; Show progress GUI
    progressGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border")
    ThemeHelper.StyleGui(progressGui)
    ThemeHelper.AddTitle(progressGui, "⏳ " . Lang("MSG_API_SENDING", "Sending request to AI..."), 360)
    ThemeHelper.AddSubtitle(progressGui, Lang("MSG_PROCESSING_WAIT", "Please wait..."), 360)
    progressGui.Add("Text", "x16 y+8 w330 center c" . AppState.THEME_FG_DIM,
        Lang("MSG_API_SENDING", "Waiting for response..."))
    progressGui.Show("AutoSize Center")
    ThemeHelper.ApplyImmersiveDarkMode(progressGui.Hwnd)

    ; Call the API
    responseText := ""
    hasError := false
    errorMessage := ""

    if AppState.ApiStreamMode {
        ; Streaming mode: show result window immediately
        AIResultWindow.Show("", AppState.TargetWindow)   ; empty content initially
        ; Define a callback that appends text to the window
        callback := (chunk) => AIResultWindow.AppendToCurrent(chunk)
        try {
            ApiClient.Send(activeContent, clipboardContent, callback)
            ; Streaming mode does not return a final content; it's displayed via callback.
            ; Mark that we have started streaming successfully.
            responseText := "STREAMING"   ; placeholder to avoid empty-response error
        } catch as err {
            hasError := true
            errorMessage := err.Message
            AIResultWindow.Close()
        }
    } else {
        ; Classic mode: wait for full response
        try {
            responseText := ApiClient.Send(activeContent, clipboardContent)
        } catch as err {
            hasError := true
            errorMessage := err.Message
        }
    }

    ; Close progress GUI
    try progressGui.Destroy()

    ; Handle errors
    if hasError {
        errorMsg := errorMessage != "" ? errorMessage : Lang("MSG_API_PARSE_ERROR", "Empty response from API.")
        ShowToolTip(errorMsg, 4000)
        return
    }

    ; For streaming mode, we already displayed the response; nothing else to do.
    if AppState.ApiStreamMode {
        return
    }

    ; Classic mode: trim and display
    responseText := Trim(responseText, " `t`r`n")
    if (responseText == "") {
        ShowToolTip(Lang("MSG_API_PARSE_ERROR", "Empty response from API."), 4000)
        return
    }

    ; Show the result window (does not modify clipboard)
    AIResultWindow.Show(responseText, AppState.TargetWindow)
}
