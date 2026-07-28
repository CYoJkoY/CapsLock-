#Requires AutoHotkey v2.0

class DarkInputDialog {
    static Show(prompt, title, default := "", width := 300) {
        resultValue := ""
        resultAction := "Cancel"

        myGui := Gui("+AlwaysOnTop -MaximizeBox -MinimizeBox", title)
        ThemeHelper.StyleGui(myGui)

        myGui.SetFont("s10")
        myGui.Add("Text", "w" (width - 20), prompt)

        editCtrl := myGui.Add(
            "Edit",
            "w" (width - 20) " r1 " ThemeHelper.GetEditOptions(),
            default
        )
        editCtrl.Focus()

        btnOK := myGui.Add(
            "Button",
            "Default w80 " ThemeHelper.GetButtonOptions(),
            "OK"
        )
        btnCancel := myGui.Add(
            "Button",
            "x+10 w80 " ThemeHelper.GetButtonOptions(),
            "Cancel"
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
