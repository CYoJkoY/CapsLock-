#Requires AutoHotkey v2.0

ShowHistoryMenu( isReturning := false ) {
    if AppState.History.Length == 0 {
        ToolTip( "没有手动复制历史" )
        SetTimer( () => ToolTip(), -1500 )
        return
    }

    if !isReturning {
        MouseGetPos( &x, &y )
        AppState.MenuPosX := x
        AppState.MenuPosY := y
    }

    myMenu := Menu()
    total := AppState.History.Length
    displayCount := total > AppState.MAX_VISIBLE_MENU ? AppState.MAX_VISIBLE_MENU : total
    loop displayCount {
        index := A_Index
        item := AppState.History[ index ]
        content := item[ "text" ]
        display := StrReplace( SubStr( content, 1, 50 ), "`n", " " )
        if StrLen( content ) > 50
            display .= "..."

        timeInfo := SubStr( item[ "time" ], 11, 5 )
        myMenu.Add( index ". [" timeInfo "] " display, ActionPickerHandler )
    }
    if total > AppState.MAX_VISIBLE_MENU {
        myMenu.Add()
        myMenu.Add( "📋 查看完整历史 (" total " 项)...", ShowFullHistoryGui )
    }
    myMenu.Show( AppState.MenuPosX, AppState.MenuPosY )
}

ActionPickerHandler( ItemName, ItemPos, MyMenu ) {
    AppState.SelectedIndex := ItemPos
    AppState.SelectedItem := AppState.History[ ItemPos ]
    action := Menu()
    action.Add( "📄 粘贴为文件", ( * ) => PasteAsFile( AppState.SelectedItem ) )
    action.Add( "🔍 预览内容", ( * ) => ShowPreviewGui( AppState.SelectedItem[ "text" ] ) )
    action.Add( "❌ 从历史删除", ( * ) => ( HistoryManager.Delete( AppState.SelectedIndex ), ShowToolTip( "已删除", 1000 ) ) )
    action.Add()
    action.Add( "⬅️ 返回列表", ( * ) => SetTimer( () => ShowHistoryMenu( true ), -10 ) )
    action.Show()
}
