#Requires AutoHotkey v2.0

ShowPreviewGui(text) {
    myGui := Gui("+AlwaysOnTop +Resize +MinSize500x350", Lang("GUI_PREVIEW_TITLE"))
    ThemeHelper.StyleGui(myGui)
    ThemeHelper.AddTitle(myGui, "👁️ " Lang("GUI_PREVIEW_TITLE"), 600)

    lineCount := StrSplit(text, "`n").Length
    charCount := StrLen(text)
    ThemeHelper.AddSubtitle(myGui,
        lineCount " lines  •  " charCount " characters", 600)
    ThemeHelper.AddSeparator(myGui, 600)

    myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT_MONO)
    myEdit := myGui.Add(
        "Edit",
        "ReadOnly VScroll Wrap w600 h350 " ThemeHelper.GetEditOptions(),
        text
    )
    myGui.SetFont("s10 c" AppState.THEME_FG, AppState.THEME_FONT)

    btnCopy := ThemeHelper.AddButton(myGui, "Default w100", "📋 Copy", "primary")
    btnCopy.OnEvent("Click", (*) => (
        A_Clipboard := text,
        ShowToolTip(Lang("MSG_COPIED", , "Copied!"), 1000)
    ))

    btn := ThemeHelper.AddButton(myGui, "x+8 yp w80", Lang("GUI_PREVIEW_CLOSE"))
    btn.OnEvent("Click", (*) => myGui.Destroy())

    myGui.OnEvent("Size", (obj, minmax, w, h) => (
        myEdit.Move(16, 80, w - 32, h - 130),
        btnCopy.Move(16, h - 42),
        btn.Move(124, h - 42)
    ))
    myGui.OnEvent("Escape", (*) => myGui.Destroy())

    myGui.Show("w640 h480")
    ThemeHelper.ApplyImmersiveDarkMode(myGui.Hwnd)
}
