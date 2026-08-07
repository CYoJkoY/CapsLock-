#Requires AutoHotkey v2.0

; Handles the CapsLock+K hotkey: sends active prompt + clipboard content
; to the configured AI API and pastes the response at the cursor position.

SendToApiAndPaste() {
    ; Validate configuration
    if (AppState.ApiUrl == "" || AppState.ApiKey == "") {
        ShowToolTip(Lang("MSG_API_URL_NOT_SET", "API not configured. Open AI Settings to configure."), 3000)
        return
    }

    ; Check active prompt
    activeContent := PromptManager.GetActiveContent()
    if (activeContent == "") {
        ShowToolTip(Lang("MSG_API_NO_PROMPT", "No active prompt selected. Open AI Settings to configure."), 3000)
        return
    }

    ; Get clipboard content
    clipboardContent := A_Clipboard
    if (clipboardContent == "") {
        ShowToolTip(Lang("MSG_API_CLIPBOARD_EMPTY", "Clipboard is empty. Copy some text first."), 2500)
        return
    }

    ; Capture the current target window for pasting
    CapturePasteTarget()

    ; Save original clipboard to restore after
    originalClipboard := A_Clipboard

    ; Show progress notification
    progressGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border")
    ThemeHelper.StyleGui(progressGui)
    ThemeHelper.AddTitle(progressGui, "⏳ " . Lang("MSG_API_SENDING", "Sending request to AI..."), 360)
    ThemeHelper.AddSubtitle(progressGui, Lang("MSG_PROCESSING_WAIT", "Please wait..."), 360)
    progressGui.Add("Text", "x16 y+8 w330 center c" . AppState.THEME_FG_DIM,
        Lang("MSG_API_SENDING", "Waiting for response..."))
    progressGui.Show("AutoSize Center")
    ThemeHelper.ApplyImmersiveDarkMode(progressGui.Hwnd)

    ; Call API
    responseText := ""
    hasError := false
    errorMessage := ""

    try {
        responseText := ApiClient.Send(activeContent, clipboardContent)
    } catch as err {
        hasError := true
        errorMessage := err.Message
    }

    ; Destroy progress GUI
    try progressGui.Destroy()

    ; Handle response
    if hasError || responseText == "" {
        ; Show error
        errorMsg := errorMessage != "" ? errorMessage : Lang("MSG_API_PARSE_ERROR", "Empty response from API.")
        ShowToolTip(errorMsg, 4000)

        ; Restore clipboard
        AppState.IgnoreNextClipChange := true
        A_Clipboard := originalClipboard
        return
    }

    ; Paste the response
    ; Trim any leading/trailing whitespace that APIs commonly add
    responseText := Trim(responseText, " `t`r`n")

    ; Use PasteAsPlainText to handle the paste + clipboard restore
    PasteAsPlainText(responseText, Lang("MSG_API_SUCCESS", "AI response pasted."))
}
