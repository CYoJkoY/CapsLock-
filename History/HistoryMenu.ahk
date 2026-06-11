#Requires AutoHotkey v2.0

ShowHistoryMenu( isReturning := false ) {
    global clipboardHistory, menuPosX, menuPosY, MAX_VISIBLE_MENU, targetWindow

    targetWindow := WinExist( "A" )
    if ( clipboardHistory.Length = 0 ) {
        ToolTip( "No manual copy history" )
        SetTimer( () => ToolTip(), -1500 )
        return
    }
    if !isReturning {
        MouseGetPos( &menuPosX, &menuPosY )
    }

    HistoryMenu := Menu()
    total := clipboardHistory.Length
    displayCount := total > MAX_VISIBLE_MENU ? MAX_VISIBLE_MENU : total

    loop displayCount {
        index := A_Index
        item := clipboardHistory[ index ]
        content := item[ "text" ]
        display := StrReplace( SubStr( content, 1, 50 ), "`n", " " )
        if ( StrLen( content ) > 50 ) {
            display .= "..."
        }
        HistoryMenu.Add( index ". " display, ActionPickerHandler )
    }

    if ( total > MAX_VISIBLE_MENU ) {
        HistoryMenu.Add()
        HistoryMenu.Add( "📋 View full history (" total " items)...", ShowFullHistoryGui )
    }

    HistoryMenu.Show( menuPosX, menuPosY )
}

ActionPickerHandler( ItemName, ItemPos, MyMenu ) {
    global selectedIndex, selectedItem, clipboardHistory

    selectedIndex := ItemPos
    selectedItem := clipboardHistory[ ItemPos ]

    ActionMenu := Menu()
    ActionMenu.Add( "📄 Paste as File", ( * ) => PasteAsFile( selectedItem ) )
    ActionMenu.Add( "🔍 Preview Content", ( * ) => ShowPreviewGui( selectedItem[ "text" ] ) )
    ActionMenu.Add( "❌ Delete from History", DeleteHistoryItem )
    ActionMenu.Add()
    ActionMenu.Add( "⬅️ Back to List", ( * ) => SetTimer( () => ShowHistoryMenu( true ), -10 ) )
    ActionMenu.Show()
}
