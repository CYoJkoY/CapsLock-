#Requires AutoHotkey v2.0

_RefreshFullHistoryList() {
    global clipboardHistory, fullHistoryGui

    lv := fullHistoryGui.ListView
    lv.Delete()

    for idx, item in clipboardHistory {
        try {
            if ( Type( item ) = "Map" && item.Has( "text" ) ) {
                content := item[ "text" ]
            } else {
                content := String( item ?? "" )
            }
        } catch {
            content := "[Invalid History Entry]"
        }
        display := StrReplace( SubStr( content, 1, 100 ), "`n", " " )
        if ( StrLen( content ) > 100 ) {
            display .= "..."
        }
        lv.Add(, idx, display )
    }

    lv.ModifyCol( 1, "AutoHdr" )
    lv.ModifyCol( 2, "AutoHdr" )
    fullHistoryGui.chkSelectAll.Value := 0
}

_ResizeFullHistoryGui( guiObj, windowMinMax, width, height ) {
    lv := guiObj.ListView
    lv.Move( 10, 10, width - 20, height - 100 )

    guiObj.btnPaste.Move( 10, height - 80 )
    guiObj.btnClose.Move( 120, height - 80 )
    guiObj.chkSelectAll.Move( 10, height - 40 )
    guiObj.btnDeleteSelected.Move( 120, height - 40 )
}

_OnFullHistoryDoubleClick( lv, row ) {
    if ( row = 0 ) {
        return
    }
    selectedHistory := clipboardHistory[ row ]
    PasteAsMultipleFiles( [
        selectedHistory
    ] )
}

_OnFullHistoryContextMenu( lv, row, isRightClick, x, y ) {
    if ( row = 0 ) {
        return
    }
    selectedHistory := clipboardHistory[ row ]
    contextMenu := Menu()
    contextMenu.Add( "📄 Paste as File", ( * ) => PasteAsMultipleFiles( [
        selectedHistory
    ] ) )
    contextMenu.Add( "🔍 Preview", ( * ) => ShowPreviewGui( selectedHistory[ "text" ] ) )
    contextMenu.Add( "❌ Delete", ( * ) => DeleteFromFullHistory( row ) )
    contextMenu.Show( x, y )
}

_PasteSelectedFromFullHistory() {
    global clipboardHistory, fullHistoryGui, targetWindow

    lv := fullHistoryGui.ListView
    fileList := []
    row := 0
    while ( row := lv.GetNext( row, "Checked" ) ) {
        fileList.Push( clipboardHistory[ row ] )
    }

    if ( fileList.Length = 0 ) {
        ShowToolTip( "Please select at least one item", 1500 )
        return
    }

    if !WinExist( "ahk_id " targetWindow ) {
        currentWin := WinExist( "A" )
        if ( currentWin && currentWin != fullHistoryGui.Hwnd ) {
            targetWindow := currentWin
        } else {
            ShowToolTip( "Target window closed.`nSwitch to desired window within 2 seconds...", 2500 )
            loop 20 {
                Sleep( 100 )
                currentWin := WinExist( "A" )
                if ( currentWin && currentWin != fullHistoryGui.Hwnd ) {
                    targetWindow := currentWin
                    break
                }
            }
            if !targetWindow {
                ShowToolTip( "No new window detected, operation cancelled", 2000 )
                return
            }
        }
    }

    state := WinGetMinMax( "ahk_id " targetWindow )
    if ( state = -1 ) {
        WinRestore( "ahk_id " targetWindow )
    }
    WinActivate( "ahk_id " targetWindow )
    if !WinWaitActive( "ahk_id " targetWindow, , 1 ) {
        ShowToolTip( "Cannot activate target window, please click it manually", 2000 )
        return
    }
    Sleep( 100 )

    for item in fileList {
        PasteSingleFile( item[ "text" ], false )
        Sleep( 200 )
    }
    ShowToolTip( "Paste completed", 1500 )
}

_OnSelectAllClicked( chk, info ) {
    lv := chk.Gui.ListView
    total := lv.GetCount()
    checked := 0
    row := 0
    while ( row := lv.GetNext( row, "Checked" ) ) {
        checked++
    }
    if ( checked = total ) {
        loop total {
            lv.Modify( A_Index, "-Check" )
        }
        chk.Value := 0
    } else {
        loop total {
            lv.Modify( A_Index, "Check" )
        }
        chk.Value := 1
    }
}

_OnDeleteSelected( * ) {
    global clipboardHistory, fullHistoryGui

    lv := fullHistoryGui.ListView
    rowsToDelete := []
    row := 0
    while ( row := lv.GetNext( row, "Checked" ) ) {
        rowsToDelete.Push( row )
    }
    if ( rowsToDelete.Length = 0 ) {
        ShowToolTip( "No checked items", 1500 )
        return
    }
    loop rowsToDelete.Length {
        idx := rowsToDelete[ rowsToDelete.Length - A_Index + 1 ]
        clipboardHistory.RemoveAt( idx )
    }
    SaveHistory()
    _RefreshFullHistoryList()
}

_UpdateSelectAllCheckbox() {
    global fullHistoryGui

    lv := fullHistoryGui.ListView
    total := lv.GetCount()
    checked := 0
    row := 0
    while ( row := lv.GetNext( row, "Checked" ) ) {
        checked++
    }
    fullHistoryGui.chkSelectAll.Value := ( checked = total ) ? 1 : 0
}

_OnItemCheck( lv, row, checked ) {
    _UpdateSelectAllCheckbox()
}
