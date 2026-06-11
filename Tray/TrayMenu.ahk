#Requires AutoHotkey v2.0

TraySetup() {
    global Tray, ModeMenu, PasteModeMenu, CurrentImMenuText

    A_IconTip := "CapsLock-"

    Tray := A_TrayMenu
    Tray.Delete()
    Tray.Add( CurrentImMenuText, ( * ) => SetImPath() )

    Tray.Add()
    Tray.Add( "Open Temp Folder", ( * ) => Run( "explore " A_Temp ) )

    ModeMenu.Delete()
    ModeMenu.Add( "1 - Delete after delay", SetDeleteMode1 )
    ModeMenu.Add( "2 - Batch cleanup", SetDeleteMode2 )
    ModeMenu.Add( "3 - Never delete", SetDeleteMode3 )
    Tray.Add( "Delete Mode", ModeMenu )

    Tray.Add( "Mode1: Set Delete Delay...", SetDeleteDelay )
    Tray.Add( "Mode2: Set Cleanup Interval...", SetCleanupInterval )

    Tray.Add()
    Tray.Add( "Set Max History Limit...", SetMaxHistory )

    PasteModeMenu.Delete()
    PasteModeMenu.Add( "1 - Paste as File", SetPasteMode1 )
    PasteModeMenu.Add( "2 - Paste as Text (with source)", SetPasteMode2 )
    Tray.Add( "Paste Mode", PasteModeMenu )

    Tray.Add()
    Tray.Add( "Load on start up", ToggleAutoStart )
    Tray.Add( "Reload", ( * ) => Reload() )
    Tray.Add( "Exit", ( * ) => ExitApp() )

    RefreshImStatus()
    TrayMenuRefresh()
}

RefreshImStatus() {
    global ImageMagickExe, CurrentImMenuText, Tray

    isValid := ( ImageMagickExe != "" )
    && InStr( StrLower( ImageMagickExe ), "magick.exe" )
    && FileExist( ImageMagickExe )

    newText := isValid ? "ImageMagick: Valid (Click to change)" : "ImageMagick: Not Set / Invalid"

    if ( CurrentImMenuText == newText ) {
        if ( isValid ) {
            Tray.Check( newText )
        } else {
            Tray.Uncheck( newText )
        }
        return
    }

    Tray.Insert( CurrentImMenuText, newText, ( * ) => SetImPath() )
    Tray.Delete( CurrentImMenuText )

    if ( isValid ) {
        Tray.Check( newText )
    } else {
        Tray.Uncheck( newText )
    }
    CurrentImMenuText := newText
}

TrayMenuRefresh() {
    global DeleteMode, PasteMode, ModeMenu, PasteModeMenu, Tray

    ModeMenu.Uncheck( "1 - Delete after delay" )
    ModeMenu.Uncheck( "2 - Batch cleanup" )
    ModeMenu.Uncheck( "3 - Never delete" )
    if ( DeleteMode = 1 ) {
        ModeMenu.Check( "1 - Delete after delay" )
    } else if ( DeleteMode = 2 ) {
        ModeMenu.Check( "2 - Batch cleanup" )
    } else if ( DeleteMode = 3 ) {
        ModeMenu.Check( "3 - Never delete" )
    }

    PasteModeMenu.Uncheck( "1 - Paste as File" )
    PasteModeMenu.Uncheck( "2 - Paste as Text (with source)" )
    if ( PasteMode = 1 ) {
        PasteModeMenu.Check( "1 - Paste as File" )
    } else if ( PasteMode = 2 ) {
        PasteModeMenu.Check( "2 - Paste as Text (with source)" )
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
    AppName := "CapsLockManager"

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
        RegRead( "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run", "CapsLockManager" )
        return true
    } catch {
        return false
    }
}
