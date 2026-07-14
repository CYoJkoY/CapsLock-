#Requires AutoHotkey v2.0

OnFullHistoryDoubleClick( lv, row ) {
    if row == 0
        return
    selected := AppState.History[ row ]
    PasteSingleFile( selected, false )
}

OnFullHistoryContextMenu( lv, row, isRightClick, x, y ) {
    if row == 0
        return
    selected := AppState.History[ row ]
    myMenu := Menu()
    myMenu.Add( "📄 Paste as File", ( * ) => PasteAsMultipleFiles( [ selected ] ) )
    myMenu.Add( "🔍 Preview", ( * ) => ShowPreviewGui( selected[ "text" ] ) )
    myMenu.Add( "❌ Delete", ( * ) => DeleteFromFullHistory( row ) )
    myMenu.Show( x, y )
}

PasteSelectedFromFullHistory() {
    myGui := AppState.FullHistoryGui
    lv := myGui.ListView
    fileList := []
    row := 0
    while row := lv.GetNext( row, "Checked" ) {
        fileList.Push( AppState.History[ row ] )
    }
    if fileList.Length == 0 {
        ShowToolTip( "请至少选择一个条目", 1500 )
        return
    }

    if !WinExist( "ahk_id " AppState.TargetWindow ) {
        current := WinExist( "A" )
        if current && current != myGui.Hwnd
            AppState.TargetWindow := current
        else {
            ShowToolTip( "目标窗口已关闭，请在2秒内切换至目标窗口...", 2500 )
            loop 20 {
                Sleep( 100 )
                current := WinExist( "A" )
                if current && current != myGui.Hwnd {
                    AppState.TargetWindow := current
                    break
                }
            }
            if !AppState.TargetWindow {
                ShowToolTip( "未检测到新窗口，操作取消", 2000 )
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
    ShowToolTip( "粘贴完成", 1500 )
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
        ShowToolTip( "未选中任何条目", 1500 )
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
