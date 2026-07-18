#Requires AutoHotkey v2.0

OnFullHistoryDoubleClick( lv, row ) {
    if row == 0
        return

    realIndex := lv.GetText( row, 1 )
    PasteSingleFile( AppState.History[ realIndex ], false )
}

OnFullHistoryContextMenu( lv, row, isRightClick, x, y ) {
    if row == 0
        return

    realIdx := lv.GetText( row, 1 )
    item := AppState.History[ realIdx ]
    myMenu := Menu()
    myMenu.Add( Lang( "CONTEXT_PASTE_FILE" ), ( * ) => PasteAsMultipleFiles( [ item ] ) )
    myMenu.Add( Lang( "CONTEXT_PREVIEW" ), ( * ) => ShowPreviewGui( item[ "text" ] ) )
    myMenu.Add( Lang( "CONTEXT_DELETE" ), ( * ) => DeleteFromFullHistory( realIdx ) )
    myMenu.Show( x, y )
}

PasteSelectedFromFullHistory() {
    myGui := AppState.FullHistoryGui
    lv := myGui.ListView
    fileList := []
    row := 0
    while row := lv.GetNext( row, "Checked" ) {
        realIdx := lv.GetText( row, 1 )
        fileList.Push( AppState.History[ realIdx ] )
    }

    if fileList.Length == 0 {
        ShowToolTip( Lang( "MSG_SELECT_ITEM" ), 1500 )
        return
    }

    if !WinExist( "ahk_id " AppState.TargetWindow ) {
        current := WinExist( "A" )
        if current && current != myGui.Hwnd
            AppState.TargetWindow := current
        else {
            ShowToolTip( Lang( "MSG_TARGET_CLOSED" ), 2500 )
            loop 20 {
                Sleep( 100 )
                current := WinExist( "A" )
                if current && current != myGui.Hwnd {
                    AppState.TargetWindow := current
                    break
                }
            }
            if !AppState.TargetWindow {
                ShowToolTip( Lang( "MSG_NO_TARGET" ), 2000 )
                return
            }
        }
    }

    WinActivate( "ahk_id " AppState.TargetWindow )
    Sleep( 100 )
    for item in fileList {
        PasteSingleFile( item, false )
        Sleep( 200 )
    }

    ShowToolTip( Lang( "MSG_PASTE_COMPLETE" ), 1500 )
}

PasteSelectedFromFullHistoryText() {
    myGui := AppState.FullHistoryGui
    lv := myGui.ListView
    textList := []
    row := 0
    while row := lv.GetNext( row, "Checked" ) {
        realIdx := lv.GetText( row, 1 )
        textList.Push( AppState.History[ realIdx ][ "text" ] )
    }

    if textList.Length == 0 {
        ShowToolTip( Lang( "MSG_SELECT_ITEM" ), 1500 )
        return
    }

    combined := ""
    for t in textList
        combined .= t "`n"
    combined := RTrim( combined, "`n" )

    if !WinExist( "ahk_id " AppState.TargetWindow ) {
        current := WinExist( "A" )
        if current && current != myGui.Hwnd
            AppState.TargetWindow := current
        else {
            ShowToolTip( Lang( "MSG_TARGET_CLOSED" ), 2500 )
            loop 20 {
                Sleep( 100 )
                current := WinExist( "A" )
                if current && current != myGui.Hwnd {
                    AppState.TargetWindow := current
                    break
                }
            }

            if !AppState.TargetWindow {
                ShowToolTip( Lang( "MSG_NO_TARGET" ), 2000 )
                return
            }

        }
    }

    backup := A_Clipboard
    A_Clipboard := combined

    WinActivate( "ahk_id " AppState.TargetWindow )
    Sleep( 100 )
    Send( "^v" )
    Sleep( 50 )
    A_Clipboard := backup
    ShowToolTip( Lang( "MSG_PASTE_MULTI_COMPLETE", , textList.Length ), 1500 )
}

OnSelectAllClicked( chk, info ) {
    lv := chk.Gui.ListView
    total := lv.GetCount()
    checked := 0
    row := 0
    while row := lv.GetNext( row, "Checked" )
        checked++

    if checked == total {
        loop total
            lv.Modify( A_Index, "-Check" )
        chk.Value := 0
    } else {
        loop total
            lv.Modify( A_Index, "Check" )
        chk.Value := 1
    }
}

OnDeleteSelected( * ) {
    myGui := AppState.FullHistoryGui
    lv := myGui.ListView
    rowsToDelete := []
    row := 0
    while row := lv.GetNext( row, "Checked" )
        rowsToDelete.Push( row )

    if rowsToDelete.Length == 0 {
        ShowToolTip( Lang( "MSG_SELECT_ITEM" ), 1500 )
        return
    }

    loop rowsToDelete.Length {
        idx := rowsToDelete[ rowsToDelete.Length - A_Index + 1 ]
        HistoryManager.Delete( idx )
    }

    RefreshFullHistoryList()
}

OnItemCheck( lv, row, checked ) {
    UpdateSelectAllCheckbox()
}

UpdateSelectAllCheckbox() {
    myGui := AppState.FullHistoryGui
    lv := myGui.ListView
    total := lv.GetCount()
    checked := 0
    row := 0
    while row := lv.GetNext( row, "Checked" )
        checked++

    myGui.chkSelectAll.Value := ( checked == total ) ? 1 : 0
}
