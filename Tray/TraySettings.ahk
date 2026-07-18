#Requires AutoHotkey v2.0

SetPasteMode( mode ) {
    AppState.PasteMode := mode
    ConfigManager.Save()
    TrayMenuRefresh()
    ToolTip( mode == 1 ? Lang( "MSG_PASTE_MODE_FILE" ) : Lang( "MSG_PASTE_MODE_TEXT" ) )
    SetTimer( () => ToolTip(), -2000 )
}

SetDeleteMode( mode ) {
    AppState.DeleteMode := mode
    ConfigManager.Save()
    TrayMenuRefresh()
    msgs := [ Lang( "MSG_DELETE_MODE_DELAY" ), Lang( "MSG_DELETE_MODE_BATCH" ), Lang( "MSG_DELETE_MODE_NEVER" ) ]
    ToolTip( msgs[ mode ] )
    SetTimer( () => ToolTip(), -2000 )
}

SetMaxHistory( * ) {
    input := InputBox( Lang( "INPUT_MAX_HISTORY_PROMPT" ), Lang( "INPUT_MAX_HISTORY_TITLE" ), "w300 h120", AppState.MaxHistory )
    if input.Result != "OK" || !IsNumber( input.Value )
        return
    newMax := Integer( input.Value )
    if newMax < 0
        newMax := 0
    if newMax == 0 {
        if AppState.History.Length > 0 {
            confirm := MsgBox( Lang( "CONFIRM_DISABLE_HISTORY", , AppState.History.Length ), Lang( "MSG_CONFIRM" ), "YesNo Icon?" )
            if confirm != "Yes"
                return
        }
        AppState.MaxHistory := 0
        ConfigManager.Save()
        AppState.History := []
        HistoryManager.Save()
        ToolTip( Lang( "MSG_HISTORY_DISABLED" ) )
        SetTimer( () => ToolTip(), -3000 )
        return
    }
    pendingRemoval := AppState.History.Length - newMax
    if pendingRemoval > 0 {
        confirm := MsgBox( Lang( "CONFIRM_TRIM_HISTORY", , AppState.History.Length, newMax, pendingRemoval ), Lang( "MSG_CONFIRM" ), "YesNo Icon?" )
        if confirm != "Yes"
            return
    }
    AppState.MaxHistory := newMax
    ConfigManager.Save()
    while AppState.History.Length > AppState.MaxHistory
        AppState.History.Pop()
    HistoryManager.Save()
    ToolTip( Lang( "MSG_HISTORY_LIMIT_SET", , newMax ) )
    SetTimer( () => ToolTip(), -3000 )
}

SetDeleteDelay( * ) {
    input := InputBox( Lang( "INPUT_DELAY_PROMPT" ), Lang( "INPUT_DELAY_TITLE" ), "w300 h120", AppState.DeleteDelay )
    if input.Result == "OK" && IsNumber( input.Value ) && input.Value > 0 {
        AppState.DeleteDelay := Integer( input.Value )
        ConfigManager.Save()
        ToolTip( Lang( "MSG_DELAY_SET", , AppState.DeleteDelay ) )
        SetTimer( () => ToolTip(), -2000 )
    }
}

SetCleanupInterval( * ) {
    input := InputBox( Lang( "INPUT_INTERVAL_PROMPT" ), Lang( "INPUT_INTERVAL_TITLE" ), "w300 h120", AppState.CleanupInterval )
    if input.Result == "OK" && IsNumber( input.Value ) && input.Value > 0 {
        AppState.CleanupInterval := Integer( input.Value )
        ConfigManager.Save()
        ToolTip( Lang( "MSG_INTERVAL_SET", , AppState.CleanupInterval ) )
        SetTimer( () => ToolTip(), -2000 )
    }
}

SetImPath( * ) {
    SelectedFile := Trim( FileSelect( 1, A_ProgramFiles, Lang( "GUI_IM_SELECT_TITLE" ), Lang( "GUI_IM_SELECT_FILTER" ) ) )
    if SelectedFile == ""
        return
    if !InStr( StrLower( SelectedFile ), "magick.exe" ) {
        MsgBox( Lang( "MSG_IM_SELECT_ERROR" ), Lang( "MSG_ERROR" ), "Iconx" )
        return
    }
    if !FileExist( SelectedFile ) {
        MsgBox( Lang( "MSG_IM_FILE_NOT_EXIST" ), Lang( "MSG_ERROR" ), "Iconx" )
        return
    }
    try {
        IniWrite( SelectedFile, AppState.ConfigFile, "ImageMagick", "Path" )
    } catch {
        MsgBox( Lang( "MSG_IM_SAVE_FAIL" ), Lang( "MSG_ERROR" ), "Iconx" )
        return
    }
    AppState.ImageMagickExe := SelectedFile
    RefreshImStatus()
    MsgBox( Lang( "MSG_IM_SET_SUCCESS", , SelectedFile ), Lang( "MSG_SUCCESS" ), "Iconi T2" )
}

SetIgnorePatterns( * ) {
    global AppState, ConfigManager
    myGui := Gui( "+AlwaysOnTop", Lang( "GUI_IGNORE_TITLE" ) )
    myGui.SetFont( "s10", "Microsoft YaHei" )
    myGui.Add( "Text", , Lang( "GUI_IGNORE_PROMPT" ) )

    myEdit := myGui.Add( "Edit", "Multi VScroll w500 h200", "" )
    current := ""
    for pattern in AppState.IgnorePatterns
        current .= pattern "`n"
    myEdit.Value := RTrim( current, "`n" )

    btnOK := myGui.Add( "Button", "Default w80", Lang( "GUI_IGNORE_OK" ) )
    btnCancel := myGui.Add( "Button", "x+10 w80", Lang( "GUI_IGNORE_CANCEL" ) )

    btnOK.OnEvent( "Click", ( * ) => SaveIgnoreRules( myEdit.Text, myGui ) )
    btnCancel.OnEvent( "Click", ( * ) => myGui.Destroy() )
    myGui.OnEvent( "Escape", ( * ) => myGui.Destroy() )
    myGui.Show()
}

SaveIgnoreRules( text, myGui ) {
    global AppState, ConfigManager
    newPatterns := []
    lines := StrSplit( text, "`n", "`r" )
    for line in lines {
        line := Trim( line )
        if line != ""
            newPatterns.Push( line )
    }
    AppState.IgnorePatterns := newPatterns
    ConfigManager.Save()
    FileHelper.globCache.Clear()
    myGui.Destroy()
    ToolTip( Lang( "MSG_IGNORE_UPDATED" ) )
    SetTimer( () => ToolTip(), -2000 )
}
