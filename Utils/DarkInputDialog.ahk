#Requires AutoHotkey v2.0

class DarkInputDialog {
    static Confirm(prompt, title, owner := "", width := 420) {
        result := { Confirmed: false, Closed: false }
        ownerHwnd := IsObject(owner) ? owner.Hwnd : 0
        ownerOption := ownerHwnd ? " +Owner" ownerHwnd : ""
        myGui := Gui(ownerOption " -MaximizeBox -MinimizeBox", title)
        ThemeHelper.StyleGui(myGui)
        ThemeHelper.AddTitle(myGui, "⚠ " title, width - 24)
        myGui.SetFont("s10 c" Theme.Text, Theme.Font)
        myGui.Add("Text", "w" (width - 24) " y+10", prompt)

        confirmBtn := ThemeHelper.AddButton(myGui, "Default w100 y+18", Lang("GUI_OK", "OK"), "danger")
        cancelBtn := ThemeHelper.AddButton(myGui, "x+8 w100", Lang("GUI_CANCEL", "Cancel"))

        OnConfirm(*) {
            result.Confirmed := true
            result.Closed := true
            myGui.Hide()
            return true
        }
        OnCancel(*) {
            result.Closed := true
            myGui.Hide()
            return true
        }
        confirmBtn.OnEvent("Click", OnConfirm)
        cancelBtn.OnEvent("Click", OnCancel)
        myGui.OnEvent("Escape", OnCancel)
        myGui.OnEvent("Close", OnCancel)

        if ownerHwnd
            owner.Opt("+Disabled")
        ThemeHelper.ApplyWindowTheme(myGui.Hwnd)
        myGui.Show("AutoSize Center")
        while !result.Closed
            Sleep(10)

        try myGui.Destroy()
        if ownerHwnd {
            try owner.Opt("-Disabled")
            try WinActivate("ahk_id " ownerHwnd)
        }
        return result.Confirmed
    }

    static Show(prompt, title, default := "", width := 360) {
        result := {
            Result: "Cancel",
            Value: "",
            Closed: false
        }

        myGui := Gui("-MaximizeBox -MinimizeBox", title)
        ThemeHelper.StyleGui(myGui)
        ThemeHelper.AddTitle(myGui, "⚙️ " title, width - 20)

        myGui.SetFont("s10 c" Theme.TextSecondary, Theme.Font)
        myGui.Add("Text", "w" (width - 20) " y+8", prompt)
        myGui.SetFont("s10 c" Theme.Text, Theme.Font)

        editCtrl := myGui.Add(
            "Edit",
            "w" (width - 20) " r1 y+12 " ThemeHelper.GetEditOptions(),
            default
        )
        btnOK := ThemeHelper.AddButton(myGui, "Default w90 y+16", "✓ " Lang("GUI_OK"), "primary")
        btnCancel := ThemeHelper.AddButton(myGui, "x+8 w90", "✕ " Lang("GUI_CANCEL"))

        OnOK(*) {
            result.Value := editCtrl.Value
            result.Result := "OK"
            result.Closed := true
            myGui.Hide()
            return true
        }
        OnCancel(*) {
            result.Closed := true
            myGui.Hide()
            return true
        }
        btnOK.OnEvent("Click", OnOK)
        btnCancel.OnEvent("Click", OnCancel)
        myGui.OnEvent("Escape", OnCancel)
        myGui.OnEvent("Close", OnCancel)

        ThemeHelper.ApplyWindowTheme(myGui.Hwnd)
        myGui.Show("AutoSize Center")
        editCtrl.Focus()

        while !result.Closed {
            Sleep(10)
        }

        try myGui.Destroy()

        return {
            Result: result.Result,
            Value: result.Value
        }
    }
}
