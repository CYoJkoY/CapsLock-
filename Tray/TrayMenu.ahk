#Requires AutoHotkey v2.0

TraySetup() {
    global AppState
    A_IconTip := "CapsLock-"
    AppState.TrayMenu := A_TrayMenu
    Tray := AppState.TrayMenu
    Tray.Delete()

    RefreshImStatus()

    Tray.Add()
    Tray.Add( "打开临时文件夹", ( * ) => Run( "explore " A_Temp ) )

    modeMenu := Menu()
    modeMenu.Add( "1 - 延迟删除", ( * ) => SetDeleteMode( 1 ) )
    modeMenu.Add( "2 - 批量清理", ( * ) => SetDeleteMode( 2 ) )
    modeMenu.Add( "3 - 永不删除", ( * ) => SetDeleteMode( 3 ) )
    Tray.Add( "删除模式", modeMenu )

    Tray.Add( "模式1: 设置延迟时间...", ( * ) => SetDeleteDelay() )
    Tray.Add( "模式2: 设置清理间隔...", ( * ) => SetCleanupInterval() )

    Tray.Add()
    Tray.Add( "设置最大历史数量...", ( * ) => SetMaxHistory() )

    pasteModeMenu := Menu()
    pasteModeMenu.Add( "1 - 粘贴为文件", ( * ) => SetPasteMode( 1 ) )
    pasteModeMenu.Add( "2 - 粘贴为文本（带来源）", ( * ) => SetPasteMode( 2 ) )
    Tray.Add( "粘贴模式", pasteModeMenu )

    Tray.Add()
    Tray.Add( "开机自启", ToggleAutoStart )
    Tray.Add( "重新加载", ( * ) => Reload() )
    Tray.Add( "退出", ( * ) => ExitApp() )

    AppState.modeMenu := modeMenu
    AppState.pasteModeMenu := pasteModeMenu
    TrayMenuRefresh()
}

RefreshImStatus() {
    global AppState
    exe := AppState.ImageMagickExe
    valid := exe != "" && InStr( StrLower( exe ), "magick.exe" ) && FileExist( exe )
    newText := valid ? "ImageMagick: 已设置 (点击更改)" : "ImageMagick: 未设置/无效"
    if AppState.currentImMenuText == newText
        return

    Tray := AppState.TrayMenu
    oldText := AppState.currentImMenuText

    if oldText != "" {
        try Tray.Delete( oldText )
        Tray.Insert( 1, newText, ( * ) => SetImPath() )
    } else {
        Tray.Add( newText, ( * ) => SetImPath() )
    }

    if valid
        Tray.Check( newText )
    else
        Tray.Uncheck( newText )
    AppState.currentImMenuText := newText
}

TrayMenuRefresh() {
    global AppState
    Tray := AppState.TrayMenu
    modeMenu := AppState.modeMenu
    modeMenu.Uncheck( "1 - 延迟删除" )
    modeMenu.Uncheck( "2 - 批量清理" )
    modeMenu.Uncheck( "3 - 永不删除" )
    if AppState.DeleteMode == 1
        modeMenu.Check( "1 - 延迟删除" )
    else if AppState.DeleteMode == 2
        modeMenu.Check( "2 - 批量清理" )
    else if AppState.DeleteMode == 3
        modeMenu.Check( "3 - 永不删除" )

    pasteMenu := AppState.pasteModeMenu
    pasteMenu.Uncheck( "1 - 粘贴为文件" )
    pasteMenu.Uncheck( "2 - 粘贴为文本（带来源）" )
    if AppState.PasteMode == 1
        pasteMenu.Check( "1 - 粘贴为文件" )
    else if AppState.PasteMode == 2
        pasteMenu.Check( "2 - 粘贴为文本（带来源）" )

    if IsAutoStartEnabled()
        Tray.Check( "开机自启" )
    else
        Tray.Uncheck( "开机自启" )
}

ToggleAutoStart( * ) {
    global AppState
    RegPath := "Software\Microsoft\Windows\CurrentVersion\Run"
    AppName := "CapsLock-"
    Tray := AppState.TrayMenu
    if IsAutoStartEnabled() {
        RegDelete( "HKEY_CURRENT_USER\" RegPath, AppName )
        Tray.Uncheck( "开机自启" )
        MsgBox( "开机自启已关闭", "成功", "Iconi T2" )
    } else {
        RegWrite( '"' A_ScriptFullPath '"', "REG_SZ", "HKEY_CURRENT_USER\" RegPath, AppName )
        Tray.Check( "开机自启" )
        MsgBox( "开机自启已开启", "成功", "Iconi T2" )
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
