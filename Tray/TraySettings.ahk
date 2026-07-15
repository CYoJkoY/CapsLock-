#Requires AutoHotkey v2.0

SetPasteMode( mode ) {
    AppState.PasteMode := mode
    ConfigManager.Save()
    TrayMenuRefresh()
    ToolTip( "粘贴模式: " ( mode == 1 ? "文件" : "文本" ) )
    SetTimer( () => ToolTip(), -2000 )
}

SetDeleteMode( mode ) {
    AppState.DeleteMode := mode
    ConfigManager.Save()
    TrayMenuRefresh()
    msgs := [ "延迟删除", "批量清理", "永不删除" ]
    ToolTip( "删除模式: " msgs[ mode ] )
    SetTimer( () => ToolTip(), -2000 )
}

SetMaxHistory( * ) {
    input := InputBox( "输入最大历史数量 (0=禁用):", "历史上限", "w300 h120", AppState.MaxHistory )
    if input.Result != "OK" || !IsNumber( input.Value )
        return
    newMax := Integer( input.Value )
    if newMax < 0
        newMax := 0
    if newMax == 0 {
        if AppState.History.Length > 0 {
            confirm := MsgBox( "禁用历史将清除所有 " AppState.History.Length " 条记录，继续吗？", "确认", "YesNo Icon?" )
            if confirm != "Yes"
                return
        }
        AppState.MaxHistory := 0
        ConfigManager.Save()
        AppState.History := []
        HistoryManager.Save()
        ToolTip( "历史已禁用，所有记录已清除" )
        SetTimer( () => ToolTip(), -3000 )
        return
    }
    pendingRemoval := AppState.History.Length - newMax
    if pendingRemoval > 0 {
        confirm := MsgBox( "当前历史有 " AppState.History.Length " 条，设置上限 " newMax " 将删除 " pendingRemoval " 条旧记录。继续？", "确认", "YesNo Icon?" )
        if confirm != "Yes"
            return
    }
    AppState.MaxHistory := newMax
    ConfigManager.Save()
    while AppState.History.Length > AppState.MaxHistory
        AppState.History.Pop()
    HistoryManager.Save()
    ToolTip( "最大历史已设为 " newMax )
    SetTimer( () => ToolTip(), -3000 )
}

SetDeleteDelay( * ) {
    input := InputBox( "输入延迟秒数:", "延迟删除", "w300 h120", AppState.DeleteDelay )
    if input.Result == "OK" && IsNumber( input.Value ) && input.Value > 0 {
        AppState.DeleteDelay := Integer( input.Value )
        ConfigManager.Save()
        ToolTip( "延迟设为 " AppState.DeleteDelay " 秒" )
        SetTimer( () => ToolTip(), -2000 )
    }
}

SetCleanupInterval( * ) {
    input := InputBox( "输入清理间隔秒数:", "批量清理", "w300 h120", AppState.CleanupInterval )
    if input.Result == "OK" && IsNumber( input.Value ) && input.Value > 0 {
        AppState.CleanupInterval := Integer( input.Value )
        ConfigManager.Save()
        ToolTip( "清理间隔设为 " AppState.CleanupInterval " 秒" )
        SetTimer( () => ToolTip(), -2000 )
    }
}

SetImPath( * ) {
    SelectedFile := Trim( FileSelect( 1, A_ProgramFiles, "选择 ImageMagick 的 magick.exe", "Executable (*.exe)" ) )
    if SelectedFile == ""
        return
    if !InStr( StrLower( SelectedFile ), "magick.exe" ) {
        MsgBox( "请选择 magick.exe", "错误", "Iconx" )
        return
    }
    if !FileExist( SelectedFile ) {
        MsgBox( "文件不存在", "错误", "Iconx" )
        return
    }
    try {
        IniWrite( SelectedFile, AppState.ConfigFile, "ImageMagick", "Path" )
    } catch {
        MsgBox( "保存路径失败", "错误", "Iconx" )
        return
    }
    AppState.ImageMagickExe := SelectedFile
    RefreshImStatus()
    MsgBox( "ImageMagick 路径已设置`n" SelectedFile, "成功", "Iconi T2" )
}

SetIgnorePatterns( * ) {
    global AppState, ConfigManager
    myGui := Gui( "+AlwaysOnTop", "忽略规则设置" )
    myGui.SetFont( "s10", "Microsoft YaHei" )
    myGui.Add( "Text", , "每行一个正则表达式，匹配的文件路径将被跳过：" )

    myEdit := myGui.Add( "Edit", "Multi VScroll w500 h200", "" )
    current := ""
    for pattern in AppState.IgnorePatterns
        current .= pattern "`n"
    myEdit.Value := RTrim( current, "`n" )

    btnOK := myGui.Add( "Button", "Default w80", "确定" )
    btnCancel := myGui.Add( "Button", "x+10 w80", "取消" )

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
    myGui.Destroy()
    ToolTip( "忽略规则已更新" )
    SetTimer( () => ToolTip(), -2000 )
}
