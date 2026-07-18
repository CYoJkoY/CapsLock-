#Requires AutoHotkey v2.0

TraySetup() {
    global AppState
    A_IconTip := "CapsLock-"
    AppState.TrayMenu := A_TrayMenu
    Tray := AppState.TrayMenu
    Tray.Delete()

    RefreshImStatus()

    Tray.Add()
    Tray.Add( Lang( "MENU_OPEN_TEMP" ), ( * ) => Run( "explore " A_Temp ) )

    modeMenu := Menu()
    modeMenu.Add( Lang( "MENU_MODE1" ), ( * ) => SetDeleteMode( 1 ) )
    modeMenu.Add( Lang( "MENU_MODE2" ), ( * ) => SetDeleteMode( 2 ) )
    modeMenu.Add( Lang( "MENU_MODE3" ), ( * ) => SetDeleteMode( 3 ) )
    Tray.Add( Lang( "MENU_DELETE_MODE" ), modeMenu )

    Tray.Add( Lang( "MENU_SET_DELAY" ), ( * ) => SetDeleteDelay() )
    Tray.Add( Lang( "MENU_SET_INTERVAL" ), ( * ) => SetCleanupInterval() )

    Tray.Add()
    Tray.Add( Lang( "MENU_MAX_HISTORY" ), ( * ) => SetMaxHistory() )

    pasteModeMenu := Menu()
    pasteModeMenu.Add( Lang( "MENU_PASTE_FILE" ), ( * ) => SetPasteMode( 1 ) )
    pasteModeMenu.Add( Lang( "MENU_PASTE_TEXT" ), ( * ) => SetPasteMode( 2 ) )
    Tray.Add( Lang( "MENU_PASTE_MODE" ), pasteModeMenu )
    Tray.Add( Lang( "MENU_IGNORE_RULES" ), ( * ) => SetIgnorePatterns() )

    langMenu := Menu()
    currentLang := Language.GetCurrent()
    for code in Language.GetLanguages() {
        langDisplay := Lang( "LANG_" . StrUpper( code ), code )
        langMenu.Add( langDisplay, SwitchLanguage.Bind( code ) )
        if ( code = currentLang ) {
            langMenu.Check( langDisplay )
        }
    }
    Tray.Add( Lang( "MENU_LANGUAGE" ), langMenu )

    Tray.Add()
    Tray.Add( Lang( "MENU_AUTOSTART" ), ToggleAutoStart )
    Tray.Add( Lang( "MENU_RELOAD" ), ( * ) => Reload() )
    Tray.Add( Lang( "MENU_EXIT" ), ( * ) => ExitApp() )

    AppState.modeMenu := modeMenu
    AppState.pasteModeMenu := pasteModeMenu
    TrayMenuRefresh()
}

RefreshImStatus() {
    global AppState
    exe := AppState.ImageMagickExe
    valid := exe != "" && InStr( StrLower( exe ), "magick.exe" ) && FileExist( exe )
    newText := valid ? Lang( "MENU_IM_STATUS_SET" ) : Lang( "MENU_IM_STATUS_NOTSET" )
    if AppState.currentImMenuText == newText
        return

    Tray := AppState.TrayMenu
    oldText := AppState.currentImMenuText

    try {
        Tray.Insert( 1, newText, ( * ) => SetImPath() )
    } catch {
        Tray.Add( newText, ( * ) => SetImPath() )
    }

    if valid
        Tray.Check( newText )
    else
        Tray.Uncheck( newText )

    if oldText != "" && oldText != newText {
        try Tray.Delete( oldText )
    }

    AppState.currentImMenuText := newText
}

TrayMenuRefresh() {
    global AppState
    Tray := AppState.TrayMenu
    modeMenu := AppState.modeMenu
    modeMenu.Uncheck( Lang( "MENU_MODE1" ) )
    modeMenu.Uncheck( Lang( "MENU_MODE2" ) )
    modeMenu.Uncheck( Lang( "MENU_MODE3" ) )
    if AppState.DeleteMode == 1
        modeMenu.Check( Lang( "MENU_MODE1" ) )
    else if AppState.DeleteMode == 2
        modeMenu.Check( Lang( "MENU_MODE2" ) )
    else if AppState.DeleteMode == 3
        modeMenu.Check( Lang( "MENU_MODE3" ) )

    pasteMenu := AppState.pasteModeMenu
    pasteMenu.Uncheck( Lang( "MENU_PASTE_FILE" ) )
    pasteMenu.Uncheck( Lang( "MENU_PASTE_TEXT" ) )
    if AppState.PasteMode == 1
        pasteMenu.Check( Lang( "MENU_PASTE_FILE" ) )
    else if AppState.PasteMode == 2
        pasteMenu.Check( Lang( "MENU_PASTE_TEXT" ) )

    if IsAutoStartEnabled()
        Tray.Check( Lang( "MENU_AUTOSTART" ) )
    else
        Tray.Uncheck( Lang( "MENU_AUTOSTART" ) )
}

ToggleAutoStart( * ) {
    global AppState
    RegPath := "Software\Microsoft\Windows\CurrentVersion\Run"
    AppName := "CapsLock-"
    Tray := AppState.TrayMenu
    if IsAutoStartEnabled() {
        RegDelete( "HKEY_CURRENT_USER\" RegPath, AppName )
        Tray.Uncheck( Lang( "MENU_AUTOSTART" ) )
        MsgBox( Lang( "MSG_AUTOSTART_OFF" ), Lang( "MSG_SUCCESS" ), "Iconi T2" )
    } else {
        RegWrite( '"' A_ScriptFullPath '"', "REG_SZ", "HKEY_CURRENT_USER\" RegPath, AppName )
        Tray.Check( Lang( "MENU_AUTOSTART" ) )
        MsgBox( Lang( "MSG_AUTOSTART_ON" ), Lang( "MSG_SUCCESS" ), "Iconi T2" )
    }
}

IsAutoStartEnabled() {
    try {
        RegRead( "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run", "CapsLock-" )
        return true
    } catch {
        return false
    }
}

SwitchLanguage( code, * ) {
    if Language.SetLanguage( code ) {
        TraySetup()
        if IsObject( AppState.FullHistoryGui ) {
            try AppState.FullHistoryGui.Destroy()
            AppState.FullHistoryGui := ""
        }
        ToolTip( Lang( "MSG_LANG_CHANGED", , code ) )
        SetTimer( () => ToolTip(), -1500 )
    }
}
