#Requires AutoHotkey v2.0

ShowHistoryMenu( isReturning := false ) {
    if AppState.History.Length == 0 {
        ToolTip( Lang( "MSG_NO_HISTORY" ) )
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
        myMenu.Add( Lang( "HISTORY_MENU_VIEW_FULL", , total ), ShowFullHistoryGui )
    }
    myMenu.Show( AppState.MenuPosX, AppState.MenuPosY )
}

ActionPickerHandler( ItemName, ItemPos, MyMenu ) {
    AppState.SelectedIndex := ItemPos
    AppState.SelectedItem := AppState.History[ ItemPos ]
    action := Menu()
    action.Add( Lang( "CONTEXT_PASTE_FILE" ), ( * ) => PasteAsFile( AppState.SelectedItem ) )
    action.Add( Lang( "CONTEXT_PREVIEW" ), ( * ) => ShowPreviewGui( AppState.SelectedItem[ "text" ] ) )
    action.Add( Lang( "CONTEXT_DELETE" ), ( * ) => ( HistoryManager.Delete( AppState.SelectedIndex ), ShowToolTip( Lang( "MSG_DELETED" ), 1000 ) ) )
    action.Add()
    action.Add( Lang( "CONTEXT_BACK" ), ( * ) => SetTimer( () => ShowHistoryMenu( true ), -10 ) )
    action.Show()
}
