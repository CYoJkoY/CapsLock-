#Requires AutoHotkey v2.0

class DarkInputDialog {
    static Show(prompt, title, default := "", width := 360) {
        dialogState := {
            Result: "Cancel",
            Value: "",
            Resolved: false
        }

        myGui := Gui("+AlwaysOnTop -MaximizeBox -MinimizeBox", title)
        ThemeHelper.StyleGui(myGui)
        ThemeHelper.AddTitle(myGui, "⚙️ " title, width - 20)

        myGui.SetFont("s10 c" AppState.THEME_FG_DIM, AppState.THEME_FONT)
        myGui.Add("Text", "w" (width - 20) " y+8", prompt)
        myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)

        editCtrl := myGui.Add(
            "Edit",
            "w" (width - 20) " r1 y+12 " ThemeHelper.GetEditOptions(),
            default
        )
        btnOK := ThemeHelper.AddButton(myGui, "Default w90 y+16", "✓ " Lang("GUI_OK"), "primary")
        btnCancel := ThemeHelper.AddButton(myGui, "x+8 w90", "✕ " Lang("GUI_CANCEL"))

        OnOK(*) {
            dialogState.Value := editCtrl.Value
            dialogState.Result := "OK"
            dialogState.Resolved := true
            myGui.Destroy()
            return true
        }
        OnCancel(*) {
            if !dialogState.Resolved
                dialogState.Result := "Cancel"
            myGui.Destroy()
            return true
        }
        btnOK.OnEvent("Click", OnOK)
        btnCancel.OnEvent("Click", OnCancel)
        myGui.OnEvent("Escape", OnCancel)
        myGui.OnEvent("Close", OnCancel)

        ThemeHelper.ApplyImmersiveDarkMode(myGui.Hwnd)
        myGui.Show("AutoSize Center")
        editCtrl.Focus()
        WinWaitClose("ahk_id " myGui.Hwnd)
        return dialogState
    }
}
