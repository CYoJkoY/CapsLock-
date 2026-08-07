#Requires AutoHotkey v2.0

; Dialog for adding or editing an AI prompt (name + multi-line content).
; Uses the project's dark theme via ThemeHelper.
class PromptEditDialog {
    ; Show the dialog and return { action: "OK"|"Cancel", name: str, content: str }.
    ; Pass existing name and content for edit mode; leave blank for add mode.
    ;
    ; Parameters:
    ;   title        - Dialog title
    ;   existingName - Pre-filled prompt name (empty for new prompts)
    ;   existingContent - Pre-filled prompt content (empty for new prompts)
    ;
    ; Returns: Object with Result ("OK"|"Cancel"), Name, and Content fields.
    static Show(title, existingName := "", existingContent := "") {
        resultName := ""
        resultContent := ""
        resultAction := "Cancel"

        myGui := Gui("+AlwaysOnTop -MaximizeBox -MinimizeBox +OwnDialogs", title)
        ThemeHelper.StyleGui(myGui)
        ThemeHelper.AddTitle(myGui, "📝 " . title, 500)

        ; Prompt name field
        myGui.SetFont("s10 c" AppState.THEME_FG_DIM, AppState.THEME_FONT)
        myGui.Add("Text", "w480 y+8", Lang("GUI_AI_PROMPT_NAME", "Prompt Name"))
        myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)
        nameEdit := myGui.Add(
            "Edit",
            "w480 r1 y+4 " . ThemeHelper.GetEditOptions(),
            existingName
        )
        nameEdit.Focus()

        ; Prompt content field
        myGui.SetFont("s10 c" AppState.THEME_FG_DIM, AppState.THEME_FONT)
        myGui.Add("Text", "w480 y+12", Lang("GUI_AI_PROMPT_CONTENT", "Prompt Content"))
        myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT_MONO)
        contentEdit := myGui.Add(
            "Edit",
            "Multi VScroll w480 h200 y+4 " . ThemeHelper.GetEditOptions(),
            existingContent
        )
        myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)

        ; Buttons
        btnOK := ThemeHelper.AddButton(myGui, "Default w90 y+16", "✓ " . Lang("GUI_OK"), "primary")
        btnCancel := ThemeHelper.AddButton(myGui, "x+8 w90", "✕ " . Lang("GUI_CANCEL"))

        OnOK(*) {
            resultName := Trim(nameEdit.Value)
            resultContent := Trim(contentEdit.Value, " `t`r`n")

            if resultName == "" {
                ShowToolTip(Lang("MSG_PROMPT_NAME_EMPTY", "Prompt name cannot be empty."), 2000)
                return
            }
            if resultContent == "" {
                ShowToolTip(Lang("MSG_PROMPT_CONTENT_EMPTY", "Prompt content cannot be empty."), 2000)
                return
            }

            resultAction := "OK"
            myGui.Destroy()
        }

        OnCancel(*) {
            resultAction := "Cancel"
            myGui.Destroy()
        }

        btnOK.OnEvent("Click", OnOK)
        btnCancel.OnEvent("Click", OnCancel)
        myGui.OnEvent("Escape", OnCancel)
        myGui.OnEvent("Close", OnCancel)

        myGui.Show("AutoSize Center")
        ThemeHelper.ApplyImmersiveDarkMode(myGui.Hwnd)
        WinWaitClose("ahk_id " . myGui.Hwnd)

        return { Result: resultAction, Name: resultName, Content: resultContent }
    }
}
