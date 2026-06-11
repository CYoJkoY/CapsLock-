#Requires AutoHotkey v2.0

TraySetup() {
    global Tray, modeMenu, pasteModeMenu, currentImMenuText

    A_IconTip := "CapsLock-"

    Tray := A_TrayMenu
    Tray.Delete()
    Tray.Add( currentImMenuText, ( * ) => SetImPath() )

    Tray.Add()
    Tray.Add( "Open Temp Folder", ( * ) => Run( "explore " A_Temp ) )

    modeMenu.Delete()
    modeMenu.Add( "1 - Delete after delay", SetDeleteMode1 )
    modeMenu.Add( "2 - Batch cleanup", SetDeleteMode2 )
    modeMenu.Add( "3 - Never delete", SetDeleteMode3 )
    Tray.Add( "Delete Mode", modeMenu )

    Tray.Add( "Mode1: Set Delete Delay...", SetDeleteDelay )
    Tray.Add( "Mode2: Set Cleanup Interval...", SetCleanupInterval )

    Tray.Add()
    Tray.Add( "Set Max History Limit...", SetMaxHistory )

    pasteModeMenu.Delete()
    pasteModeMenu.Add( "1 - Paste as File", SetPasteMode1 )
    pasteModeMenu.Add( "2 - Paste as Text (with source)", SetPasteMode2 )
    Tray.Add( "Paste Mode", pasteModeMenu )

    Tray.Add()
    Tray.Add( "Load on start up", ToggleAutoStart )
    Tray.Add( "Reload", ( * ) => Reload() )
    Tray.Add( "Exit", ( * ) => ExitApp() )

    RefreshImStatus()
    TrayMenuRefresh()
}

RefreshImStatus() {
    global imageMagickExe, currentImMenuText, Tray

    isValid := ( imageMagickExe != "" )
    && InStr( StrLower( imageMagickExe ), "magick.exe" )
    && FileExist( imageMagickExe )

    newText := isValid ? "ImageMagick: Valid (Click to change)" : "ImageMagick: Not Set / Invalid"

    if ( currentImMenuText == newText ) {
        if ( isValid ) {
            Tray.Check( newText )
        } else {
            Tray.Uncheck( newText )
        }
        return
    }

    Tray.Insert( currentImMenuText, newText, ( * ) => SetImPath() )
    Tray.Delete( currentImMenuText )

    if ( isValid ) {
        Tray.Check( newText )
    } else {
        Tray.Uncheck( newText )
    }
    currentImMenuText := newText
}

TrayMenuRefresh() {
    global deleteMode, pasteMode, modeMenu, pasteModeMenu, Tray

    modeMenu.Uncheck( "1 - Delete after delay" )
    modeMenu.Uncheck( "2 - Batch cleanup" )
    modeMenu.Uncheck( "3 - Never delete" )
    if ( deleteMode = 1 ) {
        modeMenu.Check( "1 - Delete after delay" )
    } else if ( deleteMode = 2 ) {
        modeMenu.Check( "2 - Batch cleanup" )
    } else if ( deleteMode = 3 ) {
        modeMenu.Check( "3 - Never delete" )
    }

    pasteModeMenu.Uncheck( "1 - Paste as File" )
    pasteModeMenu.Uncheck( "2 - Paste as Text (with source)" )
    if ( pasteMode = 1 ) {
        pasteModeMenu.Check( "1 - Paste as File" )
    } else if ( pasteMode = 2 ) {
        pasteModeMenu.Check( "2 - Paste as Text (with source)" )
    }

    if IsAutoStartEnabled() {
        Tray.Check( "Load on start up" )
    } else {
        Tray.Uncheck( "Load on start up" )
    }
}

ToggleAutoStart( * ) {
    global Tray

    RegPath := "Software\Microsoft\Windows\CurrentVersion\Run"
    AppName := "CapsLock-"

    if IsAutoStartEnabled() {
        RegDelete( "HKEY_CURRENT_USER\" RegPath, AppName )
        Tray.Uncheck( "Load on start up" )
        MsgBox( "Load on start up turned off", "Success", "Iconi T2" )
    } else {
        RegWrite( '"' A_ScriptFullPath '"', "REG_SZ", "HKEY_CURRENT_USER\" RegPath, AppName )
        Tray.Check( "Load on start up" )
        MsgBox( "Load on start up turned on", "Success", "Iconi T2" )
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
