#Requires AutoHotkey v2.0

class DarkInputDialog {
    static Confirm(prompt, title, owner := "", width := 420) {
        result := { Confirmed: false, Closed: false }
        ownerHwnd := IsObject(owner) ? owner.Hwnd : 0
        ownerOption := ownerHwnd ? " +Owner" ownerHwnd : ""
        myGui := Gui(ownerOption " -MaximizeBox -MinimizeBox", title)
        ThemeHelper.StyleGui(myGui)
        ThemeHelper.AddTitle(myGui, " " title, width - 24)
        myGui.SetFont("s10 c" Theme.Text, ThemeHelper.ReadingStack())
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
        ThemeHelper.AddTitle(myGui, " " title, width - 20)

        myGui.SetFont("s10 c" Theme.TextSecondary, ThemeHelper.ReadingStack())
        myGui.Add("Text", "w" (width - 20) " y+8", prompt)
        myGui.SetFont("s10 c" Theme.Text, ThemeHelper.ReadingStack())

        editCtrl := myGui.Add(
            "Edit",
            "w" (width - 20) " r1 y+12 " ThemeHelper.GetEditOptions(),
            default
        )
        btnOK := ThemeHelper.AddButton(myGui, "Default w90 y+16", Lang("GUI_OK"), "primary")
        btnCancel := ThemeHelper.AddButton(myGui, "x+8 w90", Lang("GUI_CANCEL"))

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

; Keep application feedback inside the shared Wabi Press visual system instead
; of falling back to Windows' unthemed message boxes. Return values follow the
; AutoHotkey MsgBox contract used by existing callers.
WabiMessageBox(text, title := "", options := "") {
    optionText := String(options)
    title := title == "" ? "CapsLock-" : String(title)
    message := String(text)
    isYesNo := InStr(optionText, "YesNo") > 0
    defaultNo := isYesNo && InStr(optionText, "256") > 0
    timeoutSeconds := RegExMatch(optionText, "i)T(\d+)", &timeoutMatch)
        ? Integer(timeoutMatch[1])
        : 0

    iconColor := Theme.Focus
    iconGlyph := "·"
    if InStr(optionText, "Iconx") {
        iconColor := Theme.Cinnabar
        iconGlyph := "×"
    } else if InStr(optionText, "Iconi") {
        iconColor := Theme.Moss
        iconGlyph := "✓"
    } else if InStr(optionText, "Icon!") {
        iconColor := Theme.Ochre
        iconGlyph := "!"
    } else if InStr(optionText, "Icon?") {
        iconColor := Theme.Focus
        iconGlyph := "?"
    }

    width := 500
    bodyRows := 3
    estimatedRows := 0
    for line in StrSplit(message, "`n", "`r")
        estimatedRows += Max(1, Ceil(StrLen(line) / 68))
    bodyRows := Max(3, Min(9, estimatedRows))

    result := { Value: "", Closed: false }
    myGui := Gui("-MaximizeBox -MinimizeBox +ToolWindow", title)
    ThemeHelper.StyleGui(myGui)
    ThemeHelper.AddTitle(myGui, title, width - 40)
    myGui.SetFont("s10 c" Theme.TextSecondary, ThemeHelper.ReadingStack())
    myGui.Add("Text", "x18 y+8 w2 h34 Background" iconColor)
    icon := myGui.Add("Text", "x30 yp-2 w28 h30 Center Background" Theme.Background, iconGlyph)
    ThemeHelper.MarkSurface(icon, iconColor, Theme.Background)

    body := myGui.Add(
        "Edit",
        "x68 yp w" (width - 88) " r" bodyRows " ReadOnly -E0x200 Wrap " ThemeHelper.GetEditOptions(),
        message
    )
    ThemeHelper.StyleEdit(body)

    if isYesNo {
        yesBtn := ThemeHelper.AddButton(
            myGui,
            (defaultNo ? "x" : "Default x") "260 y+14 w104",
            Lang("DIALOG_YES", "Yes"),
            "primary"
        )
        noBtn := ThemeHelper.AddButton(
            myGui,
            (defaultNo ? "Default x" : "x") "372 yp w104",
            Lang("DIALOG_NO", "No"),
            "secondary"
        )
        yesBtn.OnEvent("Click", (*) => Finish("Yes"))
        noBtn.OnEvent("Click", (*) => Finish("No"))
    } else {
        okBtn := ThemeHelper.AddButton(
            myGui,
            "Default x" (width - 132) " y+14 w104",
            Lang("GUI_OK", "OK"),
            "primary"
        )
        okBtn.OnEvent("Click", (*) => Finish("OK"))
    }

    myGui.OnEvent("Escape", (*) => Finish(isYesNo ? "No" : "OK"))
    myGui.OnEvent("Close", (*) => Finish(isYesNo ? "No" : "OK"))
    ThemeHelper.ApplyWindowTheme(myGui.Hwnd)
    myGui.Show("AutoSize Center")

    if timeoutSeconds > 0
        SetTimer((*) => Finish("Timeout"), -timeoutSeconds * 1000)

    while !result.Closed
        Sleep(10)

    try myGui.Destroy()
    return result.Value

    Finish(value) {
        if result.Closed
            return
        result.Value := value
        result.Closed := true
        try myGui.Hide()
    }
}
