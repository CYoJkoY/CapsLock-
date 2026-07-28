#Requires AutoHotkey v2.0

class DarkInputDialog {
    static Show(prompt, title, default := "", width := 360) {
        resultValue := ""
        resultAction := "Cancel"

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
        editCtrl.Focus()

        btnOK := ThemeHelper.AddButton(myGui, "Default w90 y+16", "✓ OK", "primary")
        btnCancel := ThemeHelper.AddButton(myGui, "x+8 w90", "✕ Cancel")

        OnOK(*) {
            resultValue := editCtrl.Value
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
        WinWaitClose("ahk_id " myGui.Hwnd)
        return { Result: resultAction, Value: resultValue }
    }
}
