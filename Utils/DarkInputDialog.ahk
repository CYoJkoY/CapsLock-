#Requires AutoHotkey v2.0

class DarkInputDialog {
    static Show(prompt, title, default := "", width := 360) {
        resultValue := ""
        resultAction := "Cancel"

        myGui := Gui("+AlwaysOnTop -MaximizeBox -MinimizeBox", title)
        ThemeHelper.StyleGui(myGui)

        ; 标题图标
        ThemeHelper.AddTitle(myGui, "⚙️ " title, width - 20)

        ; 提示文字
        myGui.SetFont("s10 c" AppState.THEME_FG_DIM, AppState.THEME_FONT)
        myGui.Add("Text", "w" (width - 20) " y+8", prompt)
        myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)

        ; 输入框
        editCtrl := myGui.Add(
            "Edit",
            "w" (width - 20) " r1 y+12 " ThemeHelper.GetEditOptions(),
            default
        )
        editCtrl.Focus()

        ; 按钮行
        btnOK := myGui.Add(
            "Button",
            "Default w90 y+16 " ThemeHelper.GetButtonPrimary(),
            "✓ OK"
        )
        btnCancel := myGui.Add(
            "Button",
            "x+8 w90 " ThemeHelper.GetButtonSecondary(),
            "✕ Cancel"
        )

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
