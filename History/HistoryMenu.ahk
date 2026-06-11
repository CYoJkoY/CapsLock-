#Requires AutoHotkey v2.0

ShowHistoryMenu( isReturning := false ) {
    global ClipboardHistory, MenuPosX, MenuPosY, MAX_VISIBLE_MENU, TargetWindow

    TargetWindow := WinExist( "A" )
    if ( ClipboardHistory.Length = 0 ) {
        ToolTip( "No manual copy history" )
        SetTimer( () => ToolTip(), -1500 )
        return
    }
    if !isReturning {
        MouseGetPos( &MenuPosX, &MenuPosY )
    }

    HistoryMenu := Menu()
    total := ClipboardHistory.Length
    displayCount := total > MAX_VISIBLE_MENU ? MAX_VISIBLE_MENU : total

    loop displayCount {
        index := A_Index
        item := ClipboardHistory[ index ]
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

    HistoryMenu.Show( MenuPosX, MenuPosY )
}

ActionPickerHandler( ItemName, ItemPos, MyMenu ) {
    global SelectedIndex, SelectedItem, ClipboardHistory

    SelectedIndex := ItemPos
    SelectedItem := ClipboardHistory[ ItemPos ]

    ActionMenu := Menu()
    ActionMenu.Add( "📄 Paste as File", ( * ) => PasteAsFile( SelectedItem ) )
    ActionMenu.Add( "🔍 Preview Content", ( * ) => ShowPreviewGui( SelectedItem[ "text" ] ) )
    ActionMenu.Add( "❌ Delete from History", DeleteHistoryItem )
    ActionMenu.Add()
    ActionMenu.Add( "⬅️ Back to List", ( * ) => SetTimer( () => ShowHistoryMenu( true ), -10 ) )
    ActionMenu.Show()
}
